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

# Load modules
load_module() {
  local name="$1"
  local local_path="$(dirname "$SELF_PATH")/modules/$name.sh"
  local remote_url="$BASE_URL/modules/$name.sh"

  if [[ "$SELF_PATH" == /dev/fd/* ]]; then
    # Remote mode
    if ! source <(curl -fsSL "$remote_url"); then
      echo "❌ Failed to load module '$name' from $remote_url"
      exit 1
    fi
  else
    # Local mode
    if [[ -f "$local_path" ]]; then
      source "$local_path"
    else
      echo "❌ Local module '$name' not found at $local_path"
      exit 1
    fi
  fi
}
load_module ui
load_module install

declare -A SCRIPTS=(
  [gutenberg]="gutenberg.sh"
  [convert]="ffmpeg-convert-mkv.sh"
)

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
