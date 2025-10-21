# modules/ui.sh
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

# Detect best available UI tool or apply override
detect_ui() {
  local override="$1"
  if [[ -n "$override" ]]; then
    UI_TOOL="$override"
  elif [[ -n "$DISPLAY" ]]; then
    for tool in yad zenity dialog; do
      if command -v "$tool" &>/dev/null; then
        UI_TOOL="$tool"
        return
      fi
    done
    UI_TOOL="cli"
  else
    UI_TOOL="cli"
  fi
}

# Check if selected UI tool is available
check_ui_tool() {
  case "$UI_TOOL" in
    yad|zenity|dialog)
      if ! command -v "$UI_TOOL" &>/dev/null; then
        echo "❌ UI tool '$UI_TOOL' is not installed."
        return 1
      fi
      ;;
    cli)
      return 0
      ;;
    *)
      echo "⚠️ Unknown UI tool: '$UI_TOOL'"
      return 1
      ;;
  esac
}

# Inject UI flag into argument array (used in sorcery.sh)
inject_ui_flag() {
  local -n arr=$1
  local flag="--${UI_TOOL#--}"
  if [[ ! " ${arr[*]} " =~ " $flag " ]]; then
    arr=("$flag" "${arr[@]}")
  fi
}

# Script selection UI (used in sorcery.sh)
select_script_ui() {
  local mode="$UI_TOOL"
  shift
  local scripts=("$@")

  case "$mode" in
    yad)
      local list=$(IFS="!"; echo "${scripts[*]}")
      local choice=$(yad --form --title="🧙‍♂️ CommandSorcery Launcher" \
        --width=400 --height=200 --center \
        --field="Choose script":CB "$list")
      echo "${choice%%|*}"
      ;;
    zenity)
      zenity --list --title="🧙‍♂️ CommandSorcery Launcher" \
        --column="Available Scripts" "${scripts[@]}"
      ;;
    dialog)
      local menu=()
      local i=1
      for s in "${scripts[@]}"; do
        menu+=("$i" "$s")
        ((i++))
      done
      local choice=$(dialog --menu "Choose script" 15 50 ${#menu[@]} "${menu[@]}" 3>&1 1>&2 2>&3)
      echo "${scripts[$((choice-1))]}"
      ;;
    cli)
      {
        echo "🧙‍♂️ Available scripts:"
        local i=1
        for s in "${scripts[@]}"; do
          echo "  $i) $s"
          ((i++))
        done
      } >&2
      read -rp "Choose script [name or number]: " choice
      for s in "${scripts[@]}"; do
        if [[ "$choice" == "$s" ]]; then
          echo "$s"
          return 0
        fi
      done
      if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local index=$((choice - 1))
        if (( index >= 0 && index < ${#scripts[@]} )); then
          echo "${scripts[$index]}"
          return 0
        fi
      fi
      echo "❌ Invalid selection: $choice" >&2
      return 1
      ;;
  esac
}
