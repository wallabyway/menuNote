#!/bin/bash
# Optional: regenerate assets/AppIcon.icns from icon.iconset PNGs (requires macOS)
set -euo pipefail
cd "$(dirname "$0")/assets"
iconutil -c icns icon.iconset -o AppIcon.icns
echo "Wrote assets/AppIcon.icns"
