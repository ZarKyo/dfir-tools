#!/bin/bash
#
# Bash utilities for other scripts
#
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# -e : exit immediately on error
# -u : treat unset variables as errors
# -o pipefail : fail if any command in a pipeline fails
# IFS : safer word splitting
set -euo pipefail
IFS=$'\n\t'

####################
# Utils
####################

# From halpomeranz/dfis
declare -A TextColor

# Terminal escape codes to color text
# \033[STYLE;TEXT_COLOR;BG_COLORm
TextColor=(
    ['PRIMARY']='\033[0;37m'  # WHITE text
    ['SUCCESS']='\033[0;32m'  # GREEN text
    ['ERROR']='\033[0;31m'    # RED text
    ['WARNING']='\033[0;33m'  # YELLOW text
    ['INFO']='\033[0;34m'     # BLUE text
    ['DEBUG']='\033[0;36m'    # PURPLE text
)

NC='\033[0m'                  # No Color

print_status() {
    local tag="$1"
    local msg="$2"
    local tclr=${TextColor[$tag]:-$NC}
    local ts

    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    if [[ "$tag" == "ERROR" ]]; then
        printf "${tclr}%s - [%s] - %s${NC}\n" "$ts" "$tag" "$msg" >&2
    else
        printf "${tclr}%s - [%s] - %s${NC}\n" "$ts" "$tag" "$msg"
    fi
    [[ -n "${LOG:-}" ]] && printf "%s - [%s] - %s\n" "$ts" "$tag" "$msg" >> "$LOG"
}

# Check root rights
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This script must be run as root !"
        exit 1
    fi
}

# Wrapper: disable set -u for virtualenvwrapper commands (mkvirtualenv, workon,
# setvirtualenvproject, deactivate) which reference unbound vars like ZSH_VERSION.
function _venv() {
    set +u
    "$@" || true
    set -u
}

# System-wide locations for the DFIR tools: Python virtualenvs, and the source
# checkouts of the tools that run from their working tree.
#
# Both live outside any home directory so that they belong to the machine and
# survive imaging, where the installer creates a brand-new user. A virtualenv
# additionally hard-codes absolute paths (script shebangs, VIRTUAL_ENV in
# bin/activate) and cannot be relocated afterwards, so WORKON_HOME has to be
# set before any mkvirtualenv call — hence its definition here, at source time.
export WORKON_HOME="${WORKON_HOME_OVERRIDE:-/opt/dfir-venvs}"
export DFIR_SRC="${DFIR_SRC_OVERRIDE:-/opt/dfir-src}"

# Create the shared locations and make WORKON_HOME the machine-wide default.
function setup-shared-dirs() {
    local dir
    for dir in "${WORKON_HOME}" "${DFIR_SRC}"; do
        if [[ ! -d ${dir} ]]; then
            print_status "INFO" "Create ${dir}."
            # Owned by root, group `sudo`, setgid and group-writable: pip,
            # mkvirtualenv and git keep working as a normal user, which the
            # install flow needs (a virtualenv must be activated in the
            # *current* shell, so it cannot be created under sudo). Members of
            # `sudo` can already become root, so this grants nothing new.
            sudo install -d -m 2775 -o root -g sudo "${dir}"
        fi
    done

    # Applies to every user of the installed image, not just this one.
    # DFIR_SRC and WORKON_HOME are exported here so login sessions see them —
    # utils.sh only sets them for install/update scripts, not at login, and the
    # aliases (e.g. `autopsy`) rely on DFIR_SRC.
    if [[ ! -e /etc/profile.d/dfir-tools.sh ]]; then
        print_status "INFO" "Set DFIR_SRC, WORKON_HOME and PATH system-wide."
        {
            printf '# Set by dfir-tools.\n'
            printf 'export DFIR_SRC=%s\n' "${DFIR_SRC}"
            printf 'export WORKON_HOME=%s\n' "${WORKON_HOME}"
            # shellcheck disable=SC2016  # $PATH must stay literal in the generated file
            printf 'export PATH="$PATH:%s/didierstevenssuite"\n' "${DFIR_SRC}"
        } | sudo tee /etc/profile.d/dfir-tools.sh > /dev/null
        sudo chmod 0644 /etc/profile.d/dfir-tools.sh
    fi
}

# Checkout git repo to directory
function checkout-git-repo() {
    print_status "INFO" "Checkout $2 to $1"
    if [[ ! -d "${DFIR_SRC}"/"$2" ]]; then
        git clone --quiet "$1" "${DFIR_SRC}"/"$2" >> "$LOG" 2>&1
        print_status "INFO" "Checkout git repo $1"
    fi
}

# Update git repositories
function update-git-repositories() {
    cd "${DFIR_SRC}" || exit 1
    print_status "INFO" "Update git repositories."
    shopt -s nullglob
    for repo in *; do
        print_status "INFO" "Updating $repo."
        (
            cd "$repo" || { print_status "ERROR" "Couldn't cd into update-git-repositories"; exit 1; }
            git fetch --all >> "$LOG" 2>&1
            default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | \
                sed 's@^refs/remotes/origin/@@')" || default_branch="main"
            git reset --hard "origin/${default_branch}" >> "$LOG" 2>&1
        )
    done
    print_status "INFO" "Updated git repositories."
}

function update-ubuntu() {
    print_status "INFO" "Updating Ubuntu."
    print_status "INFO" "Running apt update."
    sudo apt update 2>&1 | tee -a "$LOG" > /dev/null
    print_status "INFO" "Running apt dist-upgrade."
    while ! sudo DEBIAN_FRONTEND=noninteractive apt -y dist-upgrade --force-yes 2>&1 | tee -a "$LOG" > /dev/null; do
        print_status "WARNING" "APT busy. Will retry in 10 seconds."
        sleep 10
    done
}

####################
# System setup
####################


# Tools for Vmware
function install-vmware-tools() {
    print_status "INFO" "Installing tools for VMware."
    sudo apt -yqq install \
        open-vm-tools-desktop 2>&1 | tee -a "$LOG" > /dev/null
}

# Install Docker via the helper script from https://github.com/ZarKyo/utils
function install-docker() {
    if command -v docker > /dev/null 2>&1; then
        return
    fi
    print_status "INFO" "Installing Docker."
    {
        curl -fsSL https://raw.githubusercontent.com/ZarKyo/utils/main/bin/install_docker.sh \
            -o /tmp/install_docker.sh
        bash /tmp/install_docker.sh
        rm -f /tmp/install_docker.sh
    } >> "$LOG" 2>&1
    print_status "INFO" "Installed Docker (log out/in for non-sudo docker access)."
}

# Create common directories
function create-common-directories() {
    print_status "INFO" "Create basic directory structure."

    mkdir -p ~/src/git

    setup-shared-dirs

    local mnt_dirs=(
        aff bde e01 evidence1 ewf ewf-mount
        ext ext4 hgfs iscsi
        linux-mount1 linux-mount2 linux-mount3
        linux-mount4 linux-mount5 linux-mount6
        linux-mount7 linux-mount8 linux-mount9
        windows-mount shadow-mount usb vss
        windows-mount1 windows-mount2 windows-mount3
        windows-mount4 windows-mount5 windows-mount6
        windows-mount7 windows-mount8 windows-mount9
        xfs
    )
    for dir in "${mnt_dirs[@]}"; do
        sudo mkdir -p "/mnt/$dir"
    done

    print_status "SUCCESS" "Directory structure created."
}

# Create docker directories.
function create-docker-directories() {
    if [ ! -d ~/docker ]; then
        print_status "INFO" "Create docker directory structure."
        mkdir -p ~/docker
    fi

    for dir in pescanner radare2 mastiff thug v8 viper; do
        if [ ! -d ~/docker/$dir ]; then
            mkdir ~/docker/$dir
            chmod 755 ~/docker/$dir
        fi
    done
}

# Create /cases/not-mounted
function create-cases-not-mounted() {
    if [[ ! -e /cases/not-mounted ]]; then
        # Check if already mounted
        if ! mount | grep /cases | grep ^.host > /dev/null; then
            print_status "INFO" "Create /cases/not-mounted."
            [[ ! -d /cases ]] && sudo mkdir /cases
            sudo chown "$USER" /cases
            touch /cases/not-mounted
        fi
    fi
}


function install-utils() {
    print_status "INFO" "Installing utils"
    if [[ ! -d ~/src/utils ]]; then
        mkdir -p ~/src
        git clone https://github.com/ZarKyo/utils.git ~/src/utils >> "$LOG" 2>&1 \
            || { print_status "ERROR" "Failed to clone utils repo."; return 1; }
    fi
    print_status "INFO" "Done installing utils"
}

####################
# Tools
####################

# General tools
function install-general-tools() {
    print_status "INFO" "Installing general tools."
    sudo DEBIAN_FRONTEND=noninteractive apt -yqq install \
        ascii \
        build-essential \
        curl \
        dos2unix \
        exfat-fuse \
        eza \
        flameshot \
        git \
        gnupg \
        hdparm \
        htop \
        jq \
        libffi-dev \
        libimage-exiftool-perl \
        libncurses5-dev \
        libssl-dev \
        make \
        nvme-cli \
        p7zip \
        python3-dev \
        python3-virtualenv \
        remmina \
        remmina-plugin-rdp \
        remmina-plugin-vnc \
        screen \
        sharutils \
        sqlite3 \
        sqlitebrowser \
        strace \
        tmux \
        trash-cli \
        tree \
        tshark \
        unzip \
        vim \
        vim-doc \
        vim-scripts \
        virtualenvwrapper \
        wget \
        whois \
        wireshark-common \
        wswedish \
        nano \
        zip 2>&1 | tee -a "$LOG" > /dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt -yqq install \
        unrar 2>&1 | tee -a "${LOG}" > /dev/null ||
        sudo DEBIAN_FRONTEND=noninteractive apt -yqq install \
            unrar-free 2>&1 | tee -a "${LOG}" > /dev/null
}

# Install the latest release .deb of a GitHub project.
#   $1  owner/repo
#   $2  dpkg package name — also the idempotency guard
#   $3  ERE matched (case-insensitively) against the asset names
#
# Every caller below publishes an amd64-only .deb, so this bails out on any
# other architecture rather than installing something that cannot run.
function install-github-deb() {
    local repo="$1" pkg="$2" pattern="$3"
    local url tmpdir

    if dpkg --status "${pkg}" > /dev/null 2>&1; then
        return 0
    fi
    if [[ "$(uname -m)" != "x86_64" ]]; then
        print_status "WARNING" "Skipping ${pkg}: only an amd64 .deb is published, host is $(uname -m)."
        return 0
    fi

    print_status "INFO" "Installing ${pkg} from the latest ${repo} release."
    url="$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
        jq -r --arg p "${pattern}" \
        '.assets[] | select(.name | test($p; "i")) | .browser_download_url' | head -1)"
    if [[ -z "${url}" ]]; then
        print_status "ERROR" "No asset matching /${pattern}/ in the latest ${repo} release."
        return 1
    fi

    tmpdir="$(mktemp -d)"
    wget -q -O "${tmpdir}/${pkg}.deb" "${url}" >> "$LOG" 2>&1
    # dpkg does not resolve dependencies and exits non-zero when some are
    # missing; `apt -f install` then pulls them in and finishes the configure.
    sudo dpkg -i "${tmpdir}/${pkg}.deb" 2>&1 | tee -a "$LOG" > /dev/null || true
    sudo apt-get -qq -f -y install 2>&1 | tee -a "$LOG" > /dev/null
    rm -rf "${tmpdir}"
    print_status "INFO" "Installed ${pkg}."
}

# Reinstall a github-deb package at the latest release. The .deb repos below
# publish no apt source, so `apt upgrade` never sees them.
function update-github-deb() {
    local repo="$1" pkg="$2" pattern="$3"
    if dpkg --status "${pkg}" > /dev/null 2>&1; then
        sudo apt-get -yqq remove "${pkg}" 2>&1 | tee -a "$LOG" > /dev/null
    fi
    install-github-deb "${repo}" "${pkg}" "${pattern}"
}

# https://github.com/balena-io/etcher — write a forensic image to USB media.
function install-balena-etcher() {
    print_status "INFO" "install-balena-etcher"
    install-github-deb balena-io/etcher balena-etcher '^balena-etcher_.*_amd64\.deb$'
}

function update-balena-etcher() {
    update-github-deb balena-io/etcher balena-etcher '^balena-etcher_.*_amd64\.deb$'
}

# https://github.com/jgraph/drawio-desktop — offline diagramming (timelines,
# network maps) for reports, with no browser round-trip.
function install-drawio() {
    print_status "INFO" "install-drawio"
    install-github-deb jgraph/drawio-desktop draw.io '^drawio-amd64-.*\.deb$'
}

function update-drawio() {
    update-github-deb jgraph/drawio-desktop draw.io '^drawio-amd64-.*\.deb$'
}

# https://www.veracrypt.fr/ — mount/analyse VeraCrypt and TrueCrypt volumes.
# The GUI build, not veracrypt-console: `^veracrypt-[0-9]` is what excludes the
# console asset, whose name shares the same prefix.
VERACRYPT_ASSET='^veracrypt-[0-9].*-Ubuntu-24\.04-amd64\.deb$'

function install-veracrypt() {
    print_status "INFO" "install-veracrypt"
    install-github-deb veracrypt/VeraCrypt veracrypt "${VERACRYPT_ASSET}"
}

function update-veracrypt() {
    update-github-deb veracrypt/VeraCrypt veracrypt "${VERACRYPT_ASSET}"
}

# https://vscodium.com/ — VS Code without Microsoft's telemetry and branding.
# From the project's own apt repo rather than a one-off .deb, so `apt upgrade`
# keeps it current and no update-vscodium is needed.
function install-vscodium() {
    print_status "INFO" "install-vscodium"
    if dpkg --status codium > /dev/null 2>&1; then
        return 0
    fi
    local key=/usr/share/keyrings/vscodium-archive-keyring.gpg
    print_status "INFO" "Installing VSCodium."
    {
        curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | \
            gpg --dearmor | sudo tee "${key}" > /dev/null
        sudo chmod 0644 "${key}"
        printf 'deb [signed-by=%s] https://download.vscodium.com/debs vscodium main\n' "${key}" | \
            sudo tee /etc/apt/sources.list.d/vscodium.list > /dev/null
        sudo apt-get -qq update
        sudo DEBIAN_FRONTEND=noninteractive apt-get -yqq install codium
    } >> "$LOG" 2>&1
    print_status "INFO" "Installed VSCodium."
}

# https://github.com/mandiant/capa — identify capabilities in executables.
# /usr/local/bin, as for floss above.
function install-capa() {
    print_status "INFO" "install-capa"
    if [[ ! -e /usr/local/bin/capa ]]; then
        local url tmpdir
        # The release also carries -linux-arm64 and -linux-py312 archives, so
        # anchor on the exact suffix rather than matching "linux".
        url="$(curl -s https://api.github.com/repos/mandiant/capa/releases/latest | \
            jq -r '.assets[] | select(.name | test("-linux\\.zip$"; "i")) | .browser_download_url' | head -1)"
        if [[ -z "$url" ]]; then
            print_status "ERROR" "Could not find capa Linux release on GitHub."
            return 1
        fi
        tmpdir="$(mktemp -d)"
        wget -q -O "${tmpdir}/capa.zip" "$url" >> "$LOG" 2>&1
        unzip -q -o "${tmpdir}/capa.zip" -d "${tmpdir}" >> "$LOG" 2>&1
        sudo install -m 755 -o root -g root "${tmpdir}/capa" /usr/local/bin/capa
        rm -rf "${tmpdir}"
        print_status "INFO" "Installed capa."
    fi
}

function update-capa() {
    print_status "INFO" "Update capa."
    sudo rm -f /usr/local/bin/capa
    install-capa
}

# https://github.com/google/docker-explorer — offline analysis of Docker
# containers and images found in a disk image.
#
# From the git checkout rather than PyPI, whose releases lag well behind the
# repository; update-git-repositories then keeps it current. The venv holds its
# `requests` dependency, and a /usr/local/bin wrapper with the paths baked in
# makes `de.py` available to every user and survives imaging.
function install-docker-explorer() {
    print_status "INFO" "install-docker-explorer"
    if [[ ! -d "${DFIR_SRC}"/docker-explorer ]]; then
        git clone --quiet https://github.com/google/docker-explorer.git \
            "${DFIR_SRC}"/docker-explorer >> "$LOG" 2>&1
        cd "${DFIR_SRC}"/docker-explorer || { print_status "ERROR" "Couldn't cd into install-docker-explorer."; exit 1; }
        _venv mkvirtualenv docker-explorer
        {
            _venv setvirtualenvproject
            pip install --upgrade pip
            pip install requests
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Checked out docker-explorer."
    fi
    if [[ ! -e /usr/local/bin/docker-explorer ]]; then
        {
            printf '#!/bin/sh\n'
            printf '# Wrapper generated by dfir-tools. https://github.com/google/docker-explorer\n'
            printf 'exec %s/docker-explorer/bin/python %s/docker-explorer/tools/de.py "$@"\n' \
                "${WORKON_HOME}" "${DFIR_SRC}"
        } | sudo tee /usr/local/bin/docker-explorer > /dev/null
        sudo chmod 0755 /usr/local/bin/docker-explorer
        print_status "INFO" "Installed the docker-explorer wrapper."
    fi
}

function update-docker-explorer() {
    if [[ -d "${DFIR_SRC}"/docker-explorer ]]; then
        # The checkout itself is refreshed by update-git-repositories; only the
        # venv dependencies need a pass here.
        _venv workon docker-explorer
        {
            pip install --upgrade pip
            pip install --upgrade requests
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Updated docker-explorer."
    fi
}

function enable-new-didier() {
    print_status "INFO" "Setting permissions on DidierStevensSuite scripts"
    if [[ -d "${DFIR_SRC}"/didierstevenssuite ]]; then
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/base64dump.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/byte-stats.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/cipher-tool.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/count.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/cut-bytes.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/decode*
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/defuzzer.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/emldump.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/extractscripts.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/file2vbscript.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/find-file-in-file.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/hex-to-bin.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/numbers*
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/oledump.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/pdf-parser.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/pdfid.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/pecheck.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/plugin_*
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/python-per-line.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/reextra.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/re-search.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/rtfdump.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/sets.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/shellcode*
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/split.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/translate.py
        chmod 755 "${DFIR_SRC}"/didierstevenssuite/zipdump.py
    fi
}

# Install Google Chrome
function install-google-chrome() {
    if [[ "$(uname -m)" == "aarch64" ]]; then
        if ! dpkg --status chromium > /dev/null 2>&1; then
            print_status "INFO" "Installing chromium."
            DEBIAN_FRONTEND=noninteractive sudo apt -yqq install chromium 2>&1 | tee -a "$LOG" > /dev/null
        fi
    else
        if ! dpkg --status google-chrome-stable > /dev/null 2>&1; then
            print_status "INFO" "Installing Google Chrome."
            cd /tmp || { print_status "ERROR" "Couldn't cd /tmp in install-google-chrome."; exit 1; }
            wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb >> "$LOG" 2>&1
            sudo dpkg -i google-chrome-stable_current_amd64.deb 2>&1 | tee -a "$LOG" > /dev/null || true
            sudo apt -qq -f -y install 2>&1 | tee -a "$LOG" > /dev/null
            rm -f google-chrome-stable_current_amd64.deb
        fi
    fi
}

# Install Volatility 3 via Abyss-W4tcher's vol_ez_install (docker-based).
# https://github.com/volatilityfoundation/volatility3
# https://github.com/Abyss-W4tcher/volatility-scripts
# vol_ez_install hard-codes ~/vol3, which would not survive imaging. We let it
# install there, then move the directory into DFIR_SRC and leave a ~/vol3
# symlink so the aliases (vol3d, volshell3d) keep working unchanged. The same
# symlink is placed in /etc/skel by sift-iso-builder, so the user created by the
# installer also gets ~/vol3 -> DFIR_SRC/vol3.
function relocate-vol3() {
    # DFIR_SRC is group-writable by `sudo` (mode 2775), so a sudo-group user can
    # move into it without sudo, and git stays writable for updates.
    if [[ -d ~/vol3 && ! -L ~/vol3 ]]; then
        rm -rf "${DFIR_SRC}"/vol3
        mv ~/vol3 "${DFIR_SRC}"/vol3
        ln -sfn "${DFIR_SRC}"/vol3 ~/vol3
    fi
}

function install-volatility() {
    print_status "INFO" "install-volatility"
    if [[ -d "${DFIR_SRC}"/vol3 ]]; then
        [[ ! -e ~/vol3 ]] && ln -sfn "${DFIR_SRC}"/vol3 ~/vol3
        return
    fi
    print_status "INFO" "Install volatility3 via vol_ez_install."
    {
        wget --quiet -O /tmp/vol_ez_install.sh \
            https://raw.githubusercontent.com/Abyss-W4tcher/volatility-scripts/master/vol_ez_install/vol_ez_install.sh
        chmod +x /tmp/vol_ez_install.sh
        /tmp/vol_ez_install.sh vol3_install
        rm -f /tmp/vol_ez_install.sh
    } >> "$LOG" 2>&1
    relocate-vol3
    print_status "INFO" "Installed volatility3."
}

function update-volatility() {
    if [[ -d "${DFIR_SRC}"/vol3 ]]; then
        cd "${DFIR_SRC}"/vol3 || { print_status "ERROR" "Couldn't cd into update-volatility."; exit 1; }
        print_status "INFO" "Update volatility3."
        {
            git fetch --all
            default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | \
                sed 's@^refs/remotes/origin/@@')" || default_branch="develop"
            git reset --hard "origin/${default_branch}"
        } >> "$LOG" 2>&1
        print_status "INFO" "Updated volatility3."
    fi
}

# https://github.com/mkorman90/regipy
function install-regipy() {
    print_status "INFO" "install-regipy"
    if [[ ! -d "${WORKON_HOME}"/regipy ]]; then
        _venv mkvirtualenv regipy
        {
            pip install --upgrade pip
            pip install "regipy[full]"
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Installed regipy."
    fi
}

function update-regipy() {
    if [[ -d "${WORKON_HOME}"/regipy ]]; then
        _venv workon regipy
        {
            pip install --upgrade pip
            pip install --upgrade "regipy[full]"
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Updated regipy."
    fi
}

# https://github.com/ZarKyo/Autopsy-docker
# The compose file is needed at run time by `docker compose up`, so it lives in
# DFIR_SRC alongside the other checkouts. The built image itself is in
# /var/lib/docker and is not affected by any of this.
AUTOPSY_DIR="${DFIR_SRC}"/Autopsy-docker

function install-autopsy-docker() {
    print_status "INFO" "install-autopsy-docker"
    if [[ ! -d ${AUTOPSY_DIR} ]]; then
        print_status "INFO" "Installing Autopsy-docker."
        checkout-git-repo https://github.com/ZarKyo/Autopsy-docker.git Autopsy-docker
        cd "${AUTOPSY_DIR}" || { print_status "ERROR" "Couldn't cd into install-autopsy-docker."; exit 1; }
        # The build pulls several GB with its output redirected to the log;
        # without this line it looks like a hang.
        print_status "INFO" "Building the Autopsy Docker image, this takes a while (see $LOG)."
        sudo docker compose build 2>&1 | tee -a "$LOG" > /dev/null || \
            print_status "WARNING" "docker compose build failed — check that docker is installed."
        print_status "INFO" "Installed Autopsy-docker."
    fi
}

function update-autopsy-docker() {
    if [[ -d ${AUTOPSY_DIR} ]]; then
        cd "${AUTOPSY_DIR}" || { print_status "ERROR" "Couldn't cd into update-autopsy-docker."; exit 1; }
        print_status "INFO" "Rebuilding the Autopsy Docker image, this takes a while (see $LOG)."
        {
            git fetch --all
            git reset --hard "origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')"
            sudo docker compose build --pull
        } >> "$LOG" 2>&1 || \
            print_status "WARNING" "Autopsy-docker update failed."
        print_status "INFO" "Updated Autopsy-docker."
    fi
}

# https://github.com/brendangregg/Chaosreader
# /usr/local/bin: on the default PATH, available to every user, and part of the
# rootfs so it survives imaging.
function install-chaosreader() {
    print_status "INFO" "install-chaosreader"
    if [[ ! -e /usr/local/bin/chaosreader ]]; then
        local tmpdir
        tmpdir="$(mktemp -d)"
        wget -q -O "${tmpdir}/chaosreader" \
            https://raw.githubusercontent.com/brendangregg/Chaosreader/master/chaosreader >> "$LOG" 2>&1
        sudo install -m 755 -o root -g root "${tmpdir}/chaosreader" /usr/local/bin/chaosreader
        rm -rf "${tmpdir}"
        print_status "INFO" "Installed chaosreader."
    fi
}

function update-chaosreader() {
    print_status "INFO" "Update chaosreader."
    sudo rm -f /usr/local/bin/chaosreader
    install-chaosreader
}

# https://github.com/mandiant/flare-floss
# /usr/local/bin, as for chaosreader above.
function install-floss() {
    print_status "INFO" "install-floss"
    if [[ ! -e /usr/local/bin/floss ]]; then
        local url tmpdir
        url="$(curl -s https://api.github.com/repos/mandiant/flare-floss/releases/latest | \
            jq -r '.assets[] | select(.name | test("linux"; "i")) | .browser_download_url' | head -1)"
        if [[ -z "$url" ]]; then
            print_status "ERROR" "Could not find floss Linux release on GitHub."
            return 1
        fi
        tmpdir="$(mktemp -d)"
        wget -q -O "${tmpdir}/floss_dl" "$url" >> "$LOG" 2>&1
        if file "${tmpdir}/floss_dl" | grep -q -i 'zip'; then
            unzip -q "${tmpdir}/floss_dl" -d "${tmpdir}" >> "$LOG" 2>&1
            sudo install -m 755 -o root -g root "${tmpdir}/floss" /usr/local/bin/floss
        else
            sudo install -m 755 -o root -g root "${tmpdir}/floss_dl" /usr/local/bin/floss
        fi
        rm -rf "${tmpdir}"
        print_status "INFO" "Installed floss."
    fi
}

function update-floss() {
    print_status "INFO" "Update floss."
    sudo rm -f /usr/local/bin/floss
    install-floss
}

# https://github.com/Lazza/RecuperaBit
function install-RecuperaBit() {
    print_status "INFO" "install-RecuperaBit"
    if [[ ! -d "${DFIR_SRC}"/RecuperaBit ]]; then
        git clone --quiet https://github.com/Lazza/RecuperaBit.git \
            "${DFIR_SRC}"/RecuperaBit >> "$LOG" 2>&1
        cd "${DFIR_SRC}"/RecuperaBit || { print_status "ERROR" "Couldn't cd into install-RecuperaBit."; exit 1; }
        _venv mkvirtualenv RecuperaBit
        {
            _venv setvirtualenvproject
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Checked out RecuperaBit."
    fi
}

function update-RecuperaBit() {
    if [[ -d "${DFIR_SRC}"/RecuperaBit ]]; then
        _venv workon RecuperaBit
        cd "${DFIR_SRC}"/RecuperaBit || { print_status "ERROR" "Couldn't cd into update-RecuperaBit."; exit 1; }
        {
            git fetch --all
            default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | \
                sed 's@^refs/remotes/origin/@@')" || default_branch="main"
            git reset --hard "origin/${default_branch}"
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Updated RecuperaBit."
    fi
}

# https://github.com/MarkBaggett/srum-dump
function install-srum-dump() {
    print_status "INFO" "install-srum-dump"
    if [[ ! -d "${DFIR_SRC}"/srum-dump ]]; then
        git clone --quiet https://github.com/MarkBaggett/srum-dump.git \
            "${DFIR_SRC}"/srum-dump >> "$LOG" 2>&1
        cd "${DFIR_SRC}"/srum-dump || { print_status "ERROR" "Couldn't cd into install-srum-dump."; exit 1; }
        _venv mkvirtualenv srum-dump
        {
            _venv setvirtualenvproject
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
            pip install impacket openpyxl python-registry
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Checked out srum-dump."
    fi
}

function update-srum-dump() {
    if [[ -d "${DFIR_SRC}"/srum-dump ]]; then
        _venv workon srum-dump
        cd "${DFIR_SRC}"/srum-dump || { print_status "ERROR" "Couldn't cd into update-srum-dump."; exit 1; }
        {
            git fetch --all
            default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | \
                sed 's@^refs/remotes/origin/@@')" || default_branch="main"
            git reset --hard "origin/${default_branch}"
        } >> "$LOG" 2>&1
        {
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
            pip install --upgrade impacket openpyxl python-registry
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Updated srum-dump."
    fi
}

# https://github.com/DidierStevens/DidierStevensSuite
function install-didierstevenssuite() {
    print_status "INFO" "install-didierstevenssuite"
    if [[ ! -d "${DFIR_SRC}"/didierstevenssuite ]]; then
        {
            git clone --quiet https://github.com/DidierStevens/DidierStevensSuite.git \
                "${DFIR_SRC}"/didierstevenssuite
        } >> "$LOG" 2>&1
        _venv mkvirtualenv didierstevenssuite
        { _venv setvirtualenvproject; } >> "$LOG" 2>&1
        enable-new-didier
        _venv deactivate
        print_status "INFO" "Checked out DidierStevensSuite."
    fi
}

function update-didierstevenssuite() {
    if [[ -d "${DFIR_SRC}"/didierstevenssuite ]]; then
        _venv workon didierstevenssuite
        cd "${DFIR_SRC}"/didierstevenssuite || { print_status "ERROR" "Couldn't cd into update-didierstevenssuite."; exit 1; }
        {
            git fetch --all
            default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | \
                sed 's@^refs/remotes/origin/@@')" || default_branch="main"
            git reset --hard "origin/${default_branch}"
        } >> "$LOG" 2>&1
        enable-new-didier
        _venv deactivate
        print_status "INFO" "Updated DidierStevensSuite."
    fi
}

# https://github.com/decalage2/oletools.git
function install-oletools() {
    print_status "INFO" "install-oletools"
    if [[ ! -d "${WORKON_HOME}"/oletools ]]; then
        _venv mkvirtualenv oletools
        {
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
            pip install oletools
        } >> "$LOG" 2>&1
        print_status "INFO" "Installed oletools."
    fi
}

function update-oletools() {
    if [[ -d "${WORKON_HOME}"/oletools ]]; then
        _venv workon oletools
        pip install --upgrade pip >> "$LOG" 2>&1
        pip install --upgrade oletools >> "$LOG" 2>&1
        print_status "INFO" "Updated oletools."
    fi
}

# https://github.com/bontchev/pcodedmp
function install-pcodedmp() {
    print_status "INFO" "install-pcodedmp"
    if [[ ! -d "${DFIR_SRC}"/pcodedmp ]]; then
        git clone --quiet https://github.com/bontchev/pcodedmp.git \
            "${DFIR_SRC}"/pcodedmp >> "$LOG" 2>&1
        cd "${DFIR_SRC}"/pcodedmp || { print_status "ERROR" "Couldn't cd into install-pcodedmp."; exit 1; }
        _venv mkvirtualenv pcodedmp
        {
            _venv setvirtualenvproject
            pip install --upgrade pip setuptools
            pip install oletools
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Installed pcodedmp."
    fi
}

function update-pcodedmp() {
    if [[ -d "${DFIR_SRC}"/pcodedmp ]]; then
        _venv workon pcodedmp
        cd "${DFIR_SRC}"/pcodedmp || { print_status "ERROR" "Couldn't cd into update-pcodedmp."; exit 1; }
        {
            git fetch --all
            default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | \
                sed 's@^refs/remotes/origin/@@')" || default_branch="main"
            git reset --hard "origin/${default_branch}"
        } >> "$LOG" 2>&1
        _venv deactivate
        print_status "INFO" "Updated pcodedmp."
    fi
}

# https://github.com/keydet89/RegRipper4.0
function install-regripper() {
    print_status "INFO" "install-regripper"
    if [[ ! -d "${DFIR_SRC}"/RegRipper4.0 ]]; then
        checkout-git-repo https://github.com/keydet89/RegRipper4.0.git RegRipper4.0
        print_status "INFO" "Checked out RegRipper4.0."
    fi
    # The wrapper is resolved relative to this file rather than to a checkout
    # path, and installed system-wide so every user gets the `regripper`
    # command.
    if [[ ! -e /usr/local/bin/regripper ]]; then
        sudo install -m 755 -o root -g root \
            "$(dirname "${BASH_SOURCE[0]}")/../files/regripper" /usr/local/bin/regripper
    fi
}

# https://github.com/radare/radare2
function install-radare2() {
    print_status "INFO" "install-radare2"
    if [[ ! -d "${DFIR_SRC}"/radare2 ]]; then
        print_status "INFO" "Starting installation of radare2."
        sudo apt remove -y radare2 2>&1 | tee -a "$LOG" > /dev/null
        sudo apt-get autoremove -y 2>&1 | tee -a "$LOG" > /dev/null
        checkout-git-repo https://github.com/radare/radare2.git radare2
        cd "${DFIR_SRC}"/radare2 || { print_status "ERROR" "Couldn't cd into install-radare2."; exit 1; }
        make clean >> "$LOG" 2>&1 || true
        ./sys/install.sh >> "$LOG" 2>&1 || print_status "ERROR" "./sys/install.sh failed!"
        print_status "INFO" "Installed radare2."
    fi
}

function update-radare2() {
    print_status "INFO" "update-radare2"
    if [[ -d "${DFIR_SRC}"/radare2 ]]; then
        sudo apt remove -y radare2 2>&1 | tee -a "$LOG" > /dev/null
        sudo apt-get autoremove -y 2>&1 | tee -a "$LOG" > /dev/null
        cd "${DFIR_SRC}"/radare2 || { print_status "ERROR" "Couldn't cd into update-radare2."; exit 1; }
        {
            git fetch --all
            git reset --hard origin/master
            ./sys/install.sh
        } >> "$LOG" 2>&1
        print_status "INFO" "Updated radare2."
    fi
}

####################
# SIFT
####################

function install-sift() {
    if [[ ! -e ~/.config/.sift ]]; then
        print_status "INFO" "Start installation of SIFT."
        cd /tmp || true
        {
            sudo apt-get autoremove -y
            if [[ $(uname -m) == "x86_64" ]]; then
                ARCH="amd64"
            else
                ARCH="arm64"
            fi
            wget "$(curl -s https://api.github.com/repos/ekristen/cast/releases/latest | jq . |
                grep 'browser_' | grep deb | grep -v deb.sig | grep "$ARCH" | cut -d\" -f4 | head -1)"
            wget "$(curl -s https://api.github.com/repos/ekristen/cast/releases/latest | jq . |
                grep 'browser_' | grep deb | grep -v deb.sig | grep "$ARCH" | cut -d\" -f4 | tail -1)"
        } >> "$LOG" 2>&1
        # Does not validate gpg at the moment due to problems downloading keys in some networks...
        sudo dpkg -i cast*.deb
        sudo systemctl stop ssh.service
        sudo /usr/bin/cast install teamdfir/sift-saltstack 2>&1 | tee -a "$LOG"
        sudo systemctl start ssh.service
        touch ~/.config/.sift
        print_status "INFO" "SIFT installation finished."
    fi
}

function update-sift() {
    START_FRESHCLAM=1
    print_status "INFO" "Start SIFT upgrade."
    if sudo service clamav-freshclam status 2>&1 | tee -a "$LOG" | grep -q "Active: active"; then
        sudo service clamav-freshclam stop 2>&1 | tee -a "$LOG" > /dev/null
        START_FRESHCLAM=0
    fi
    {
        sudo /usr/local/bin/sift update || true
        # Two passes: salt exits 0 even when individual states failed, and a
        # second run tends to settle those. The first pass is allowed to fail
        # outright — without `|| true`, set -e would abort here and the retry
        # would never run, which is exactly the case it exists for. The second
        # pass is NOT tolerated, so an upgrade that is genuinely broken still
        # stops the script instead of being reported as a success.
        sudo /usr/local/bin/sift upgrade || true
        sudo /usr/local/bin/sift upgrade
    } >> "$LOG" 2>&1
    print_status "INFO" "SIFT upgrade finished."
    if [[ $START_FRESHCLAM -eq 0 ]]; then
        sudo service clamav-freshclam start 2>&1 | tee -a "$LOG" > /dev/null
    fi
}

function cleanup-sift() {
    if [[ -e ~/examples.desktop ]]; then
        print_status "INFO" "Clean up folders and files."
        rm -f ~/examples.desktop
    fi
    # The SIFT posters and cheat sheets are reference material, not user data:
    # they belong to the system, not to one account. Kept in /usr/local/share
    # so they survive imaging, with symlinks providing the familiar
    # ~/Documents/SIFT and ~/Desktop/SIFT entries.
    local docs=/usr/local/share/sift-docs

    if [[ -e ~/Desktop/SIFT-Cheatsheet.pdf ]]; then
        print_status "INFO" "Clean Desktop."
        sudo install -d -m 755 -o root -g root "$docs"
        sudo install -m 644 -o root -g root ~/Desktop/*.pdf "$docs"/ || true
        rm -f ~/Desktop/*.pdf
    fi

    # A real directory here means the PDFs are not yet in $docs.
    if [[ -d ~/Documents/SIFT && ! -L ~/Documents/SIFT ]]; then
        print_status "INFO" "Move SIFT documents to $docs."
        sudo install -d -m 755 -o root -g root "$docs"
        sudo install -m 644 -o root -g root ~/Documents/SIFT/*.pdf "$docs"/ || true
        rm -rf ~/Documents/SIFT
    fi

    if [[ -d $docs ]]; then
        mkdir -p ~/Documents
        [[ ! -e ~/Documents/SIFT ]] && ln -s "$docs" ~/Documents/SIFT
        [[ -L ~/Desktop/SIFT ]] && rm -f ~/Desktop/SIFT
        [[ ! -e ~/Desktop/SIFT ]] && ln -s "$docs" ~/Desktop/SIFT
    fi
    return 0
}

function remove-old() {
    # Fixes from https://github.com/sans-dfir/sift/issues/106#issuecomment-251566412
    if [[ -e /etc/apt/sources.list.d/google-chrome.list ]]; then
        print_status "INFO" "Remove old versions of Chrome."
        sudo rm -f /etc/apt/sources.list.d/google-chrome.list*
    fi

    # Remove old wireshark. Caused errors during update
    if dpkg -l wireshark | grep 1.12 >> "$LOG" 2>&1; then
        print_status "INFO" "Remove old versions of wireshark."
        sudo apt -yqq remove wireshark 2>&1 | tee -a "$LOG" > /dev/null
    fi
}

####################
# REMnux
####################

function install-apt-remnux() {
    print_status "INFO" "Installing apt-packages for REMnux."
    # sleuthkit provides hfind(1)
    sudo apt -yqq install \
        mpack \
        sleuthkit \
        testdisk \
        tree 2>&1 | tee -a "$LOG" > /dev/null
}

function install-remnux() {
    if [[ ! -e ~/.config/.remnux ]]; then
        print_status "INFO" "Start installation of REMnux."
        rm -f remnux
        wget --quiet https://REMnux.org/remnux
        mv remnux remnux
        chmod +x remnux
        sudo mv remnux /usr/local/bin
        sudo apt install -y gnupg
        sudo systemctl stop ssh.service
        sudo /usr/local/bin/remnux install --version=v2026.6.24 --mode=dedicated 2>&1 | tee -a "$LOG"
        sudo systemctl start ssh.service
        touch ~/.config/.remnux
        print_status "INFO" "REMnux installation finished."
    fi
}

# Cleanup functions
function cleanup-remnux() {
    if [[ -e ~/examples.desktop ]]; then
        print_status "INFO" "Clean up folders and files."
        rm -f ~/examples.desktop
    fi
    if [[ -e ~/Desktop/REMnux\ Cheat\ Sheet ]]; then
        print_status "INFO" "Clean Desktop."
        [ ! -d ~/Documents/REMnux ] && mkdir -p ~/Documents/REMnux
        [ -e ~/Desktop/REMnux\ Docs ] && mv -f ~/Desktop/REMnux\ Docs ~/Documents/REMnux/
        [ -e ~/Desktop/REMnux\ Tools\ Sheet ] && mv -f ~/Desktop/REMnux\ Tools\ Sheet ~/Documents/REMnux/
        [ -e ~/Desktop/REMnux\ Cheat\ Sheet ] && mv -f ~/Desktop/REMnux\ Cheat\ Sheet ~/Documents/REMnux/
        if [[ ! -e ~/Desktop/cases ]]; then
            ln -s /cases ~/Desktop/cases || true
        fi
        if [[ ! -e ~/Desktop/REMnux ]]; then
            ln -s ~/Documents/REMnux ~/Desktop/REMnux || true
        fi
    fi
}
