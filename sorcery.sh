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
  for key in "${!SCRIPTS[@]}"; do
    echo "  $key"
  done
  echo ""
  echo "Interface options:"
  echo "  --yad           – Use YAD graphical interface"
  echo "  --zenity        – Use Zenity graphical interface"
  echo "  --dialog        – Use Dialog (text-based UI)"
  echo "  --cli           – Use pure command-line input"
  echo ""
  echo "Functional options (passed to the selected script):"
  echo "  --batch         – Enable batch mode for video conversion"
  echo "  --no-open       – Do not open the PDF after creation (gutenberg)"
  echo "  --no-toc        – Skip table of contents in PDF (gutenberg)"
  echo "  --install-if-missing=yad|zenity|dialog – Install GUI tool if missing"
  echo ""
  echo "Other options:"
  echo "  --update-self   – Update this launcher script from GitHub"
  echo "  --help          – Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./sorcery.sh gutenberg --yad --no-open"
  echo "  ./sorcery.sh convert --batch --cli"
  echo "  ./sorcery.sh --update-self"
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

REQUIRED_TOOLS=(curl wget bash)
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "📦 Installing missing tool: $tool"
    sudo apt update && sudo apt install -y "$tool"
  fi
done

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
    UI_FLAG="$arg"
  else
    EXTRA_ARGS+=("$arg")
  fi
done

# Inject UI flag into EXTRA_ARGS if not already present
if [[ -n "$UI_FLAG" && ! " ${EXTRA_ARGS[*]} " =~ " $UI_FLAG " ]]; then
  EXTRA_ARGS=("$UI_FLAG" "${EXTRA_ARGS[@]}")
fi

# ─────────────────────────────────────────────
# 🧠 Auto-select UI if none given
# ─────────────────────────────────────────────

if [[ -z "$UI_FLAG" ]]; then
  if command -v yad &>/dev/null; then
    UI_FLAG="--yad"
  elif command -v zenity &>/dev/null; then
    UI_FLAG="--zenity"
  elif command -v dialog &>/dev/null; then
    UI_FLAG="--dialog"
  else
    UI_FLAG="--cli"
  fi
fi

# ─────────────────────────────────────────────
# 🪄 Script selection via UI
# ─────────────────────────────────────────────

if [[ -z "$SCRIPT" ]]; then
  case "$UI_FLAG" in
    --yad)
      SCRIPT_LIST=$(IFS="!"; echo "${!SCRIPTS[*]}")
      CHOICE=$(yad --form \
        --title="🧙‍♂️ CommandSorcery Launcher" \
        --width=400 --height=200 \
        --center \
        --field="Choose script":CB "$SCRIPT_LIST")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      SCRIPT=$(echo "$CHOICE" | cut -d'|' -f1)
      ;;
    --zenity)
      CHOICE=$(zenity --list \
        --title="🧙‍♂️ CommandSorcery Launcher" \
        --column="Available Scripts" "${!SCRIPTS[@]}")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      SCRIPT="$CHOICE"
      ;;
    --dialog)
      MENU_ITEMS=()
      i=1
      for key in "${!SCRIPTS[@]}"; do
        MENU_ITEMS+=("$i" "$key")
        ((i++))
      done
      CHOICE=$(dialog --menu "Choose script" 15 50 ${#MENU_ITEMS[@]} "${MENU_ITEMS[@]}" 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      SCRIPT=$(echo "${!SCRIPTS[@]}" | awk -v n="$CHOICE" '{print $n}')
      ;;
    --cli|--text)
      echo "🧙‍♂️ Available scripts:"
      i=1
      for key in "${!SCRIPTS[@]}"; do
        echo "  $i) $key"
        ((i++))
      done
      read -rp "Choose script [name or number]: " CHOICE
      if [[ -n "${SCRIPTS[$CHOICE]}" ]]; then
        SCRIPT="$CHOICE"
      else
        INDEXED=("${!SCRIPTS[@]}")
        SCRIPT="${INDEXED[$((CHOICE-1))]}"
      fi
      ;;
  esac
fi

# ─────────────────────────────────────────────
# 🚀 Execute selected script remotely
# ─────────────────────────────────────────────

if [[ -n "${SCRIPTS[$SCRIPT]}" ]]; then
  echo "🚀 Running ${SCRIPTS[$SCRIPT]}..."
  bash <(curl -s "$BASE_URL/${SCRIPTS[$SCRIPT]}") "$UI_FLAG" "${EXTRA_ARGS[@]}"
else
  echo "❌ Unknown script: $SCRIPT"
  echo "Use --help to see available options."
  exit 1
fi
