#!/usr/bin/env bash
# Apply build/compilation-fix patches only.
# Run from this repo root. Set AOSP_ROOT if your aosp tree is not in ./aosp.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOSP_ROOT="${AOSP_ROOT:-$SCRIPT_DIR/aosp}"

if [ ! -d "$AOSP_ROOT" ]; then
  echo "Error: AOSP root not found at $AOSP_ROOT. Set AOSP_ROOT or clone/sync into ./aosp."
  exit 1
fi

cd "$AOSP_ROOT"

BUILD_DIR="$SCRIPT_DIR/patches/01-build-fixes"
if [ ! -d "$BUILD_DIR" ]; then
  echo "No build-fixes directory found. Skipping."
  exit 0
fi

for p in "$BUILD_DIR"/*.patch; do
  [ -f "$p" ] || continue
  name=$(basename "$p" .patch)
  case "$name" in
    build_make)              repo_path="build/make" ;;
    build_soong)            repo_path="build/soong" ;;
    device_brcm_rpi5_build) repo_path="device/brcm/rpi5" ;;
    *)
      echo "Unknown build patch: $name. Add a mapping in apply_build_patches.sh and remove_build_patches.sh."
      exit 1
      ;;
  esac
  echo "Applying build fix: $name -> $repo_path"
  (cd "$repo_path" && git apply --whitespace=fix "$p")
done

echo "Build patches applied successfully."
