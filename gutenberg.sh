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

# ─────────────────────────────────────────────
# 🧭 Parse command-line arguments
# ─────────────────────────────────────────────

GUI_OVERRIDE=""
SHOW_HELP=false
NO_OPEN=false
DISABLE_TOC=false

for arg in "$@"; do
  case "$arg" in
    --dialog) GUI_OVERRIDE="dialog" ;;
    --zenity) GUI_OVERRIDE="zenity" ;;
    --yad)    GUI_OVERRIDE="yad" ;;
    --cli|--text) GUI_OVERRIDE="none" ;;
    --no-open) NO_OPEN=true ;;
    --no-toc) DISABLE_TOC=true ;;
    --help|-h) SHOW_HELP=true ;;
  esac
done

if $SHOW_HELP; then
  echo ""
  echo "📘 Gutenberg Downloader – Hilfe"
  echo "----------------------------------------"
  echo "Verwendung: ./gutenberg.sh [OPTIONEN]"
  echo ""
  echo "GUI-Modus:"
  echo "  --yad       Nutze YAD als grafische Oberfläche"
  echo "  --zenity    Nutze Zenity als grafische Oberfläche"
  echo "  --dialog    Nutze Dialog (Text-basiert im Terminal)"
  echo "  --cli       Nutze reine Kommandozeile ohne GUI"
  echo ""
  echo "Funktionale Optionen:"
  echo "  --no-toc    Erzeuge Inhaltsverzeichnis im PDF nicht"
  echo "  --no-open   Öffne die PDF nach dem Erstellen nicht automatisch"
  echo "  --help, -h  Zeigt diese Hilfe"
  echo ""
  echo "Beispiel:"
  echo "  ./gutenberg.sh --yad --no-toc --no-open"
  echo ""
  echo "Linkformat zum Buch, Beispiel an Mark Twains Querkopf Wilson:"
  echo "  https://www.projekt-gutenberg.org/twain/querkopf/index.html"
  echo ""
  exit 0
fi

# ─────────────────────────────────────────────
# 🧠 Check for GUI environment and required tools
# ─────────────────────────────────────────────

# Detect if a graphical environment is available
check_gui() {
  GUI_AVAILABLE=false
  if [ -n "$DISPLAY" ]; then GUI_AVAILABLE=true; fi
}

# Check if required tools are installed
check_core_tools() {
  MISSING_CORE=()
  CORE_TOOLS=(wget pandoc lynx pdflatex)

  for tool in "${CORE_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      echo "❌ $tool is not installed."
      MISSING_CORE+=("$tool")
    fi
  done

  if [ ${#MISSING_CORE[@]} -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

check_gui_tool() {
  case "$GUI_TOOL" in
    yad)
      if ! command -v yad &>/dev/null; then
        echo "❌ GUI-Modus 'yad' ist nicht installiert."
        return 1
      fi
      ;;
    zenity)
      if ! command -v zenity &>/dev/null; then
        echo "❌ GUI-Modus 'zenity' ist nicht installiert."
        return 1
      fi
      ;;
    dialog)
      if ! command -v dialog &>/dev/null; then
        echo "❌ GUI-Modus 'dialog' ist nicht installiert."
        return 1
      fi
      ;;
  esac
  return 0
}

# Detect available GUI tool (zenity or dialog)
detect_gui_tool() {
  if [ -n "$GUI_OVERRIDE" ]; then
    GUI_TOOL="$GUI_OVERRIDE"
  elif [ -n "$DISPLAY" ]; then
    if command -v yad &>/dev/null; then
      GUI_TOOL="yad"
    elif command -v zenity &>/dev/null; then
      GUI_TOOL="zenity"
    elif command -v dialog &>/dev/null; then
      GUI_TOOL="dialog"
    else
      GUI_TOOL="none"
    fi
  else
    GUI_TOOL="none"
  fi
}

# Prompt user to run with sudo if tools are missing
install_missing_core() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "🔒 Bitte mit sudo starten, um fehlende Kernpakete zu installieren."
    exit 1
  fi
  echo "📦 Installiere fehlende Kernpakete: ${MISSING_CORE[*]}"
  apt update
  apt install -y "${MISSING_CORE[@]}"
}

# ─────────────────────────────────────────────
# 📥 Get user input via GUI or terminal
# ─────────────────────────────────────────────

# Ask user to choose output folder
get_user_input() {
  case "$GUI_TOOL" in
    yad)
      FORM_OUTPUT=$(yad --form \
        --title="Gutenberg Downloader" \
        --width=800 \
        --height=200 \
        --center \
        --window-icon="book" \
        --field="📘 Buch-URL zur Projekt Gutenberg-Seite (e.g. https://www.projekt-gutenberg.org/twain/querkopf/index.html)":LBL \
        --field="📘 Enter book URL": \
        --field="📄 PDF filename (without .pdf)": \
        --field="📁 Choose output folder":DIR \
        "" "" "" "$HOME")
      [ $? -ne 0 ] && echo "🚫 Abgebrochen." && exit 1
      IFS="|" read -r _ URL OUTPUT TARGET_DIR <<< "$FORM_OUTPUT"
      ;;
    zenity)
      URL=$(zenity --entry \
        --title="Gutenberg URL" \
        --text="Enter book URL (e.g. https://www.projekt-gutenberg.org/twain/querkopf/index.html):")
      [ $? -ne 0 ] && echo "🚫 Abgebrochen." && exit 1
      OUTPUT=$(zenity --entry --title="Filename" --text="Enter PDF filename (without .pdf):")
      [ $? -ne 0 ] && echo "🚫 Abgebrochen." && exit 1
      TARGET_DIR=$(zenity --file-selection --directory --title="Choose output folder")
      [ $? -ne 0 ] && echo "🚫 Abgebrochen." && exit 1
      ;;
    dialog)
        dialog --inputbox "Enter book URL (e.g. https://www.projekt-gutenberg.org/twain/querkopf/index.html):" 10 70 3>&1 1>&2 2>&3
        DIALOG_EXIT=$?
        if [ "$DIALOG_EXIT" -ne 0 ]; then
          echo "🚫 Abgebrochen." && exit 1
        fi
        URL=$(dialog --inputbox "Enter book URL (e.g. https://www.projekt-gutenberg.org/twain/querkopf/index.html):" 10 70 3>&1 1>&2 2>&3)

        dialog --inputbox "Enter PDF filename (without .pdf):" 10 60 3>&1 1>&2 2>&3
        DIALOG_EXIT=$?
        if [ "$DIALOG_EXIT" -ne 0 ]; then
          echo "🚫 Abgebrochen." && exit 1
        fi
        OUTPUT=$(dialog --inputbox "Enter PDF filename (without .pdf):" 10 60 3>&1 1>&2 2>&3)

        dialog --dselect "$HOME/" 10 60 3>&1 1>&2 2>&3
        DIALOG_EXIT=$?
        if [ "$DIALOG_EXIT" -ne 0 ]; then
          echo "🚫 Abgebrochen." && exit 1
        fi
        TARGET_DIR=$(dialog --dselect "$HOME/" 10 60 3>&1 1>&2 2>&3)
      ;;
    *)
      echo "📘 Please enter the book URL in the format:"
      echo "    https://www.projekt-gutenberg.org/twain/querkopf/index.html"
      read -p "🔗 Book URL: " URL
      read -p "📄 Filename (without .pdf): " OUTPUT
      read -p "📁 Output folder: " TARGET_DIR
      ;;
  esac
}

# ─────────────────────────────────────────────
# 📚 Download chapters and convert to text
# ─────────────────────────────────────────────

# Clean up unwanted lines from chapter text
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

# Main function to download, process, and generate PDF
download_and_convert() {
  CHAPTER_COUNT=1
  WORKDIR=$(mktemp -d)
  cd "$WORKDIR" || exit 1

  # Extract book path from URL
  BOOK_PATH=$(echo "$URL" | sed -E 's|https?://www\.projekt-gutenberg\.org/||; s|/index\.html||')
  wget -qO- "$URL" > raw.html

  # Extract metadata from raw HTML
  RAW_CLEAN=$(sed ':a;N;$!ba;s/\n/ /g' raw.html)
  AUTHOR=$(echo "$RAW_CLEAN" | sed -n 's/.*<meta name="author"[[:space:]]*content="\([^"]*\)".*/\1/p' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  TITLE=$(echo "$RAW_CLEAN" | sed -n 's/.*<meta name="title"[[:space:]]*content="\([^"]*\)".*/\1/p' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  TRANSLATOR=$(echo "$RAW_CLEAN" | sed -n 's/.*<meta name="translator"[[:space:]]*content="\([^"]*\)".*/\1/p' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  PUBLISHER=$(echo "$RAW_CLEAN" | sed -n 's/.*<meta name="publisher"[[:space:]]*content="\([^"]*\)".*/\1/p' | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Show extracted metadata
  echo "📘 Title: $TITLE"
  echo "✍️ Author: $AUTHOR"
  echo "🌍 Translator: $TRANSLATOR"
  echo "🏢 Publisher: $PUBLISHER"

  # Extract chapter links
  grep -oP "(?<=href=['\"])[^'\"]+\.html(?=['\"])" raw.html | sort -u > all_links.txt
  grep -E "^(titlepage\.html|chap[0-9]+\.html|kap[0-9]+\.html|text[0-9]+\.html)$" all_links.txt > links.txt

  mkdir chapters
  cd chapters || exit 1

  # Download all chapter HTML files
  while read -r link; do
    [[ "$link" == /* ]] && wget -q "https://www.projekt-gutenberg.org$link" || wget -q "https://www.projekt-gutenberg.org/${BOOK_PATH}/$link"
  done < ../links.txt

  # Try to download cover image
  COVER_IMAGE="titel.gif"
  COVER_URL="https://www.projekt-gutenberg.org/${BOOK_PATH}/bilder/${COVER_IMAGE}"
  wget -q "$COVER_URL" -O "$COVER_IMAGE"
  #[[ -f "$COVER_IMAGE" ]] && echo "✅ Cover image downloaded: $COVER_IMAGE" || COVER_IMAGE=""
  if [[ -f "$COVER_IMAGE" && -s "$COVER_IMAGE" ]]; then
    echo "✅ Cover image downloaded: $COVER_IMAGE"
  else
    echo "⚠️ Kein gültiges Coverbild gefunden."
    COVER_IMAGE=""
  fi

  # Create metadata page
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
   
  # Convert each chapter to clean text
  HTML_FILES=(*.html)
  HTML_FILES_SORTED=()
  for f in "${HTML_FILES[@]}"; do [[ "$f" != "titlepage.html" ]] && HTML_FILES_SORTED+=("$f"); done
  [[ -f "titlepage.html" ]] && HTML_FILES_SORTED=("titlepage.html" "${HTML_FILES_SORTED[@]}")

  for file in "${HTML_FILES_SORTED[@]}"; do
    TMP_TXT="${file%.html}.raw.txt"
    lynx -dump "$file" > "$TMP_TXT"
    clean_chapter_text "$TMP_TXT" "${file%.html}.clean.txt"
  
    if [[ "$file" == "titlepage.html" ]]; then
      sed -E 's/^\*?[[:space:]]*//' "${file%.html}.clean.txt" |
      sed -E 's/^\[[0-9]+\][[:space:]]*//' > "${file%.html}.pre.txt"
      echo "\\newpage" > "${file%.html}.txt"
      [[ -n "$COVER_IMAGE" ]] && echo "![Cover]($COVER_IMAGE)" >> "${file%.html}.txt" && echo "" >> "${file%.html}.txt"
      cat "${file%.html}.pre.txt" >> "${file%.html}.txt"
    else
      sed -E 's/^\*?[[:space:]]*//' "${file%.html}.clean.txt" |
      sed -E 's/^\[[0-9]+\][[:space:]]*//' > "${file%.html}.pre.txt"

      # scan for Title (Bash only)
      SPECIAL_TITLES="Schlu(ß|ss)|Fin|Epilog|Nachwort|Prolog|Ende"
      CHAPTER_TITLE="$(
        grep -E -m1 \
          "^[[:space:]]*[0-9]+[[:space:]]*\.*[[:space:]]*Kapitel.*$|^[[:space:]]*[[:alpha:]ÄÖÜäöüß-]+(tes|stes)[[:space:]]+Kapitel.*$|^[[:space:]]*(${SPECIAL_TITLES})\.?$" \
          "${file%.html}.pre.txt" \
        | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
      )"

      [[ -z "$CHAPTER_TITLE" ]] && CHAPTER_TITLE="Kapitel $CHAPTER_COUNT"

      # generate Chapter file
      awk -v c="$CHAPTER_COUNT" -v hdr="$CHAPTER_TITLE" -v specials="$SPECIAL_TITLES" '
      function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
      BEGIN {
        print "\\newpage\n"
        printf("## Chapter %d – %s\n\n", c, hdr)
      }
      {
        line = $0
        t = trim(line)

        # 1) Skip the original title line (numeric, textual, special, or exact hdr), wherever it occurs
        if (title_skipped == 0 &&
            ( t == hdr ||
              t ~ /^[0-9]+\.([[:space:]]*)Kapitel\b.*/ ||
              t ~ /^[A-ZÄÖÜa-zäöüß-]+(stes|tes)[[:space:]]+Kapitel\b.*/ ||
              (specials != "" && t ~ ("^(" specials ")\\b.*")) )) {
          title_skipped = 1
          expect_subtitle = 1
          next
        }

        # 2) If the very next non-empty line looks like a subtitle, emit it as ### and skip it
        if (expect_subtitle == 1 && t != "") {
          # Heuristics: short line, contains a separator (–, -, :) and is not itself a title
          is_title = ( t ~ /^[0-9]+\.([[:space:]]*)Kapitel\b.*/ ||
                       t ~ /^[A-ZÄÖÜa-zäöüß-]+(stes|tes)[[:space:]]+Kapitel\b.*/ ||
                       (specials != "" && t ~ ("^(" specials ")\\b.*")) )
          if (!is_title && (length(t) <= 200) && (t ~ /[–-]|:/)) {
            printf("### %s\n\n", t)
            expect_subtitle = 0
            next
          } else {
            # No subtitle; fall through to normal text
            expect_subtitle = 0
          }
        }

        # 3) Normal content
        print line
      }
      ' "${file%.html}.pre.txt" > "${file%.html}.txt"

      # Shell output
      echo "📘 Kapitel erkannt: Chapter $CHAPTER_COUNT – $CHAPTER_TITLE"
      CHAPTER_COUNT=$((CHAPTER_COUNT + 1))
    fi
    
    # Remove intermediate files to keep things tidy
    rm "$TMP_TXT" "${file%.html}.clean.txt" "${file%.html}.pre.txt"
  done
  
  # 📦 Merge all processed text files into one
  echo "📦 Merging all chapters..."
  if ! $DISABLE_TOC; then
  # generate LaTeX-Header for Pandoc
  {
    echo "\\usepackage{titletoc}"
    echo "\\setcounter{tocdepth}{2}"
    echo "\\newcommand{\\customtoc}{"
    echo "  \\clearpage"
    echo "  \\tableofcontents"
    echo "}"
  } > custom-header.tex

  # TOC-Trigger in Markdown
  echo "\\customtoc" > toc_trigger.txt

  # Merge: Cover → TOC → Capital
    cat metadata.txt toc_trigger.txt chap*.txt > "${OUTPUT}.txt"
  else
    cat metadata.txt chap*.txt > "${OUTPUT}.txt"
  fi

  # 🖨 Generate PDF in the target directory
  echo "🖨 Generating PDF..."
  PANDOC_OPTIONS=("--pdf-engine=xelatex")
  ! $DISABLE_TOC && PANDOC_OPTIONS+=("--include-in-header=custom-header.tex")

  pandoc "${OUTPUT}.txt" -o "${TARGET_DIR}/${OUTPUT}.pdf" "${PANDOC_OPTIONS[@]}"

  # Return to working directory root for cleanup
  cd ..
}

# ─────────────────────────────────────────────
# 🧹 Cleanup temporary files
# ─────────────────────────────────────────────

cleanup() {
  echo "🧽 Cleaning up temporary files..."
  cd "$TARGET_DIR" || cd /tmp
  rm -rf "$WORKDIR"
  echo "✅ Done! PDF saved as: ${TARGET_DIR}/${OUTPUT}.pdf"
  
  # 🧭 Optionally do not open the PDF after generation
  if ! $NO_OPEN; then
    xdg-open "${TARGET_DIR}/${OUTPUT}.pdf" &
  fi
}

# ─────────────────────────────────────────────
# 🚀 Main execution
# ─────────────────────────────────────────────

echo "📋 Gutenberg Downloader started…"
check_gui
check_core_tools
if ! check_core_tools; then
  install_missing_core
fi

detect_gui_tool
echo "🖥️ Eingabemodus: $GUI_TOOL"
check_gui_tool || {
  echo "⚠️ GUI '$GUI_TOOL' nicht verfügbar. Bitte installieren oder anderen Modus wählen."
  exit 1
}
get_user_input
download_and_convert
cleanup
