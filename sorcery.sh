#!/bin/bash
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
# 🧙‍♂️ CommandSorcery Launcher

BASE_URL="https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main"
SELF_PATH="$0"
SELF_NAME=$(basename "$0")
declare -A SCRIPTS
declare -A SCRIPT_OPTIONS
declare -A SCRIPT_OPTIONS_DESC

# Load modules
fetch_remote() {
  local url="$1"
  if command -v curl &>/dev/null; then
    curl -fsSL "$url"
  elif command -v wget &>/dev/null; then
    wget -qO- "$url"
  else
    echo "❌ Neither curl nor wget is available."
    return 1
  fi
}

load_module() {
  local name="$1"
  local base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local local_path="$base_dir/modules/$name.sh"
  local remote_url="$BASE_URL/modules/$name.sh"

  if [[ -f "$local_path" ]]; then
    source "$local_path"
    echo "📦 Loaded local module: $name"
  else
    echo "🌐 Local module '$name' not found, trying online..."
    if fetch_remote "$remote_url" | source /dev/stdin; then
      echo "✅ Loaded remote module: $name"
    else
      echo "❌ Failed to load module '$name' from $remote_url"
      exit 1
    fi
  fi
}

load_module ui
load_module install
load_module registry

splash_sorcerer

# ─────────────────────────────────────────────
# 🧾 Help
# ─────────────────────────────────────────────

if [[ "$1" == "--help" ]]; then
  echo ""
  echo "🧙‍♂️ CommandSorcery Launcher – Help"
  echo "----------------------------------------"
  echo "Usage: ./sorcery.sh [SCRIPT] [OPTIONS]"
  echo ""
  echo "Available scripts:"
  for key in "${!SCRIPTS[@]}"; do echo "  $key"; done
  echo ""
  echo "Interface options:"
  echo "  --yad | --zenity | --dialog | --cli"
  echo ""
  echo "Other options:"
  echo "  --update-self   – Update this launcher script from GitHub"
  echo "  --help          – Show this help message"
  echo ""
  exit 0
fi

# ─────────────────────────────────────────────
# 🔄 Self-update
# ─────────────────────────────────────────────

if [[ "$1" == "--update-self" ]]; then
  echo "🔄 Checking for update..."
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/sorcery.sh")

  if [[ "$STATUS" == "200" ]]; then
    echo "📦 Creating backup: ${SELF_PATH}.bak"
    cp "$SELF_PATH" "${SELF_PATH}.bak"
    echo "⬇️ Downloading latest version..."
    curl -s "$BASE_URL/sorcery.sh" -o "$SELF_PATH" && chmod +x "$SELF_PATH"
    echo "✅ Updated successfully."
  else
    echo "❌ Update failed: GitHub returned HTTP $STATUS"
    echo "🛑 Your current version remains untouched."
  fi
  exit 0
fi

# ─────────────────────────────────────────────
# 🧰 Check dependencies
# ─────────────────────────────────────────────

check_core_tools curl wget bash || exit 1

# ─────────────────────────────────────────────
# 🧭 Parse arguments
# ─────────────────────────────────────────────

SCRIPT=""
UI_FLAG=""
EXTRA_ARGS=()

for arg in "$@"; do
  if [[ -n "${SCRIPTS[$arg]}" ]]; then
    SCRIPT="$arg"
  elif [[ "$arg" =~ ^--(yad|zenity|dialog|cli|text)$ ]]; then
    UI_FLAG="${arg#--}"
  else
    EXTRA_ARGS+=("$arg")
  fi
done

# ─────────────────────────────────────────────
# 🧠 UI detection
# ─────────────────────────────────────────────

detect_ui "$UI_FLAG"
inject_ui_flag EXTRA_ARGS

# ─────────────────────────────────────────────
# 🪄 Script selection via UI
# ─────────────────────────────────────────────

if [[ -z "$SCRIPT" ]]; then
  SCRIPT_KEYS=("${!SCRIPTS[@]}")
  SCRIPT=$(select_script_ui "$UI_FLAG" "${SCRIPT_KEYS[@]}")
  mapfile -t OPTIONAL_FLAGS < <(select_script_options_ui "$SCRIPT")
  [[ ${#OPTIONAL_FLAGS[@]} -gt 0 ]] && EXTRA_ARGS+=("${OPTIONAL_FLAGS[@]}")
  [[ -z "$SCRIPT" ]] && echo "🚫 Cancelled." && exit 1
fi

# ─────────────────────────────────────────────
# 🚀 Execute selected script remotely
# ─────────────────────────────────────────────

if [[ -n "${SCRIPTS[$SCRIPT]}" ]]; then
  echo "🚀 Running ${SCRIPTS[$SCRIPT]}..."
  bash <(curl -s "$BASE_URL/${SCRIPTS[$SCRIPT]}") "$UI_FLAG" "${EXTRA_ARGS[@]}"
else
  echo "❌ Unknown script: $SCRIPT"
  exit 1
fi
