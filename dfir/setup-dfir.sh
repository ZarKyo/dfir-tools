#!/bin/bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# For apt
export DEBIAN_FRONTEND=noninteractive
export LOG=/tmp/dfir.log
touch "$LOG"

# shellcheck source=/dev/null
if [[ -e  ~/src/bin/dfir-tools/common/bin/utils.sh ]]; then
    .  ~/src/bin/dfir-tools/common/bin/utils.sh
else
    echo "Cant find utils.sh."
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
    wget --quiet https://REMnux.org/remnux-cli -O /tmp/remnux-cli
    chmod +x /tmp/remnux-cli
    sudo mv /tmp/remnux-cli /usr/local/bin/remnux
    sudo apt install -y gnupg
fi

sudo systemctl stop ssh.service
# shellcheck disable=SC2024
sudo /usr/local/bin/remnux install --mode=addon 2>&1 | tee -a "$LOG"
sudo systemctl start ssh.service
touch ~/.config/.remnux

install-apt-remnux
cleanup-remnux

# REMnux aliases (SIFT aliases already deployed by setup-sift.sh)
cp ~/dfir-tools/remnux/.remnux_aliases ~/.remnux_aliases

print_status "INFO" "DFIR installation finished."
