#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# -e : exit immediately on error
# -u : treat unset variables as errors
# -o pipefail : fail if any command in a pipeline fails
# IFS : safer word splitting
set -euo pipefail
IFS=$'\n\t'

if [[ -e ~/.config/.remnux ]]; then
    printf '\033[0;31mYou have already installed REMnux! Use update-remnux.sh instead.\033[0m\n' >&2
    exit 1
fi

#################### 
# Vars
####################

# For apt
export DEBIAN_FRONTEND=noninteractive

export VM_USER=user
export LOG=/tmp/sift-update.log
touch $LOG

# Ask for the sudo password once, up front. Not `sudo -v`: see the comment in
# setup-sift.sh — verifypw defaults to `all`, so -v prompts even under
# NOPASSWD:ALL and fails outright when there is no TTY.
if ! sudo -n true 2>/dev/null; then
    sudo true
fi

# shellcheck source=/dev/null
if [[ -e  ~/src/git/dfir-tools/common/bin/utils.sh ]]; then
    .  ~/src/git/dfir-tools/common/bin/utils.sh
else
    printf '\033[0;31mCant find utils.sh.\033[0m\n' >&2
    exit 1
fi

print_status "INFO" "Start update."
print_status "INFO" "Make sure where not in a virtualenv."
deactivate 2> /dev/null || true

remove-old
create-common-directories

print_status "INFO" "Run update-sift script."
update-sift

print_status "INFO" "Update clamav database."
sudo /usr/bin/freshclam || print_status "INFO" "Update of clamav database failed."

update-ubuntu

print_status "INFO" "Update virtualenvwrapper."
# WORKON_HOME comes from utils.sh, which defines it once for the whole
# toolchain. Setting it here would point `workon` at a different location than
# the one the install used.
export VIRTUALENVWRAPPER_HOOK_DIR="${WORKON_HOME}"/hooks
set +u
# shellcheck source=/dev/null
source /usr/share/virtualenvwrapper/virtualenvwrapper.sh
set -u

# Update git repositories
update-git-repositories

# Update python
update-chaosreader
update-floss
update-RecuperaBit
update-volatility
update-regipy
update-autopsy-docker

print_status "INFO" "update-sift.sh done."
