#!/bin/bash

set -e
LOG=/tmp/$1.log
touch "$LOG"

# shellcheck source=/dev/null
source ~/utils/bin/utils.sh

if [[ $# == 0 ]]; then
    error-message "Need one argument"
    exit 1
fi

if [[ $1 == "-h" || $1 == "--help" || $1 == "-l" || $1 == "--list" ]]; then
    print_status "INFO" "Available functions:"
    grep "^function " ~/utils/bin/utils.sh |
        grep -v create-common-directories |
        grep -v enable-new-didier |
        grep -v error-message |
        grep -v print_status "INFO" |
        grep -v install-apt-remnux |
        grep -v install-general-tools |
        grep -v install-google-chrome |
        grep -v install-pi-rho-security |
        grep -v install-remnux |
        grep -v install-sift |
        grep -v install-vmware-tools |
        grep -v turn-off-sound |
        grep -v update-sift |
        awk '{print $2}' |
        cut -f1 -d\( |
        sort
    exit 0
fi

print_status "INFO" "Executing function $1."
deactivate 2> /dev/null || true
export PROJECT_HOME="$HOME"/src/python
"$@"
print_status "INFO" "Done."
