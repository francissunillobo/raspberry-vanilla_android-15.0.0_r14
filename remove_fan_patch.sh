#!/usr/bin/env bash
# Remove (revert) fan-control patch only (device/brcm/rpi5).
# Run from this repo root. Set AOSP_ROOT if your aosp tree is not in ./aosp.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOSP_ROOT="${AOSP_ROOT:-$SCRIPT_DIR/aosp}"

if [ ! -d "$AOSP_ROOT" ]; then
  echo "Error: AOSP root not found at $AOSP_ROOT. Set AOSP_ROOT or use ./aosp."
  exit 1
fi

FAN_PATCH="$SCRIPT_DIR/patches/02-fan-control/device_brcm_rpi5_fancontrol.patch"
if [ ! -f "$FAN_PATCH" ]; then
  echo "Error: Fan control patch not found at $FAN_PATCH"
  exit 1
fi

cd "$AOSP_ROOT"
echo "Reverting fan control patch in device/brcm/rpi5"
(cd device/brcm/rpi5 && git apply -R --whitespace=fix "$FAN_PATCH" || true)
echo "Fan control patch removed successfully."
