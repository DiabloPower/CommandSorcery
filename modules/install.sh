# modules/install.sh
# 
# Copyright (c) [2025] [Ronny Hamann]
# 
# License Terms:
# 
# 1. Modifications of this script are permitted for personal use.
# 2. Redistribution or reuse of the modified or unmodified script
#    is only allowed with prior written permission from the author.
# 
# Disclaimer of Warranty:
# 
# This script is provided "as is", without warranty of any kind, express or implied,
# including but not limited to the warranties of merchantability, fitness for a particular purpose,
# and noninfringement. In no event shall the author be liable for any claim, damages or other liability,
# whether in an action of contract, tort or otherwise, arising from, out of or in connection with the
# script or the use or other dealings in the script.
#

install_if_missing() {
  if ! command -v "$1" &>/dev/null; then
    echo "📦 Installing missing tool: $1"
    sudo apt update && sudo apt install -y "$1"
  fi
}

check_core_tools() {
  local missing=()
  for tool in "$@"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "❌ Missing tools: ${missing[*]}"
    return 1
  fi
  return 0
}
