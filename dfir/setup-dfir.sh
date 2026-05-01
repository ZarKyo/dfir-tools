#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# For apt
export DEBIAN_FRONTEND=noninteractive
export LOG=/tmp/dfir.log
touch "$LOG"

# Make a fake sudo to get password before output
sudo -v

# shellcheck source=/dev/null
if [[ -e  ~/src/git/dfir-tools/common/bin/utils.sh ]]; then
    .  ~/src/git/dfir-tools/common/bin/utils.sh
else
    printf '\033[0;31mCant find utils.sh.\033[0m\n' >&2
    exit 1
fi

print_status "INFO" "Starting DFIR installation (SIFT base + REMnux addon)."

# Step 1: SIFT base installation.
# DFIR_MODE=1 bypasses the mutual-exclusivity check in setup-sift.sh.
export DFIR_MODE=1

bash "$SCRIPT_DIR/../sift/setup-sift.sh"

# Step 2: Add REMnux as an addon on top of SIFT.
print_status "INFO" "Adding REMnux as addon on top of SIFT."

if [[ ! -e /usr/local/bin/remnux ]]; then
    wget --quiet https://REMnux.org/remnux -O /tmp/remnux
    chmod +x /tmp/remnux
    sudo mv /tmp/remnux /usr/local/bin/remnux
    sudo apt install -y gnupg
fi

sudo systemctl stop ssh.service
sudo /usr/local/bin/remnux install --version=v2026.6.24 --mode=addon 2>&1 | tee -a "$LOG"
sudo systemctl start ssh.service
touch ~/.config/.remnux

install-apt-remnux
cleanup-remnux

# REMnux aliases (SIFT aliases already deployed by setup-sift.sh)
cp "${SCRIPT_DIR}/../remnux/.remnux_aliases" ~/.remnux_aliases

print_status "INFO" "DFIR installation finished."
