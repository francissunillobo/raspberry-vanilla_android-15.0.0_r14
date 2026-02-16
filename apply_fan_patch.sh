#!/usr/bin/env bash
# Apply fan-control patch only (device/brcm/rpi5).
# Run from this repo root. Set AOSP_ROOT if your aosp tree is not in ./aosp.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOSP_ROOT="${AOSP_ROOT:-$SCRIPT_DIR/aosp}"

if [ ! -d "$AOSP_ROOT" ]; then
  echo "Error: AOSP root not found at $AOSP_ROOT. Set AOSP_ROOT or clone/sync into ./aosp."
  exit 1
fi

FAN_PATCH="$SCRIPT_DIR/patches/02-fan-control/device_brcm_rpi5_fancontrol.patch"
if [ ! -f "$FAN_PATCH" ]; then
  echo "Error: Fan control patch not found at $FAN_PATCH"
  exit 1
fi

cd "$AOSP_ROOT"
echo "Applying fan control patch in device/brcm/rpi5"
(cd device/brcm/rpi5 && git apply --whitespace=fix "$FAN_PATCH")
echo "Fan control patch applied successfully."
