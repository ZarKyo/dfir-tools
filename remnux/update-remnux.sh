#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
# -e : exit immediately on error
# -u : treat unset variables as errors
# -o pipefail : fail if any command in a pipeline fails
# IFS : safer word splitting
set -euo pipefail
IFS=$'\n\t'

if [[ -e ~/.config/.sift ]]; then
    echo "You have already installed SIFT ! Use update-sift.sh insteed."
    exit 1
fi

#################### 
# Vars
####################

# For apt
export DEBIAN_FRONTEND=noninteractive

export VM_USER=user
export LOG=/tmp/remnux.log
touch $LOG

# Force sudo password prompt early
sudo -v

# shellcheck source=/dev/null
if [[ -e  ~/src/bin/dfir-tools/common/bin/utils.sh ]]; then
    .  ~/src/bin/dfir-tools/common/bin/utils.sh
else
    echo "Cant find utils.sh."
    exit 1
fi

print_status "INFO" "Start update."
print_status "INFO" "Make sure where not in a virtualenv."
deactivate 2> /dev/null || true

remove-old

print_status "INFO" "Update clamav database."
sudo /usr/bin/freshclam || true

print_status "INFO" "Run upgrade and update for REMnux."
sudo remnux upgrade && sudo remnux update

update-ubuntu

print_status "INFO" "Update virtualenvwrapper."
# Use virtualenvwrapper for python tools
export WORKON_HOME=$HOME/src/python
export VIRTUALENVWRAPPER_HOOK_DIR=$HOME/src/python/hooks
# Prevent virtualenvwrapper from failing under 'set -u'
export ZSH_VERSION=""
# shellcheck source=/dev/null
source /usr/share/virtualenvwrapper/virtualenvwrapper.sh

# Update git repositories
update-git-repositories

install-chaosreader
install-pcodedmp

print_status "INFO" "update-remnux.sh done."
