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
# │ 🎥 FFmpeg MKV Conversion Script with GUI and CLI Support   │
# │ Supports YAD, Zenity, Dialog, and pure CLI                 │
# └────────────────────────────────────────────────────────────┘

UI="yad"

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --install-if-missing=UI	Use to install UI-Tools (YAD/Zenity/Dialog)"
  echo "  --yad			        Use YAD GUI (default if available)"
  echo "  --zenity    			Use Zenity GUI"
  echo "  --dialog    			Use Dialog (text-based UI)"
  echo "  --cli       			Use pure command-line input"
  echo "  --help      			Show this help message"
  exit 0
}

INSTALL_GUI_TOOL=""
for arg in "$@"; do
  case "$arg" in
    --install-if-missing=*) INSTALL_GUI_TOOL="${arg#*=}" ;;
    --yad) UI="yad" ;;
    --zenity) UI="zenity" ;;
    --dialog) UI="dialog" ;;
    --cli) UI="cli" ;;
    --help) show_help ;;
    *) echo "Unknown option: $arg"; show_help ;;
  esac
done

install_if_missing() {
  if ! command -v "$1" &> /dev/null; then
    echo "$1 not found. Installing..."
    sudo apt update && sudo apt install -y "$1"
  fi
}

install_if_missing ffmpeg  # hard dependency

case "$INSTALL_GUI_TOOL" in
  yad|zenity|dialog)
    if ! command -v "$INSTALL_GUI_TOOL" &>/dev/null; then
      echo "📦 Installiere GUI-Tool: $INSTALL_GUI_TOOL"
      sudo apt update && sudo apt install -y "$INSTALL_GUI_TOOL"
    else
      echo "✅ GUI-Tool '$INSTALL_GUI_TOOL' already installed."
    fi
    ;;
  "")
    # do nothing
    ;;
  *)
    echo "⚠️ Unknown GUI-Tool: $INSTALL_GUI_TOOL"
    ;;
esac

if [[ -f "/usr/lib/x86_64-linux-gnu/libnvidia-encode.so.1" ]]; then
  echo "✅ NVIDIA encoding libraries found."
else
  echo "❌ NVIDIA encoding libraries missing. Please install them first."
  exit 1
fi

if ffmpeg -encoders | grep -q hevc_nvenc; then
  ENCODER="hevc_nvenc"
else
  echo "⚠️ NVENC not available. Falling back to CPU encoding (libx265)."
  ENCODER="libx265"
fi

check_ui() {
  if ! command -v "$1" &> /dev/null; then
    echo "$1 not available. Falling back to CLI."
    UI="cli"
  fi
}
check_ui "$UI"

get_user_input() {
  case "$UI" in
    yad)
      INPUT_FILE=$(yad --file --title="🎬 Select input MKV file" --width=900 --height=600)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_FILE=$(yad --file --save --title="💾 Choose output MKV file" --width=900 --height=600)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      BITRATE="2"
      QUALITY="26"
      FORM_OUTPUT=$(yad --form \
        --title="🎥 MKV Converter" \
        --width=900 \
        --height=200 \
        --center \
        --window-icon="video-x-generic" \
        --field="🎬 Input file":TXT \
        --field="💾 Output file (.mkv)":TXT \
        --field="📶 Bitrate (Mbit/s)":NUM \
        --field="🎚️ Quality (CRF or QP)":NUM \
        "$INPUT_FILE" "$OUTPUT_FILE" "$BITRATE" "$QUALITY")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      IFS="|" read -r INPUT_FILE OUTPUT_FILE BITRATE QUALITY <<< "$FORM_OUTPUT"

      OVERWRITE_FLAG=""
      if [[ -f "$OUTPUT_FILE" ]]; then
        yad --question \
          --title="⚠️ File exists" \
          --text="The output file already exists:\n\n$OUTPUT_FILE\n\nDo you want to overwrite it?" \
          --button="Overwrite:0" \
          --button="Cancel:1"
        if [ $? -eq 0 ]; then
          OVERWRITE_FLAG="-y"
        else
          echo "🚫 Cancelled by user." && exit 1
        fi
      fi
      ;;
    zenity)
      INPUT_FILE=$(zenity --file-selection --title="Select input MKV file")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_FILE=$(zenity --file-selection --save --title="Choose output file")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      BITRATE=$(zenity --entry --title="Bitrate" --text="Enter bitrate in Mbit/s (e.g. 2):" --entry-text="2")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      QUALITY=$(zenity --entry --title="Quality" --text="Enter CRF or QP value (e.g. 26):" --entry-text="26")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OVERWRITE_FLAG="-y"
      ;;
    dialog)
      INPUT_FILE=$(dialog --title "Input file" --fselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_FILE=$(dialog --title "Output file" --fselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      BITRATE=$(dialog --inputbox "Enter bitrate in Mbit/s (e.g. 2):" 10 50 "2" 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      QUALITY=$(dialog --inputbox "Enter CRF or QP value (e.g. 26):" 10 50 "26" 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OVERWRITE_FLAG="-y"
      ;;
    cli)
      echo "📥 Please enter conversion parameters:"
      read -rp "🎬 Input file path: " INPUT_FILE
      read -rp "💾 Output file path: " OUTPUT_FILE
      read -rp "📶 Bitrate in Mbit/s (e.g. 2): " BITRATE
      read -rp "🎚️ Quality (CRF or QP, e.g. 26): " QUALITY
      OVERWRITE_FLAG="-y"
      ;;
  esac
}

get_user_input

if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
  echo "❌ No file selected. Aborting."
  exit 1
fi

convert_command=(
  ffmpeg $OVERWRITE_FLAG -i "$INPUT_FILE" -c:v "$ENCODER" -preset medium \
  -b:v "${BITRATE}M" -qp "$QUALITY" -map 0:v -map 0:a \
  -c:a aac -b:a 192k "$OUTPUT_FILE"
)

case "$UI" in
  yad)
    LOGFILE=$(mktemp)
    "${convert_command[@]}" &> "$LOGFILE" &
    FFMPEG_PID=$!
    tail -f "$LOGFILE" | yad --text-info \
      --title="🎬 Converting..." \
      --width=800 \
      --height=400 \
      --center \
      --wrap \
      --tail \
      --no-buttons &
    TAIL_PID=$!
    wait "$FFMPEG_PID"
    kill "$TAIL_PID"
    rm "$LOGFILE"
    yad --info \
      --title="✅ Conversion Complete" \
      --text="Your MKV file has been successfully converted!" \
      --button="OK:0" \
      --width=400 \
      --height=100
    ;;
  zenity)
    "${convert_command[@]}" | tee >(zenity --progress \
      --title="Converting..." --pulsate --auto-close)
    ;;
  dialog | cli)
    "${convert_command[@]}"
    ;;
esac

echo "✅ Conversion complete!"

