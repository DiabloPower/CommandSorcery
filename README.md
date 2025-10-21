# CommandSorcery
A growing arsenal of command-line spells — crafted for automation, diagnostics, and everyday CLI enchantments. Bash-centric and more.

## Scripts

### [`gutenberg.sh`](./gutenberg.sh): 

A shell script for fetching, organizing, and exporting books from [Projekt Gutenberg-DE](https://www.projekt-gutenberg.org/) as polished PDFs.

### 🧙‍♂️ Interface Options:

This script supports multiple user interfaces:

- 🖥️ CLI (Command Line)
- 🪟 Dialog
- 🪄 Zenity
- 🧿 YAD

The interface can be selected automatically based on availability, or manually via command-line override.

### 🧾 Usage:

To view all available options and usage instructions, simply run:

```bash
./gutenberg.sh --help
```

### 🧰 Core Dependencies

These tools are essential for the script to function properly. If missing, they will be automatically installed via apt (with sudo):

- wget – for downloading web pages and files
- pandoc – for converting text formats (e.g., Markdown to PDF)
- lynx – for parsing and extracting text from HTML
- pdflatex – for generating PDFs via LaTeX (used by Pandoc)

### 🧩 Optional GUI Dependencies

These are only installed if explicitly requested via:

```bash
--install-if-missing=yad
```

Available options:

- yad – graphical form and live log window
- zenity – entry dialogs and progress spinner
- dialog – text-based UI for terminal environments

---

## [`ffmpeg-convert-mkv.sh`](./ffmpeg-convert-mkv.sh):

A flexible shell script for converting video files with FFmpeg including single-file and batch directory conversion, supporting hardware acceleration (NVENC) and multiple user interfaces. It accepts virtually any input format (e.g. AVI, MP4, MOV) and re-encodes the video using H.265 — either via libx265 or NVENC if available — while converting audio to AAC. The output container is determined by the file extension you specify, such as .mkv, .mp4, or others.

### 🎛️ Interface Options:

This script supports multiple user interfaces:

- 🖥️ CLI (Command Line)
- 🪟 Dialog
- 🪄 Zenity
- 🧿 YAD

The interface can be selected manually via command-line flags, or defaults to YAD if available.

### 🧾 Usage:

To view all available options and usage instructions, simply run:

```bash
./ffmpeg-convert-mkv.sh --help
```

### 🧰 Core Dependencies

ffmpeg – required for video conversion (automatically installed via apt if missing)

### 🧩 Optional GUI Dependencies

These are only installed if explicitly requested via:

```bash
--install-if-missing=yad
```

Available options:

- yad – graphical form and live log window
- zenity – entry dialogs and progress spinner
- dialog – text-based UI for terminal environments

### ⚡ Hardware Acceleration

If NVIDIA NVENC is available, the script will use hevc_nvenc for faster encoding. Otherwise, it falls back to libx265.

### 🗂️ Batch Mode

This script now supports a powerful batch mode for converting entire directories of video files. You can activate it via:

```bash
--batch
```
When enabled, the script will prompt for input and output directories (via GUI or CLI), then process all supported video formats in one go. It includes:

- ✅ Automatic format detection
- ✅ Live progress display (YAD)
- ✅ Summary of successful, failed, and skipped conversions
- ✅ Safety check to prevent overwriting input files

---
to be continued...

## 🧙‍♂️ Development Notes

This project was developed and tested on a Debian-based system (Zorin OS 17.3). The scripts attempt to install their required dependencies automatically via apt, if missing.

## 🧠 Remote Execution from GitHub
You can run these scripts directly from GitHub without downloading them manually. This is useful for quick usage, automation, or testing across multiple systems.

### 🧾 Example: Run gutenberg.sh directly
```bash
bash <(curl -s https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main/gutenberg.sh)
```
Or using wget:
```bash
bash <(wget -qO - https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main/gutenberg.sh)
```
### 🎬 Example: Run ffmpeg-convert-mkv.sh directly
```bash
bash <(curl -s https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main/ffmpeg-convert-mkv.sh)
```
Or using wget:
```bash
bash <(wget -qO - https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main/ffmpeg-convert-mkv.sh)
```
You can pass any flags as usual, for example:

```bash
bash <(curl -s https://raw.githubusercontent.com/DiabloPower/CommandSorcery/main/ffmpeg-convert-mkv.sh) --batch --yad
```

⚠️ Note: This requires internet access and assumes the script is compatible with your system. Dependencies will be installed automatically if missing (via apt).

## 📜 License

```plaintext
# 
# Copyright (c) 2024 Ronny Hamann
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
```

## Contributing
Feel free to open issues or submit pull requests if you want to contribute to the project.

## Contact
For any questions or feedback, please contact Ronny Hamann.
