# modules/input.sh
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

get_gutenberg_input() {
  local mode="$1"
  case "$mode" in
    yad)
      FORM=$(yad --form --title="Gutenberg Downloader" \
        --field="📘 Buch-URL": \
        --field="📄 PDF-Dateiname (ohne .pdf)": \
        --field="📁 Zielordner":DIR \
        "" "" "$HOME")
      IFS="|" read -r URL OUTPUT TARGET_DIR <<< "$FORM"
      ;;
    zenity)
      URL=$(zenity --entry --text="Buch-URL eingeben:")
      OUTPUT=$(zenity --entry --text="PDF-Dateiname:")
      TARGET_DIR=$(zenity --file-selection --directory)
      ;;
    dialog)
      URL=$(dialog --inputbox "Buch-URL:" 10 60 3>&1 1>&2 2>&3)
      OUTPUT=$(dialog --inputbox "PDF-Dateiname:" 10 60 3>&1 1>&2 2>&3)
      TARGET_DIR=$(dialog --dselect "$HOME/" 10 60 3>&1 1>&2 2>&3)
      ;;
    none)
      read -p "📘 Buch-URL: " URL
      read -p "📄 PDF-Dateiname: " OUTPUT
      read -p "📁 Zielordner: " TARGET_DIR
      ;;
  esac

  [[ -z "$URL" || -z "$OUTPUT" || -z "$TARGET_DIR" ]] && return 1
  export URL OUTPUT TARGET_DIR
}

get_ffmpeg_input() {
  local mode="$1"
  BITRATE="2"
  QUALITY="22"
  case "$mode" in
    yad)
      FORM=$(yad --form --title="🎥 MKV Converter" \
        --width=900 --height=200 --center \
        --field="📶 Bitrate (Mbit/s)":NUM \
        --field="🎚️ Quality (CRF or QP)":NUM \
        "$BITRATE" "$QUALITY")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      IFS="|" read -r BITRATE QUALITY <<< "$FORM"
      ;;
    zenity)
      BITRATE=$(zenity --entry --text="Bitrate (e.g. 2):" --entry-text="$BITRATE")
      QUALITY=$(zenity --entry --text="Quality (e.g. 22):" --entry-text="$QUALITY")
      ;;
    dialog)
      BITRATE=$(dialog --inputbox "Bitrate (e.g. 2):" 10 50 "$BITRATE" 3>&1 1>&2 2>&3)
      QUALITY=$(dialog --inputbox "Quality (e.g. 22):" 10 50 "$QUALITY" 3>&1 1>&2 2>&3)
      ;;
    cli)
      read -rp "📶 Bitrate in Mbit/s (e.g. 2): " BITRATE
      read -rp "🎚️ Quality (CRF or QP, e.g. 22): " QUALITY
      ;;
  esac

  export BITRATE QUALITY
}

get_ffmpeg_single_input() {
  local mode="$1"
  case "$mode" in
    yad)
      INPUT_FILE=$(yad --file --title="🎬 Select input file" --width=900 --height=600)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_FILE=$(yad --file --save --title="💾 Choose output file" --width=900 --height=600)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      ;;
    zenity)
      INPUT_FILE=$(zenity --file-selection --title="Select input file")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_FILE=$(zenity --file-selection --save --title="Choose output file")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      ;;
    dialog)
      INPUT_FILE=$(dialog --title "Input file" --fselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      OUTPUT_FILE=$(dialog --title "Output file" --fselect "$HOME/" 15 80 3>&1 1>&2 2>&3)
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      ;;
    cli)
      read -e -p "🎬 Input file path: " INPUT_FILE
      read -e -p "💾 Output file path: " OUTPUT_FILE
      ;;
  esac

  # Validate
  if [[ -z "$INPUT_FILE" || -z "$OUTPUT_FILE" ]]; then
    echo "❌ No input/output file selected."
    exit 1
  fi

  export INPUT_FILE OUTPUT_FILE
}

get_ffmpeg_batch_input() {
  local mode="$1"
  case "$mode" in
    yad|zenity|dialog|cli)
      # GUI-Formular je nach Tool
      # Ergebnis: INPUT_DIR, OUTPUT_DIR
      ;;
  esac
  export INPUT_DIR OUTPUT_DIR
}

run_ffmpeg_batch() {
  local encoder="$1"
  local bitrate="$2"
  local quality="$3"
  local input="$4"
  local output="$5"
  local mode="$6"

  # Batch-Konvertierung wie bisher
}
