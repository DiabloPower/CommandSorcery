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
# ┌────────────────────────────────────────────────────────────┐
# │ 🎥 FFmpeg Conversion Script with GUI and CLI Support       │
# │ Supports YAD, Zenity, Dialog, CLI, and Batch Mode          │
# └────────────────────────────────────────────────────────────┘

BASE_URL="https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main"
SELF_PATH="$0"

# Load modules
load_module() {
  local name="$1"
  local local_path="$(dirname "$SELF_PATH")/modules/$name.sh"
  local remote_url="$BASE_URL/modules/$name.sh"

  if [[ "$SELF_PATH" == /dev/fd/* ]]; then
    source <(curl -fsSL "$remote_url") || { echo "❌ Failed to load module '$name'"; exit 1; }
  else
    source "$local_path" || { echo "❌ Local module '$name' not found"; exit 1; }
  fi
}

load_module ui
load_module install
load_module input

# ─────────────────────────────────────────────
# 🧾 Help
# ─────────────────────────────────────────────

if [[ "$1" == "--help" ]]; then
  echo "🎥 FFmpeg Converter – Help"
  echo ""
  echo "Usage: ./convert.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --yad | --zenity | --dialog | --cli"
  echo "  --batch               – Enable batch mode"
  echo "  --install-if-missing=UI"
  echo "  --help                – Show this help"
  exit 0
fi

# ─────────────────────────────────────────────
# 🧭 parse arguments
# ─────────────────────────────────────────────

UI_OVERRIDE=""
INSTALL_GUI_TOOL=""
BATCH_MODE=false

for arg in "$@"; do
  case "$arg" in
    --install-if-missing=*) INSTALL_GUI_TOOL="${arg#*=}" ;;
    --yad|--zenity|--dialog|--cli) UI_OVERRIDE="${arg#--}" ;;
    --batch) BATCH_MODE=true ;;
  esac
done

# ─────────────────────────────────────────────
# 🧠 Setup
# ─────────────────────────────────────────────

detect_ui "$UI_OVERRIDE"
check_ui_tool || exit 1
install_if_missing ffmpeg
[[ -n "$INSTALL_GUI_TOOL" ]] && install_if_missing "$INSTALL_GUI_TOOL"

# Check for NVENC
if [[ -f "/usr/lib/x86_64-linux-gnu/libnvidia-encode.so.1" ]]; then
  echo "✅ NVIDIA encoding libraries found."
else
  echo "❌ NVIDIA encoding libraries missing. Please install them first."
  exit 1
fi

ENCODER=$(ffmpeg -hide_banner -encoders 2>/dev/null | grep -q hevc_nvenc && echo "hevc_nvenc" || echo "libx265")

# ─────────────────────────────────────────────
# 📥 get input
# ─────────────────────────────────────────────

if $BATCH_MODE; then
  get_ffmpeg_input "$UI_TOOL" || exit 1
  get_ffmpeg_batch_input "$UI_TOOL" || exit 1
  run_ffmpeg_batch "$ENCODER" "$BITRATE" "$QUALITY" "$INPUT_DIR" "$OUTPUT_DIR" "$UI_TOOL"
  exit 0
else
  get_ffmpeg_input "$UI_TOOL" || exit 1
  get_ffmpeg_single_input "$UI_TOOL" || exit 1
fi

# ─────────────────────────────────────────────
# 🚀 single convertion
# ─────────────────────────────────────────────

if [[ "$(realpath "$INPUT_FILE")" == "$(realpath "$OUTPUT_FILE")" ]]; then
  echo "❌ Input and output file are the same. Aborting."
  exit 1
fi

ffmpeg -y -i "$INPUT_FILE" -c:v "$ENCODER" -preset medium \
  -b:v "${BITRATE}M" -qp "$QUALITY" -map 0:v -map 0:a \
  -c:a aac -b:a 192k "$OUTPUT_FILE"

echo "✅ Conversion complete: $OUTPUT_FILE"
