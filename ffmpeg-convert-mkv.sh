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

# Default UI mode
UI="yad"
INSTALL_GUI_TOOL=""
BATCH_MODE=false

# Show help message and usage instructions
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --install-if-missing=UI   Install UI tool (yad/zenity/dialog)"
  echo "  --yad                     Use YAD GUI (default if available)"
  echo "  --zenity                  Use Zenity GUI"
  echo "  --dialog                  Use Dialog (text-based UI)"
  echo "  --cli                     Use pure command-line input"
  echo "  --batch                   Enable batch mode for directory conversion"
  echo "  --help                    Show this help message"
  exit 0
}

# Parse command-line arguments
for arg in "$@"; do
  case "$arg" in
    --install-if-missing=*) INSTALL_GUI_TOOL="${arg#*=}" ;;
    --yad) UI="yad" ;;
    --zenity) UI="zenity" ;;
    --dialog) UI="dialog" ;;
    --cli) UI="cli" ;;
    --batch) BATCH_MODE=true ;;
    --help) show_help ;;
    *) echo "Unknown option: $arg"; show_help ;;
  esac
done

# Install required tool if missing
install_if_missing() {
  if ! command -v "$1" &> /dev/null; then
    echo "$1 not found. Installing..."
    sudo apt update && sudo apt install -y "$1"
  fi
}

# Ensure ffmpeg is installed
install_if_missing ffmpeg

# Optionally install selected GUI tool
case "$INSTALL_GUI_TOOL" in
  yad|zenity|dialog)
    install_if_missing "$INSTALL_GUI_TOOL"
    ;;
  "") ;;
  *) echo "⚠️ Unknown GUI-Tool: $INSTALL_GUI_TOOL" ;;
esac

# Check for NVIDIA NVENC support
if [[ -f "/usr/lib/x86_64-linux-gnu/libnvidia-encode.so.1" ]]; then
  echo "✅ NVIDIA encoding libraries found."
else
  echo "❌ NVIDIA encoding libraries missing. Please install them first."
  exit 1
fi

# Select encoder: NVENC if available, otherwise fallback to CPU
if ffmpeg -encoders | grep -q hevc_nvenc; then
  ENCODER="hevc_nvenc"
else
  echo "⚠️ NVENC not available. Falling back to CPU encoding (libx265)."
  ENCODER="libx265"
fi

# Fallback to CLI if selected UI tool is not available
check_ui() {
  if ! command -v "$1" &> /dev/null; then
    echo "$1 not available. Falling back to CLI."
    UI="cli"
  fi
}
check_ui "$UI"

# Prompt user to select input/output directories for batch mode
get_batch_input() {
  case "$UI" in
    yad)
      DIRS=$(yad --form \
        --title="🎬 Batch Conversion" \
        --width=800 \
        --height=200 \
        --center \
        --field="📁 Input directory":DIR \
        --field="💾 Output directory":DIR \
        "$HOME" "$HOME")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      IFS="|" read -r INPUT_DIR OUTPUT_DIR <<< "$DIRS"
      ;;
    zenity)
      INPUT_DIR=$(zenity --file-selection --directory --title="Select input directory")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_DIR=$(zenity --file-selection --directory --title="Select output directory")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      ;;
    dialog)
      INPUT_DIR=$(dialog --title "Input directory" --dselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_DIR=$(dialog --title "Output directory" --dselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      ;;
    cli)
      read -e -p "📁 Input directory: " INPUT_DIR
      read -e -p "💾 Output directory: " OUTPUT_DIR
      ;;
  esac

  # Create output directory if it doesn't exist
  if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "📂 Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR" || { echo "❌ Failed to create output directory."; exit 1; }
  fi
}

# Perform batch conversion of all supported video files in input directory
run_batch_conversion() {
  echo "📦 Starting batch conversion..."
  shopt -s nullglob
  LOGFILE=$(mktemp)
  SUMMARY_LOG=$(mktemp)
  PIPE=$(mktemp -u)
  mkfifo "$PIPE"

  SUCCESS_COUNT=0
  FAIL_COUNT=0
  SKIPPED_COUNT=0

  # Backup original stdout/stderr
  exec {STDOUT_BACKUP}>&1
  exec {STDERR_BACKUP}>&2

  # Start YAD live log window
  if [[ "$UI" == "yad" ]]; then
    yad --text-info \
      --title="🎬 Batch Converting..." \
      --width=800 \
      --height=400 \
      --center \
      --wrap \
      --tail \
      --no-buttons < "$PIPE" &
    YAD_PID=$!
  fi

  # Redirect stdout/stderr to logfile and pipe
  exec > >(tee -a "$LOGFILE" > "$PIPE")
  exec 2>&1

  # Conversion loop
  for INPUT_FILE in "$INPUT_DIR"/*.{mp4,mkv,avi,mov,flv,webm,mpeg,mpg,m4v,ts,wmv,ogg}; do
    [ -f "$INPUT_FILE" ] || continue
    BASENAME=$(basename "$INPUT_FILE")
    OUTPUT_FILE="${OUTPUT_DIR}/${BASENAME%.*}.mkv"

    if [[ "$(realpath "$INPUT_FILE")" == "$(realpath "$OUTPUT_FILE")" ]]; then
      echo "⚠️ Skipping $BASENAME — input and output paths are identical." | tee -a "$SUMMARY_LOG"
      ((SKIPPED_COUNT++))
      continue
    fi

    echo "🎬 Converting: $BASENAME → $(basename "$OUTPUT_FILE")"
    if ffmpeg -y -i "$INPUT_FILE" -c:v "$ENCODER" -preset medium \
      -b:v "${BITRATE}M" -qp "$QUALITY" -map 0:v -map 0:a \
      -c:a aac -b:a 192k "$OUTPUT_FILE"; then
      echo "✅ Success: $BASENAME" | tee -a "$SUMMARY_LOG"
      ((SUCCESS_COUNT++))
    else
      echo "❌ Failed: $BASENAME" | tee -a "$SUMMARY_LOG"
      ((FAIL_COUNT++))
    fi
  done

  echo "✅ Batch conversion complete!"

  # Restore original stdout/stderr
  exec 1>&${STDOUT_BACKUP}
  exec 2>&${STDERR_BACKUP}

  # Clean up GUI
  if [[ "$UI" == "yad" ]]; then
    sleep 1
    kill "$YAD_PID"
    rm "$PIPE"
    yad --info \
      --title="✅ Batch Complete" \
      --text="All files have been successfully converted!" \
      --button="OK:0" \
      --width=400 \
      --height=100
  else
    cat "$LOGFILE"
    rm "$LOGFILE"
  fi

  # Final summary
  echo -e "\n📊 Summary:"
  echo "  ✔️ Successful: $SUCCESS_COUNT"
  echo "  ❌ Failed:     $FAIL_COUNT"
  echo "  ⚠️ Skipped:    $SKIPPED_COUNT"
  echo -e "\n📝 Detailed summary:"
  cat "$SUMMARY_LOG"
  rm "$SUMMARY_LOG"
}

# Prompt user for input/output files and encoding parameters
get_user_input() {
  case "$UI" in
    yad)
      if ! $BATCH_MODE; then
        INPUT_FILE=$(yad --file --title="🎬 Select input file" --width=900 --height=600)
        [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
        OUTPUT_FILE=$(yad --file --save --title="💾 Choose output file" --width=900 --height=600)
        [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      fi
      BITRATE="2"
      QUALITY="22"
      FORM_OUTPUT=$(yad --form \
        --title="🎥 MKV Converter" \
        --width=900 \
        --height=200 \
        --center \
        --window-icon="video-x-generic" \
        --field="📶 Bitrate (Mbit/s)":NUM \
        --field="🎚️ Quality (CRF or QP)":NUM \
        "$BITRATE" "$QUALITY")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      IFS="|" read -r BITRATE QUALITY <<< "$FORM_OUTPUT"
      ;;
    zenity)
      if ! $BATCH_MODE; then
        INPUT_FILE=$(zenity --file-selection --title="Select input file")
        [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
        OUTPUT_FILE=$(zenity --file-selection --save --title="Choose output file")
        [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      fi
      BITRATE=$(zenity --entry --title="Bitrate" --text="Enter bitrate in Mbit/s (e.g. 2):" --entry-text="2")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      QUALITY=$(zenity --entry --title="Quality" --text="Enter CRF or QP value (e.g. 22):" --entry-text="22")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      ;;
    dialog)
      # Use dialog to select input/output files and enter encoding parameters
      if ! $BATCH_MODE; then
        INPUT_FILE=$(dialog --title "Input file" --fselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
        OUTPUT_FILE=$(dialog --title "Output file" --fselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      fi
      BITRATE=$(dialog --inputbox "Enter bitrate in Mbit/s (e.g. 2):" 10 50 "2" 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      QUALITY=$(dialog --inputbox "Enter CRF or QP value (e.g. 22):" 10 50 "22" 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      ;;
    cli)
      # Use CLI to enter input/output paths and encoding parameters
      if ! $BATCH_MODE; then
        read -e -p "🎬 Input file path: " INPUT_FILE
        read -e -p "💾 Output file path: " OUTPUT_FILE
      fi
      read -rp "📶 Bitrate in Mbit/s (e.g. 2): " BITRATE
      read -rp "🎚️ Quality (CRF or QP, e.g. 22): " QUALITY
      ;;
  esac
}

# If batch mode is enabled, run batch input and conversion, then exit
if $BATCH_MODE; then
  get_user_input         # Ask for bitrate and quality
  get_batch_input        # Ask for input/output directories
  run_batch_conversion   # Process all files in batch
  exit 0
fi

# Otherwise, proceed with single file conversion
get_user_input

# Default overwrite flag for ffmpeg
OVERWRITE_FLAG="-y"

# Validate input and output file paths
if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
  echo "❌ No file selected. Aborting."
  exit 1
fi

# Prevent overwriting input file
if [[ "$(realpath "$INPUT_FILE")" == "$(realpath "$OUTPUT_FILE")" ]]; then
  echo "❌ Input and output file are the same. Aborting to prevent overwrite."
  exit 1
fi

# Build ffmpeg command as array for safe execution
convert_command=(
  ffmpeg $OVERWRITE_FLAG -i "$INPUT_FILE" -c:v "$ENCODER" -preset medium \
  -b:v "${BITRATE}M" -qp "$QUALITY" -map 0:v -map 0:a \
  -c:a aac -b:a 192k "$OUTPUT_FILE"
)

# Execute conversion and show progress/output depending on UI
case "$UI" in
  yad)
    # Show live log in YAD window
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
      --text="Your file has been successfully converted:\n\n$OUTPUT_FILE" \
      --button="OK:0" \
      --width=400 \
      --height=100
    ;;
  zenity)
    # Show progress bar in Zenity
    "${convert_command[@]}" | tee >(zenity --progress \
      --title="Converting..." --pulsate --auto-close)
    ;;
  dialog | cli)
    # Output directly to terminal
    "${convert_command[@]}"
    ;;
esac

# Final confirmation
echo "✅ Conversion complete!"
