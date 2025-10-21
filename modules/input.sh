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
      if [ $? -ne 0 ]; then echo "🚫 Cancelled." && exit 1; fi
      OUTPUT=$(zenity --entry --text="PDF-Dateiname:")
      if [ $? -ne 0 ]; then echo "🚫 Cancelled." && exit 1; fi
      TARGET_DIR=$(zenity --file-selection --directory)
      if [ $? -ne 0 ]; then echo "🚫 Cancelled." && exit 1; fi
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
      if [ $? -ne 0 ]; then echo "🚫 Cancelled." && exit 1; fi
      QUALITY=$(zenity --entry --text="Quality (e.g. 22):" --entry-text="$QUALITY")
      if [ $? -ne 0 ]; then echo "🚫 Cancelled." && exit 1; fi
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
      if [ $? -ne 0 ]; then echo "🚫 Cancelled." && exit 1; fi
      OUTPUT_FILE=$(zenity --file-selection --save --title="Choose output file")
      if [ $? -ne 0 ]; then echo "🚫 Cancelled." && exit 1; fi
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
    yad)
      FORM=$(yad --form --title="🎬 Batch Conversion" \
        --width=800 --height=200 --center \
        --field="📁 Input directory":DIR \
        --field="💾 Output directory":DIR \
        "$HOME" "$HOME")
      [ $? -ne 0 ] && echo "🚫 Cancelled." && exit 1
      IFS="|" read -r INPUT_DIR OUTPUT_DIR <<< "$FORM"
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

  if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "❌ No input/output directory selected."
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR" || { echo "❌ Failed to create output directory."; exit 1; }

  export INPUT_DIR OUTPUT_DIR
}

run_ffmpeg_batch() {
  local encoder="$1"
  local bitrate="$2"
  local quality="$3"
  local input="$4"
  local output="$5"
  local mode="$6"

  echo "📦 Starting batch conversion..."
  shopt -s nullglob
  local formats=(mp4 mkv avi mov flv webm mpeg mpg m4v ts wmv ogg)
  local files=()
  for ext in "${formats[@]}"; do
    files+=("$input"/*."$ext")
  done

  local total=${#files[@]}
  local count=0
  local success=0 fail=0 skipped=0
  local summary=$(mktemp)

  exec {STDOUT_BACKUP}>&1
  exec {STDERR_BACKUP}>&2

  case "$mode" in
    yad)
      local pipe=$(mktemp -u)
      mkfifo "$pipe"
      yad --text-info \
        --title="🎬 Batch Converting..." \
        --width=800 --height=400 \
        --center --wrap --tail --no-buttons < "$pipe" &
      YAD_PID=$!
      exec > >(tee -a "$pipe")
      exec 2>&1
      ;;
    zenity)
      ZENITY_FIFO=$(mktemp -u)
      mkfifo "$ZENITY_FIFO"
      zenity --progress \
        --title="Batch Converting..." \
        --text="Starting conversion..." \
        --auto-close --no-cancel < "$ZENITY_FIFO" &
      ZENITY_PID=$!
      ;;
    dialog)
      LOG=$(mktemp)
      dialog --tailbox "$LOG" 20 80 &
      DIALOG_PID=$!
      ;;
    cli)
      # Kein exec, direkte Ausgabe
      ;;
  esac

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local base=$(basename "$f")
    local out="${output}/${base%.*}.mkv"
    ((count++))

    if [[ "$(realpath "$f")" == "$(realpath "$out")" ]]; then
      echo "⚠️ Skipping $base — input and output are identical." | tee -a "$summary"
      ((skipped++))
      continue
    fi

    case "$mode" in
      yad)
        echo "🎬 Converting: $base → $(basename "$out")"
        ;;
      zenity)
        local percent=$((count * 100 / total))
        echo "$percent" > "$ZENITY_FIFO"
        echo "# Converting: $base" > "$ZENITY_FIFO"
        ;;
      dialog)
        echo "🎬 Converting: $base → $(basename "$out")" >> "$LOG"
        ;;
      cli)
        echo "🎬 Converting: $base → $(basename "$out")"
        ;;
    esac

    if ffmpeg -y -i "$f" -c:v "$encoder" -preset medium \
      -b:v "${bitrate}M" -qp "$quality" -map 0:v -map 0:a \
      -c:a aac -b:a 192k "$out"; then
      echo "✅ Success: $base" | tee -a "$summary"
      ((success++))
    else
      echo "❌ Failed: $base" | tee -a "$summary"
      ((fail++))
    fi
  done

  exec 1>&${STDOUT_BACKUP}
  exec 2>&${STDERR_BACKUP}

  case "$mode" in
    yad)
      sleep 1
      kill "$YAD_PID"
      rm "$pipe"
      yad --info \
        --title="✅ Batch Complete" \
        --text="All files processed.\n\n✔️ $success\n❌ $fail\n⚠️ $skipped" \
        --button="OK:0" --width=400 --height=120
      ;;
    zenity)
      echo "100" > "$ZENITY_FIFO"
      rm "$ZENITY_FIFO"
      kill "$ZENITY_PID" 2>/dev/null
      zenity --info \
        --title="✅ Batch Complete" \
        --text="All files processed.\n\n✔️ $success\n❌ $fail\n⚠️ $skipped"
      ;;
    dialog)
      sleep 1
      kill "$DIALOG_PID" 2>/dev/null
      rm "$LOG"
      dialog --msgbox "✅ Batch complete:\n✔️ $success\n❌ $fail\n⚠️ $skipped" 10 50
      ;;
    cli)
      echo -e "\n✅ Batch complete:"
      echo "✔️ Successful: $success"
      echo "❌ Failed:     $fail"
      echo "⚠️ Skipped:    $skipped"
      ;;
  esac

  rm "$summary"
}
