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
    if [[ "$tag" == "ERROR" ]]; then
        printf "${tclr}%s${NC}\n" "$msg" >&2
    else
        printf "${tclr}%s${NC}\n" "$msg"
    fi
}

# Check root rights
function check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This script must be run as root !" >&2
        exit 1
    fi
}

# Checkout git repo to directory
function checkout-git-repo() {
    echo "Checkout $2 to $1" >> "$LOG" 2>&1
    if [[ ! -d ~/src/git/"$2" ]]; then
        git clone --quiet "$1" ~/src/git/"$2" >> "$LOG" 2>&1
        print_status "INFO" "Checkout git repo $1"
    fi
}

# Update git repositories
function update-git-repositories() {
    cd ~/src/git || exit 1
    print_status "INFO" "Update git repositories."
    shopt -s nullglob
    for repo in *; do
        print_status "INFO" "Updating $repo."
        (
            cd "$repo" || error-exit-message "Couldn't cd into update-git-repositories"
            git fetch --all >> "$LOG" 2>&1
            git reset --hard origin/master >> "$LOG" 2>&1
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
        echo "APT busy. Will retry in 10 seconds."
        sleep 10
    done
}

####################
# System setup
####################

# Turn off sound on start up
function turn-off-sound() {
    if [[ ! -e /usr/share/glib-2.0/schemas/50_unity-greeter.gschema.override ]]; then
        echo "turn-off-sound" >> "$LOG" 2>&1
        echo -e '[com.canonical.unity-greeter]\nplay-ready-sound = false' |
            sudo tee -a /usr/share/glib-2.0/schemas/50_unity-greeter.gschema.override > /dev/null
        sudo glib-compile-schemas /usr/share/glib-2.0/schemas/
    fi
}

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

    local src_dirs=(bin git python)
    for dir in "${src_dirs[@]}"; do
        mkdir -p ~/src/"$dir"
    done

    local mnt_dirs=(
        aff bde e01 evidence1 ewf ewf_mount
        ext ext4 hgfs iscsi
        linux-mount1 linux-mount2 linux-mount3
        linux-mount4 linux-mount5 linux-mount6
        linux-mount7 linux-mount8 linux-mount9
        windows_mount shadow_mount usb vss
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
            chmod 777 ~/docker/$dir
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

# Fix problem with pip - https://github.com/pypa/pip/issues/1093
function fix-python-pip() {
    if [[ ! -e /usr/local/bin/pip ]]; then
        {
            sudo apt remove -yqq --auto-remove python-pip
            wget --quiet -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
            sudo -H python /tmp/get-pip.py
            sudo ln -s /usr/local/bin/pip /usr/bin/pip
            sudo rm /tmp/get-pip.py
            sudo -H pip install pyopenssl ndg-httpsclient pyasn1
            sudo -H pip install --upgrade "urllib3[secure]"
        } >> "$LOG" 2>&1
        print_status "INFO" "Install pip from pypa.io."
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
        git \
        htop \
        jq \
        libffi-dev \
        libimage-exiftool-perl \
        libncurses5-dev \
        libssl-dev \
        p7zip \
        python3-dev \
        python3-virtualenv \
        screen \
        sharutils \
        sqlite3 \
        sqlitebrowser \
        strace \
        tmux \
        tshark \
        vim \
        vim-doc \
        vim-scripts \
        virtualenvwrapper \
        wget \
        whois \
        wswedish \
        nano \
        zip 2>&1 | tee -a "$LOG" > /dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt -yqq install \
        unrar 2>&1 | tee -a "${LOG}" > /dev/null ||
        sudo DEBIAN_FRONTEND=noninteractive apt -yqq install \
            unrar-free 2>&1 | tee -a "${LOG}" > /dev/null
}

function enable-new-didier() {
    echo "enable-new-didier" >> "$LOG" 2>&1
    if [[ -d ~/src/python/didierstevenssuite ]]; then
        chmod 755 ~/src/python/didierstevenssuite/
        chmod 755 ~/src/python/didierstevenssuite/base64dump.py
        chmod 755 ~/src/python/didierstevenssuite/byte-stats.py
        chmod 755 ~/src/python/didierstevenssuite/cipher-tool.py
        chmod 755 ~/src/python/didierstevenssuite/count.py
        chmod 755 ~/src/python/didierstevenssuite/cut-bytes.py
        chmod 755 ~/src/python/didierstevenssuite/decode*
        chmod 755 ~/src/python/didierstevenssuite/defuzzer.py
        chmod 755 ~/src/python/didierstevenssuite/emldump.py
        chmod 755 ~/src/python/didierstevenssuite/extractscripts.py
        chmod 755 ~/src/python/didierstevenssuite/file2vbscript.py
        chmod 755 ~/src/python/didierstevenssuite/find-file-in-file.py
        chmod 755 ~/src/python/didierstevenssuite/hex-to-bin.py
        chmod 755 ~/src/python/didierstevenssuite/numbers*
        chmod 755 ~/src/python/didierstevenssuite/oledump.py
        chmod 755 ~/src/python/didierstevenssuite/pdf-parser.py
        chmod 755 ~/src/python/didierstevenssuite/pdfid.py
        chmod 755 ~/src/python/didierstevenssuite/pecheck.py
        chmod 755 ~/src/python/didierstevenssuite/plugin_*
        chmod 755 ~/src/python/didierstevenssuite/python-per-line.py
        chmod 755 ~/src/python/didierstevenssuite/reextra.py
        chmod 755 ~/src/python/didierstevenssuite/re-search.py
        chmod 755 ~/src/python/didierstevenssuite/rtfdump.py
        chmod 755 ~/src/python/didierstevenssuite/sets.py
        chmod 755 ~/src/python/didierstevenssuite/shellcode*
        chmod 755 ~/src/python/didierstevenssuite/split.py
        chmod 755 ~/src/python/didierstevenssuite/translate.py
        chmod 755 ~/src/python/didierstevenssuite/zipdump.py
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
            cd /tmp || error-exit-message "Couldn't cd /tmp in install-google-chrome."
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
function install-volatility() {
    echo "install-volatility" >> "$LOG" 2>&1
    if [[ -d ~/vol3 ]]; then
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
    print_status "INFO" "Installed volatility3."
}

function update-volatility() {
    if [[ -d ~/vol3 ]]; then
        cd ~/vol3 || error-exit-message "Couldn't cd into update-volatility."
        print_status "INFO" "Update volatility3."
        {
            git fetch --all
            git reset --hard origin/develop
        } >> "$LOG" 2>&1
        print_status "INFO" "Updated volatility3."
    fi
}

# https://github.com/mkorman90/regipy
function install-regipy() {
    echo "install-regipy" >> "$LOG" 2>&1
    if [[ ! -d ~/.virtualenvs/regipy ]]; then
        {
            mkvirtualenv regipy || true
            pip install --upgrade pip
            pip install "regipy[full]"
        } >> "$LOG" 2>&1
        deactivate || true
        print_status "INFO" "Installed regipy."
    fi
}

function update-regipy() {
    if [[ -d ~/.virtualenvs/regipy ]]; then
        workon regipy || true
        {
            pip install --upgrade pip
            pip install --upgrade "regipy[full]"
        } >> "$LOG" 2>&1
        deactivate || true
        print_status "INFO" "Updated regipy."
    fi
}

# https://github.com/ZarKyo/Autopsy-docker
function install-autopsy-docker() {
    echo "install-autopsy-docker" >> "$LOG" 2>&1
    if [[ ! -d ~/src/git/Autopsy-docker ]]; then
        print_status "INFO" "Installing Autopsy-docker."
        checkout-git-repo https://github.com/ZarKyo/Autopsy-docker.git Autopsy-docker
        cd ~/src/git/Autopsy-docker || error-exit-message "Couldn't cd into install-autopsy-docker."
        sudo docker compose build 2>&1 | tee -a "$LOG" > /dev/null || \
            print_status "WARNING" "docker compose build failed — check that docker is installed."
        print_status "INFO" "Installed Autopsy-docker."
    fi
}

function update-autopsy-docker() {
    if [[ -d ~/src/git/Autopsy-docker ]]; then
        cd ~/src/git/Autopsy-docker || error-exit-message "Couldn't cd into update-autopsy-docker."
        {
            git fetch --all
            git reset --hard "origin/$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')"
            sudo docker compose build --pull
        } >> "$LOG" 2>&1 || \
            print_status "WARNING" "Autopsy-docker update failed."
        print_status "INFO" "Updated Autopsy-docker."
    fi
}

# This repo contians newer versions of Wireshark etc. Update again after adding
function install-pi-rho-security() {
    if [[ ! -e /etc/apt/sources.list.d/pi-rho-security-trusty.list ]]; then
        print_status "INFO" "Enable ppa:pi-rho/security and install updated packages."
        {
            sudo add-apt-repository -y ppa:pi-rho/security
            sudo apt -qq update
            while ! sudo apt -y dist-upgrade --force-yes; do
                echo "APT busy. Will retry in 10 seconds."
                sleep 10
            done
            sudo apt -qq -y install html2text nasm
            sudo apt-get autoremove -qq -y
        } >> "$LOG" 2>&1
    fi
}

# https://github.com/brendangregg/Chaosreader
function install-chaosreader() {
    echo "install-chaosreader" >> "$LOG" 2>&1
    if [[ ! -e ~/src/bin/chaosreader ]]; then
        wget -q -O ~/src/bin/chaosreader \
            https://raw.githubusercontent.com/brendangregg/Chaosreader/master/chaosreader >> "$LOG" 2>&1
        chmod +x ~/src/bin/chaosreader
        print_status "INFO" "Installed chaosreader."
    fi
}

function update-chaosreader() {
    print_status "INFO" "Update chaosreader."
    rm -f ~/src/bin/chaosreader
    install-chaosreader
}

# Fireeye floss
function install-floss() {
    echo "install-floss" >> "$LOG" 2>&1
    if [[ ! -e ~/src/bin/floss ]]; then
        wget -q -O ~/src/bin/floss \
            https://s3.amazonaws.com/build-artifacts.floss.flare.fireeye.com/travis/linux/dist/floss >> "$LOG" 2>&1
        chmod +x ~/src/bin/floss
        print_status "INFO" "Installed floss."
    fi
}

function update-floss() {
    print_status "INFO" "Update floss."
    rm -f ~/src/bin/floss
    install-floss
}

# https://github.com/Lazza/RecuperaBit
function install-RecuperaBit() {
    echo "install-RecuperaBit" >> "$LOG" 2>&1
    if [[ ! -d ~/src/python/RecuperaBit ]]; then
        git clone --quiet https://github.com/Lazza/RecuperaBit.git \
            ~/src/python/RecuperaBit >> "$LOG" 2>&1
        cd ~/src/python/RecuperaBit || error-exit-message "Couldn't cd into install-RecuperaBit."
        mkvirtualenv RecuperaBit >> "$LOG" 2>&1 || true
        {
            setvirtualenvproject
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
        } >> "$LOG" 2>&1
        deactivate || true
        print_status "INFO" "Checked out RecuperaBit."
    fi
}

function update-RecuperaBit() {
    if [[ -d ~/src/python/RecuperaBit ]]; then
        workon RecuperaBit || true
        {
            git fetch --all
            git reset --hard origin/master
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
        } >> "$LOG" 2>&1
        deactivate || true
        print_status "INFO" "Updated RecuperaBit."
    fi
}

# https://github.com/MarkBaggett/srum-dump
function install-srum-dump() {
    echo "install-srum-dump" >> "$LOG" 2>&1
    if [[ ! -d ~/src/python/srum-dump ]]; then
        git clone --quiet https://github.com/MarkBaggett/srum-dump.git \
            ~/src/python/srum-dump >> "$LOG" 2>&1
        cd ~/src/python/srum-dump || error-exit-message "Couldn't cd into install-srum-dump."
        mkvirtualenv srum-dump >> "$LOG" 2>&1 || true
        {
            setvirtualenvproject
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
            pip install impacket openpyxl python-registry
        } >> "$LOG" 2>&1
        deactivate || true
        print_status "INFO" "Checked out srum-dump."
    fi
}

function update-srum-dump() {
    if [[ -d ~/src/python/srum-dump ]]; then
        workon srum-dump || true
        git fetch --all >> "$LOG" 2>&1
        git reset --hard origin/master >> "$LOG" 2>&1
        pip install --upgrade pip
        pip install --upgrade "urllib3[secure]"
        pip install --upgrade impacket openpyxl python-registry
        deactivate || true
        print_status "INFO" "Updated srum-dump."
    fi
}

# https://github.com/DidierStevens/DidierStevensSuite
function install-didierstevenssuite() {
    echo "install-didierstevenssuite" >> "$LOG" 2>&1
    if [[ ! -d ~/src/python/didierstevenssuite ]]; then
        {
            git clone --quiet https://github.com/DidierStevens/DidierStevensSuite.git \
                ~/src/python/didierstevenssuite
            mkvirtualenv didierstevenssuite || true
            setvirtualenvproject
        } >> "$LOG" 2>&1
        enable-new-didier
        deactivate || true
        print_status "INFO" "Checked out DidierStevensSuite."
    fi
}

function update-didierstevenssuite() {
    if [[ -d ~/src/python/didierstevenssuite ]]; then
        workon didierstevenssuite || true
        cd ~/src/python/didierstevenssuite || error-exit-message "Couldn't cd into update-didierstevenssuite."
        git fetch --all >> "$LOG" 2>&1
        git reset --hard origin/master >> "$LOG" 2>&1
        enable-new-didier
        deactivate || true
        print_status "INFO" "Updated DidierStevensSuite."
    fi
}

# https://github.com/decalage2/oletools.git
function install-oletools() {
    echo "install-oletools" >> "$LOG" 2>&1
    if [[ ! -d ~/.virtualenvs/oletools ]]; then
        {
            mkvirtualenv oletools || true
            pip install --upgrade pip
            pip install --upgrade "urllib3[secure]"
            pip install oletools
        } >> "$LOG" 2>&1
        print_status "INFO" "Installed oletools."
    fi
}

function update-oletools() {
    if [[ -d ~/.virtualenvs/oletools ]]; then
        workon oletools || true
        pip install --upgrade pip >> "$LOG" 2>&1
        pip install --upgrade oletools >> "$LOG" 2>&1
        print_status "INFO" "Updated oletools."
    fi
}

# https://github.com/bontchev/pcodedmp
function install-pcodedmp() {
    echo "install-pcodedmp" >> "$LOG" 2>&1
    if [[ ! -d ~/src/python/pcodedmp ]]; then
        {
            git clone --quiet https://github.com/bontchev/pcodedmp.git \
                ~/src/python/pcodedmp
            mkvirtualenv pcodedmp || true
            pip install --upgrade pip setuptools
            pip install oletools
        } >> "$LOG" 2>&1
        deactivate || true
        print_status "INFO" "Installed pcodedmp."
    fi
}

function update-pcodedmp() {
    if [[ -d ~/src/python/pcodedmp ]]; then
        workon pcodedmp || true
        cd ~/src/python/pcodedmp || error-exit-message "Couldn't cd into update-pcodedmp."
        git fetch --all >> "$LOG" 2>&1
        git reset --hard origin/master >> "$LOG" 2>&1
        deactivate || true
        print_status "INFO" "Updated pcodedmp."
    fi
}

# https://github.com/keydet89/RegRipper4.0
function install-regripper() {
    echo "install-regripper" >> "$LOG" 2>&1
    if [[ ! -d ~/src/git/RegRipper4.0 ]]; then
        git clone --quiet https://github.com/keydet89/RegRipper4.0.git \
            ~/src/git/RegRipper4.0 >> "$LOG" 2>&1
        print_status "INFO" "Checked out RegRipper4.0."
        ln -s ~/dfir-tools/files/regripper ~/src/bin/regripper
        chmod 755 ~/dfir-tools/files/regripper
    fi
}

# https://github.com/radare/radare2
function install-radare2() {
    echo "install-radare2" >> "$LOG" 2>&1
    if [[ ! -d ~/src/git/radare2 ]]; then
        print_status "INFO" "Starting installation of radare2."
        sudo apt remove -y radare2 2>&1 | tee -a "$LOG" > /dev/null
        sudo apt-get autoremove -y 2>&1 | tee -a "$LOG" > /dev/null
        checkout-git-repo https://github.com/radare/radare2.git radare2
        cd ~/src/git/radare2 || error-exit-message "Couldn't cd into install-radare2."
        make clean >> "$LOG" 2>&1 || true
        ./sys/install.sh >> "$LOG" 2>&1 || error-message "./sys/install.sh failed!"
        print_status "INFO" "Installed radare2."
    fi
}

function update-radare2() {
    echo "update-radare2" >> "$LOG" 2>&1
    if [[ -d ~/src/git/radare2 ]]; then
        sudo apt remove -y radare2 2>&1 | tee -a "$LOG" > /dev/null
        sudo apt-get autoremove -y 2>&1 | tee -a "$LOG" > /dev/null
        cd ~/src/git/radare2 || error-exit-message "Couldn't cd into update-radare2."
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
        # --pre-release: enables Ubuntu 24.04 support (unstable salt states); uncomment when ready
        # sudo /usr/bin/cast install --pre-release teamdfir/sift-saltstack 2>&1 | tee -a "$LOG"
        sudo /usr/bin/cast install teamdfir/sift-saltstack 2>&1 | tee -a "$LOG"
        sudo systemctl start ssh.service
        touch ~/.config/.sift
        print_status "INFO" "SITF installation finished."
    fi
}

function update-sift() {
    START_FRESHCLAM=1
    print_status "INFO" "Start SITF upgrade."
    if sudo service clamav-freshclam status 2>&1 | tee -a "$LOG" | grep -q "Active: active"; then
        sudo service clamav-freshclam stop 2>&1 | tee -a "$LOG" > /dev/null
        START_FRESHCLAM=0
    fi
    {
        sudo /usr/local/bin/sift update || true
        sudo /usr/local/bin/sift upgrade
        # Run upgrade twice since I often seen some fails the first time
        sudo /usr/local/bin/sift upgrade
    } >> "$LOG" 2>&1
    print_status "INFO" "SITF upgrade finished."
    if [[ $START_FRESHCLAM -eq 0 ]]; then
        sudo service clamav-freshclam start 2>&1 | tee -a "$LOG" > /dev/null
    fi
}

function cleanup-sift() {
    if [[ -e ~/examples.desktop ]]; then
        print_status "INFO" "Clean up folders and files."
        rm -f ~/examples.desktop
    fi
    if [[ -e ~/Desktop/SIFT-Cheatsheet.pdf ]]; then
        print_status "INFO" "Clean Desktop."
        [ ! -d ~/Documents/SIFT ] && mkdir -p ~/Documents/SIFT
        mv ~/Desktop/*.pdf ~/Documents/SIFT/ || true
        [ ! -e ~/Desktop/SIFT ] && ln -s ~/Documents/SIFT ~/Desktop/SIFT
    fi
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
        rm -f remnux-cli
        wget --quiet https://REMnux.org/remnux-cli
        mv remnux-cli remnux
        chmod +x remnux
        sudo mv remnux /usr/local/bin
        sudo apt install -y gnupg
        sudo systemctl stop ssh.service
        sudo /usr/local/bin/remnux install
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
