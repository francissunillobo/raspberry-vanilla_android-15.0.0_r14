#!/usr/bin/env bash
# Remove both fan-control and build-fixes patches (convenience wrapper).
# Reverts in reverse order: fan first, then build.
# Run from this repo root. Set AOSP_ROOT if your aosp tree is not in ./aosp.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/remove_fan_patch.sh"
"$SCRIPT_DIR/remove_build_patches.sh"
echo "All patches removed successfully."
