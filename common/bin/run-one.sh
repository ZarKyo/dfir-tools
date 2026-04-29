#!/bin/bash

set -e

if [[ $# == 0 ]]; then
    echo "Need one argument" >&2
    exit 1
fi

LOG=/tmp/$1.log
touch "$LOG"
export LOG

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dfir-tools utils.sh (defines install-*/update-* functions)
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/utils.sh"

if [[ $1 == "-h" || $1 == "--help" || $1 == "-l" || $1 == "--list" ]]; then
    print_status "INFO" "Available functions:"
    grep "^function " "${SCRIPT_DIR}/utils.sh" |
        grep -v create-common-directories |
        grep -v create-docker-directories |
        grep -v create-cases-not-mounted |
        grep -v enable-new-didier |
        grep -v print_status |
        grep -v check_root |
        grep -v install-apt-remnux |
        grep -v install-general-tools |
        grep -v install-google-chrome |
        grep -v install-pi-rho-security |
        grep -v install-remnux |
        grep -v install-sift |
        grep -v install-utils |
        grep -v install-docker |
        grep -v install-vmware-tools |
        grep -v turn-off-sound |
        grep -v update-sift |
        grep -v cleanup-sift |
        grep -v cleanup-remnux |
        grep -v remove-old |
        awk '{print $2}' |
        cut -f1 -d\( |
        sort
    exit 0
fi


print_status "INFO" "Executing function $1."
deactivate 2> /dev/null || true
set +u
"$@"
set -u
print_status "INFO" "Done."
