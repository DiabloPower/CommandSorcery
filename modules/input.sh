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

clean_chapter_text() {
  awk '
    BEGIN { skip = 0 }
    /(___|<< zurück)/ { skip = 1; next }
    /\+\+\+/ { if (skip) { skip = 0; next } }
    skip == 0 { print }
  ' "$1" |
    sed '/Projekt Gutenberg-DE/d;/Zurück/d;/Weiter/d;/Impressum/d;/Datenschutz/d;/Lesetipps/d;/Nach oben/d;/Kapitelübersicht/d;/∞/d' |
    grep -v 'file:///' |
    sed '/^Seite [0-9]\+$/d;/^[0-9]\{1,3\}$/d;/^[[:punct:]]\+$/d;/^ *$/d' |
    sed -E 's/Shop \+{3,}//g' > "$2"
}

download_and_convert_gutenberg() {
  local url="$1"
  local output="$2"
  local target_dir="$3"
  local disable_toc="$4"

  local workdir
  workdir=$(mktemp -d)
  cd "$workdir" || exit 1

  local book_path
  book_path=$(echo "$url" | sed -E 's|https?://www\.projekt-gutenberg\.org/||; s|/index\.html||')
  wget -qO- "$url" > raw.html

  local raw_clean
  raw_clean=$(sed ':a;N;$!ba;s/\n/ /g' raw.html)
  local author title translator publisher
  author=$(echo "$raw_clean" | sed -n 's/.*<meta name="author"[[:space:]]*content="\([^"]*\)".*/\1/p' | xargs)
  title=$(echo "$raw_clean" | sed -n 's/.*<meta name="title"[[:space:]]*content="\([^"]*\)".*/\1/p' | xargs)
  translator=$(echo "$raw_clean" | sed -n 's/.*<meta name="translator"[[:space:]]*content="\([^"]*\)".*/\1/p' | xargs)
  publisher=$(echo "$raw_clean" | sed -n 's/.*<meta name="publisher"[[:space:]]*content="\([^"]*\)".*/\1/p' | xargs)

  grep -oP "(?<=href=['\"])[^'\"]+\.html(?=['\"])" raw.html | sort -u > all_links.txt
  grep -E "^(titlepage\.html|chap[0-9]+\.html|kap[0-9]+\.html|text[0-9]+\.html)$" all_links.txt > links.txt

  mkdir chapters && cd chapters || exit 1
  while read -r link; do
    [[ "$link" == /* ]] && wget -q "https://www.projekt-gutenberg.org$link" || wget -q "https://www.projekt-gutenberg.org/${book_path}/$link"
  done < ../links.txt

  local cover_image="titel.gif"
  local cover_url="https://www.projekt-gutenberg.org/${book_path}/bilder/${cover_image}"
  wget -q "$cover_url" -O "$cover_image"
  [[ ! -s "$cover_image" ]] && cover_image=""

  #echo "\\newpage" > metadata.txt
  #echo "# $title" >> metadata.txt
  #echo "*by $author*" >> metadata.txt
  #echo "" >> metadata.txt
  #[[ -n "$translator" ]] && echo "### Translated by: $TRANSLATOR" >> metadata.txt
  #[[ -n "$publisher" ]] && echo "### Published by: $publisher" >> metadata.txt
  #[[ -n "$cover_image" ]] && echo "![Cover]($cover_image){ width=95% }" >> metadata.txt
  {
    echo "\\newpage"
    echo "# $TITLE"
    echo ""
    echo "*by $AUTHOR*"
    echo ""
    echo "### Translated by"
    echo "$TRANSLATOR"
    echo ""
    echo "### Published by"
    echo "$PUBLISHER"
    echo ""
    [[ -n "$COVER_IMAGE" ]] && echo "![Cover]($COVER_IMAGE){ width=95% }"
  } > metadata.txt

  local chapter_count=1
  local html_files=(*.html)
  local sorted_files=()
  for f in "${html_files[@]}"; do [[ "$f" != "titlepage.html" ]] && sorted_files+=("$f"); done
  [[ -f "titlepage.html" ]] && sorted_files=("titlepage.html" "${sorted_files[@]}")

  for file in "${sorted_files[@]}"; do
    local raw_txt="${file%.html}.raw.txt"
    lynx -dump "$file" > "$raw_txt"
    clean_chapter_text "$raw_txt" "${file%.html}.clean.txt"

    # Titel-Erkennung und Markdown-Erzeugung wie gehabt...
    # (Du kannst hier deine bestehende awk-Logik modularisieren)

    chapter_count=$((chapter_count + 1))
  done

  local final_txt="${output}.txt"
  if [[ "$disable_toc" == false ]]; then
    echo "\\usepackage{titletoc}" > custom-header.tex
    echo "\\setcounter{tocdepth}{2}" >> custom-header.tex
    echo "\\newcommand{\\customtoc}{\\clearpage\\tableofcontents}" >> custom-header.tex
    echo "\\customtoc" > toc_trigger.txt
    cat metadata.txt toc_trigger.txt chap*.txt > "$final_txt"
  else
    cat metadata.txt chap*.txt > "$final_txt"
  fi

  pandoc "$final_txt" -o "${target_dir}/${output}.pdf" \
    --pdf-engine=xelatex \
    $( [[ "$disable_toc" == false ]] && echo "--include-in-header=custom-header.tex" )

  cd .. && rm -rf "$workdir"
}

get_ffmpeg_input() {
  local mode="$1"
  BITRATE="2"
  QUALITY="28"
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

start_live_log() {
  local mode="$1"
  local logfile="$2"
  case "$mode" in
    yad)
      tail -f "$logfile" | yad --text-info \
        --title="🎬 Batch Converting..." \
        --width=1000 --height=600 \
        --center --wrap --tail --no-buttons &
      ;;
    zenity)
      tail -f "$logfile" &
      ;;
    dialog)
      dialog --tailbox "$logfile" 20 80 &
      ;;
    cli)
      tail -f "$logfile" &
      ;;
  esac
  UI_PID=$!
}

stop_live_log() {
  sleep 1
  kill "$UI_PID" 2>/dev/null
}

start_spinner() {
  (
    while true; do
      echo "# Convertion in progress"
      sleep 1
      echo "# Convertion in progress."
      sleep 1
      echo "# Convertion in progress.."
      sleep 1
      echo "# Convertion in progress..."
      sleep 1
    done
  ) | zenity --progress \
    --title="⏳ Please wait..." \
    --text="Convertion in progress..." \
    --pulsate \
    --auto-close \
    --no-cancel &
  SPINNER_PID=$!
}

stop_spinner() {
  kill "$SPINNER_PID" 2>/dev/null
}

spinner_knight_rider() {
  local msg="🔄 Convertion in progress..."
  local width=50
  local delay=0.1
  local pos=0
  local dir=1

  while true; do
    local line=""
    for ((i=0; i<width; i++)); do
      if (( i == pos )); then
        line+="█"
      else
        line+=" "
      fi
    done
    dialog --infobox "$msg\n[$line]" 6 $((width + 10))
    sleep "$delay"
    ((pos += dir))
    if (( pos == width || pos == 0 )); then
      ((dir *= -1))
    fi
  done
}

run_ffmpeg_batch() {
  local encoder="$1"
  local bitrate="$2"
  local quality="$3"
  local input="$4"
  local output="$5"
  local mode="$6"
  local pix_fmt="$7"
  local ratecontrol="$8"
  local audio_opts="$9"

  echo "📦 starting Batch convertion..."
  shopt -s nullglob
  local formats=(mp4 mkv avi mov flv webm mpeg mpg m4v ts wmv ogg)
  local files=()
  for ext in "${formats[@]}"; do
    files+=("$input"/*."$ext")
  done

  local total=${#files[@]}
  local count=0
  local success=0 fail=0 skipped=0

  local LOGFILE=""
  [[ "$mode" != "dialog" ]] && LOGFILE=$(mktemp) && start_live_log "$mode" "$LOGFILE"

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local base=$(basename "$f")
    local out="${output}/${base%.*}.mkv"
    ((count++))

    if [[ "$(realpath "$f")" == "$(realpath "$out")" ]]; then
      ((skipped++))
      [[ "$mode" != "dialog" ]] && echo "⚠️ skipping (same output): $base" >> "$LOGFILE"
      continue
    fi

    if [[ "$mode" == "dialog" ]]; then
      local LOGTMP=$(mktemp)
      spinner_knight_rider &
      SPINNER_PID=$!
      script -q -c "stdbuf -oL -eL ffmpeg -y $HWACCEL -i '$f' -c:v '$encoder' $ratecontrol -preset medium \
        -pix_fmt '$pix_fmt' \
        -map 0:v -map 0:a \
        $audio_opts '$out'" /dev/null &> "$LOGTMP" &
      FFMPEG_PID=$!
      wait "$FFMPEG_PID"
      kill "$SPINNER_PID" 2>/dev/null
      rm "$LOGTMP"
      [[ $? -eq 0 ]] && ((success++)) || ((fail++))
    else
      echo "🎬 Konvertiere: $base → $(basename "$out")" >> "$LOGFILE"
      local LOGTMP=$(mktemp)
      [[ "$mode" == "zenity" ]] && start_spinner
      stdbuf -oL -eL ffmpeg -y $HWACCEL -i "$f" -c:v "$encoder" $ratecontrol -preset medium \
        -pix_fmt "$pix_fmt" \
        -map 0:v -map 0:a \
        $audio_opts "$out" >> "$LOGTMP" 2>&1 &
      FFMPEG_PID=$!
      tail -f "$LOGTMP" >> "$LOGFILE" &
      TAIL_PID=$!
      wait "$FFMPEG_PID"
      [[ "$mode" == "zenity" ]] && stop_spinner
      kill "$TAIL_PID" 2>/dev/null
      rm "$LOGTMP"

      [[ $? -eq 0 ]] && ((success++)) || ((fail++))
    fi
  done

  [[ "$mode" != "dialog" ]] && stop_live_log && rm "$LOGFILE"

  case "$mode" in
    yad)
      yad --info \
        --title="✅ Batch convertion complete" \
        --text="✔️ successful: $success\n❌ failed: $fail\n⚠️ skipped: $skipped" \
        --button="OK:0" --width=400 --height=120
      ;;
    zenity)
      zenity --info \
        --title="✅ Summary" \
        --text="✔️ successful: $success\n❌ failed: $fail\n⚠️ skipped: $skipped"
      ;;
    dialog)
      dialog --msgbox "✅ Batch convertion complete:\n✔️ successful: $success\n❌ failed: $fail\n⚠️ skipped: $skipped" 10 60
      ;;
    cli)
      echo ""
      echo "📊 Summary:"
      echo "✔️ successful: $success"
      echo "❌ failed:     $fail"
      echo "⚠️ skipped:    $skipped"
      ;;
  esac
}

run_ffmpeg_single() {
  local encoder="$1"
  local bitrate="$2"
  local quality="$3"
  local input="$4"
  local output="$5"
  local mode="$6"
  local pix_fmt="$7"
  local ratecontrol="$8"
  local audio_opts="$9"

  if [[ "$(realpath "$input")" == "$(realpath "$output")" ]]; then
    echo "❌ Input and output file are the same. Aborting."
    return 1
  fi

  local convert_command=(
    ffmpeg -y $HWACCEL -i "$input" -c:v "$encoder" $ratecontrol -preset medium \
    -pix_fmt "$pix_fmt" \
    -map 0:v -map 0:a \
    $audio_opts "$output"
  )

  case "$mode" in
    yad)
      local LOGFILE=$(mktemp)
      "${convert_command[@]}" &> "$LOGFILE" &
      local FFMPEG_PID=$!
      tail -f "$LOGFILE" | yad --text-info \
        --title="🎬 Converting..." \
        --width=800 --height=400 \
        --center --wrap --tail --no-buttons &
      local TAIL_PID=$!
      wait "$FFMPEG_PID"
      kill "$TAIL_PID"
      rm "$LOGFILE"
      yad --info \
        --title="✅ Conversion Complete" \
        --text="Your file has been successfully converted:\n\n$output" \
        --button="OK:0" \
        --width=400 --height=100 --center
      ;;
    zenity)
      start_spinner
      local LOGFILE=$(mktemp)
      "${convert_command[@]}" &> "$LOGFILE" &
      local FFMPEG_PID=$!
      tail -f "$LOGFILE" | zenity --text-info \
        --title="🎬 Converting..." \
        --width=800 --height=400 \
        --center --wrap --tail --no-buttons &
      local TAIL_PID=$!
      wait "$FFMPEG_PID"
      kill "$TAIL_PID" 2>/dev/null
      stop_spinner
      rm "$LOGFILE"
      zenity --info --title="✅ Done" --text="Conversion complete:\n$output"
      ;;
    dialog)
      local LOG=$(mktemp)
      spinner_knight_rider &
      SPINNER_PID=$!
      "${convert_command[@]}" &> "$LOG" &
      local FFMPEG_PID=$!
      wait "$FFMPEG_PID"
      kill "$SPINNER_PID" 2>/dev/null
      rm "$LOG"
      dialog --msgbox "✅ Conversion complete:\n$output" 8 60
      ;;
    cli)
      echo "🎬 Converting..."
      "${convert_command[@]}"
      echo "✅ Conversion complete: $output"
      ;;
  esac
}

select_audio_opts() {
  if [[ "$AUDIO_CHANNELS" -gt 2 ]]; then
    echo "-c:a aac -b:a 384k -ac 2"
  else
    echo "-c:a aac -b:a 192k"
  fi
}

select_nvenc_ratecontrol() {
  local is_maxwell="$1"
  local quality="$2"
  local bitrate="$3"

  if $is_maxwell; then
    # Maxwell: yuv420p
    echo "-rc:v vbr -cq:v $quality -b:v ${bitrate}M -maxrate:v $((bitrate + 1))M -bufsize:v $((bitrate * 4))M -preset medium -profile:v main -tune hq -pix_fmt yuv420p"
  else
    # Turing or newer: yuv444p
    echo "-rc:v vbr -cq:v $quality -b:v ${bitrate}M -maxrate:v $((bitrate + 1))M -bufsize:v $((bitrate * 4))M -preset medium -profile:v main -tune hq -pix_fmt yuv444p"
  fi
}

detect_hwaccel_cuda() {
  # try, CUDA-Decoding
  if ffmpeg -hide_banner -hwaccels 2>/dev/null | grep -q "cuda"; then
    # Optional: try-run with dummy data
    ffmpeg -hwaccel cuda -f lavfi -i testsrc -frames:v 1 -f null - 2>/dev/null
    if [[ $? -eq 0 ]]; then
      echo "-hwaccel cuda"
      return
    fi
  fi
  echo ""
}
