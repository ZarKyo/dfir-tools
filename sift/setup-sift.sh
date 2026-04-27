#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# -e : exit immediately on error
# -u : treat unset variables as errors
# -o pipefail : fail if any command in a pipeline fails
# IFS : safer word splitting
set -euo pipefail
IFS=$'\n\t'

if [[ "${DFIR_MODE:-0}" != "1" ]] && [[ -e ~/.config/.remnux ]]; then
    echo "You have already installed REMnux! Install SIFT in separate VM."
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
if [[ -e ~/bin/dfir-tools/utils.sh ]]; then
    . ~/bin/dfir-tools/utils.sh
else
    echo "Cant find utils.sh."
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

install-sift
cleanup-sift

create-common-directories
create-docker-directories
create-cases-not-mounted

install-google-chrome

print_status "INFO" "Setup virtualenvwrapper."
# Use virtualenvwrapper for python tools
export WORKON_HOME=$HOME/src/python
export VIRTUALENVWRAPPER_HOOK_DIR=$HOME/src/python/hooks
# Prevent virtualenvwrapper from failing under 'set -u'
export ZSH_VERSION=""
# shellcheck source=/dev/null
source /usr/share/virtualenvwrapper/virtualenvwrapper.sh

install-chaosreader
install-dcp
install-floss
install-RecuperaBit

turn-off-sound

# Install aliases for SIFT. This way we can update them without
# affecting .bash_aliases.
cp ~/dfir-tools/sift/.sift_aliases ~/.sift_aliases

CONF_FILE="$HOME/.config/.manual_conf"

# Function to display and save a message
log_manual() {
    echo "$1" | tee -a "$CONF_FILE"
}

# Check if the configuration file already exists
if [[ ! -e "$CONF_FILE" ]]; then
    log_manual "##################################################################"
    log_manual "Remember to change the following things:"
    log_manual "1. Change desktop resolution to be able to do the other steps."
    log_manual "2. Security & Privacy -> Search -> Turn off online search results."
    log_manual "3. -> Diagnostics -> Turn off error reports."
    log_manual "4. Run 'make dotfiles' in ~/dfir-tools for .bashrc etc."
    log_manual "##################################################################"

    # Create the config file to avoid repeating this block
    mkdir -p "$(dirname "$CONF_FILE")"
    touch "$CONF_FILE"
else
    log_manual "INFO: Update with setup-sift.sh done."
fi

