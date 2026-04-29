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

# Force sudo password prompt early
sudo -v

# shellcheck source=/dev/null
if [[ -e  ~/src/bin/dfir-tools/common/bin/utils.sh ]]; then
    .  ~/src/bin/dfir-tools/common/bin/utils.sh
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
# Use virtualenvwrapper for python tools
export WORKON_HOME=$HOME/src/python
export VIRTUALENVWRAPPER_HOOK_DIR=$HOME/src/python/hooks
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
