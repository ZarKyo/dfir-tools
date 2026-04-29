#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# -e : exit immediately on error
# -u : treat unset variables as errors
# -o pipefail : fail if any command in a pipeline fails
# IFS : safer word splitting
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${DFIR_MODE:-0}" != "1" ]] && [[ -e ~/.config/.remnux ]]; then
    printf '\033[0;31mYou have already installed REMnux! Install SIFT in separate VM.\033[0m\n' >&2
    exit 1
fi

#################### 
# Vars
####################

# For apt
export DEBIAN_FRONTEND=noninteractive

export VM_USER=user
export LOG=/tmp/sift.log
touch $LOG

# Force sudo password prompt early
sudo -v

#################### 
# Source
####################

# shellcheck source=/dev/null
if [[ -e "${SCRIPT_DIR}/../common/bin/utils.sh" ]]; then
    . "${SCRIPT_DIR}/../common/bin/utils.sh"
else
    printf '\033[0;31mCant find utils.sh.\033[0m\n' >&2
    exit 1
fi

####################
# Start
####################

print_status "INFO" "Starting installation of SIFT."
print_status "INFO" "Details logged to $LOG."

update-ubuntu

install-general-tools
install-vmware-tools
install-utils
install-docker

set +e
install-sift
cleanup-sift
set -e

create-common-directories
create-docker-directories
create-cases-not-mounted

install-google-chrome

print_status "INFO" "Setup virtualenvwrapper."
# virtualenvwrapper.sh uses uninitialized variables (e.g. out_args) that
# trip set -u; disable it only for the source call.
set +u
# shellcheck source=/dev/null
source /usr/share/virtualenvwrapper/virtualenvwrapper.sh
set -u

install-chaosreader
install-floss
install-RecuperaBit
install-volatility
install-regipy
install-autopsy-docker

# Install aliases for SIFT. This way we can update them without
# affecting .bash_aliases.
cp "${SCRIPT_DIR}/.sift_aliases" ~/.sift_aliases

CONF_FILE="$HOME/.config/.manual_conf"

# Function to display and save a message
log_manual() {
    print_status "WARNING" "$1"
    echo "$1" >> "$CONF_FILE"
}

# Check if the configuration file already exists
if [[ ! -e "$CONF_FILE" ]]; then
    log_manual "##################################################################"
    log_manual "Remember to change the following things:"
    log_manual "1. Change desktop resolution to be able to do the other steps."
    log_manual "2. Security & Privacy -> Search -> Turn off online search results."
    log_manual "3. -> Diagnostics -> Turn off error reports."
    log_manual "4. Run 'make dotfiles' in ~/src/bin/dfir-tools for .bashrc etc."
    log_manual "##################################################################"

    # Create the config file to avoid repeating this block
    mkdir -p "$(dirname "$CONF_FILE")"
    touch "$CONF_FILE"
else
    print_status "SUCCESS" "Update with setup-sift.sh done."
    echo "Update with setup-sift.sh done." >> "$CONF_FILE"
fi

