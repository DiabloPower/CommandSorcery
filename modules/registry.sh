# modules/registry.sh
# Script registry and option metadata
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

declare -A SCRIPTS=(
  [gutenberg]="gutenberg.sh"
  [convert]="ffmpeg-convert-mkv.sh"
)

declare -A SCRIPT_OPTIONS=(
  [gutenberg]="--no-toc --no-open"
  [convert]="--batch"
)

declare -A SCRIPT_OPTIONS_DESC=(
  [gutenberg--no-toc]="Remove table of contents"
  [gutenberg--no-open]="Do not open PDF after download"
  [convert--batch]="Convert all videos in folder"
)
