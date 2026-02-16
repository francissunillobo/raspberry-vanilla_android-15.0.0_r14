#!/usr/bin/env bash
# Apply both build-fixes and fan-control patches (convenience wrapper).
# Run from this repo root. Set AOSP_ROOT if your aosp tree is not in ./aosp.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/apply_build_patches.sh"
"$SCRIPT_DIR/apply_fan_patch.sh"
echo "All patches applied successfully."
