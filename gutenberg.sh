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

BASE_URL="https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main"
SELF_PATH="$0"

# Load modules (remote oder lokal)
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

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo ""
  echo "📘 Gutenberg Downloader – Hilfe"
  echo "----------------------------------------"
  echo "Verwendung: ./gutenberg.sh [OPTIONEN]"
  echo ""
  echo "GUI-Modus:"
  echo "  --yad | --zenity | --dialog | --cli"
  echo ""
  echo "Funktionale Optionen:"
  echo "  --no-toc       – Inhaltsverzeichnis deaktivieren"
  echo "  --no-open      – PDF nach Erstellung nicht öffnen"
  echo "  --help, -h     – Diese Hilfe anzeigen"
  echo ""
  exit 0
fi

# ─────────────────────────────────────────────
# 🧭 Argumente parsen
# ─────────────────────────────────────────────

GUI_OVERRIDE=""
NO_OPEN=false
DISABLE_TOC=false

for arg in "$@"; do
  case "$arg" in
    --yad|--zenity|--dialog|--cli|--text) GUI_OVERRIDE="${arg#--}" ;;
    --no-open) NO_OPEN=true ;;
    --no-toc) DISABLE_TOC=true ;;
  esac
done

# ─────────────────────────────────────────────
# 🧠 Setup
# ─────────────────────────────────────────────

detect_ui "$GUI_OVERRIDE"
check_ui_tool || exit 1
check_core_tools wget pandoc lynx pdflatex || install_missing_core

# ─────────────────────────────────────────────
# 📥 Eingabe holen
# ─────────────────────────────────────────────

get_gutenberg_input "$UI_TOOL" || exit 1
# Ergebnis: URL, OUTPUT, TARGET_DIR sind gesetzt

# ─────────────────────────────────────────────
# 📚 Buch verarbeiten
# ─────────────────────────────────────────────

download_and_convert_gutenberg "$URL" "$OUTPUT" "$TARGET_DIR" "$DISABLE_TOC"

# ─────────────────────────────────────────────
# ✅ PDF anzeigen oder beenden
# ─────────────────────────────────────────────

PDF_PATH="${TARGET_DIR}/${OUTPUT}.pdf"
echo "✅ PDF erstellt: $PDF_PATH"

if ! $NO_OPEN; then
  xdg-open "$PDF_PATH" &
fi
