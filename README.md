# CommandSorcery
A growing arsenal of command-line spells — crafted for automation, diagnostics, and everyday CLI enchantments. Bash-centric and more.

## Scripts

### gutenberg.sh: 

A shell script for fetching, organizing, and exporting books from [Projekt Gutenberg-DE](https://www.projekt-gutenberg.org/) as polished PDFs.

🧙‍♂️ Interface Options:

This script supports multiple user interfaces:

- 🖥️ CLI (Command Line)
- 🪟 Dialog
- 🪄 Zenity
- 🧿 YAD

The interface can be selected automatically based on availability, or manually via command-line override.

🧾 Usage:

To view all available options and usage instructions, simply run:

```bash
./gutenberg.sh --help
```

🧰 Core Dependencies

These tools are essential for the script to function properly. If missing, they will be automatically installed via apt (with sudo):

- wget – for downloading web pages and files
- pandoc – for converting text formats (e.g., Markdown to PDF)
- lynx – for parsing and extracting text from HTML
- pdflatex – for generating PDFs via LaTeX (used by Pandoc)

---
to be continued...

## 🧙‍♂️ Development Notes

This project was developed and tested on a Debian-based system (Zorin OS 17.3). The scripts attempt to install their required dependencies automatically via apt, if missing.

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
