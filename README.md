# Raspberry Vanilla Android 15.0.0_r14 (RPi4 / RPi5)

Manifests and patches to build AOSP Android 15 for Raspberry Pi 4 and Raspberry Pi 5. Source code is **not** in this repo; it is fetched from [AOSP](https://source.android.com) and [Raspberry Vanilla](https://github.com/raspberry-vanilla) using the manifests below.

**Base:** AOSP `android-15.0.0_r14` + [Raspberry Vanilla android_local_manifest](https://github.com/raspberry-vanilla/android_local_manifest/tree/android-15.0.0_r14).

---

## Contents of this repository

| Path | Description |
|------|-------------|
| `manifest/manifest_brcm_rpi.xml` | Raspberry Vanilla overlay (device, build, audio, camera, etc.). |
| `manifest/remove_projects.xml` | Drops unneeded AOSP projects to reduce sync size with `--depth=1`. |
| `patches/01-build-fixes/` | **Build/compilation** patches (one `.patch` per repo). Add your own here. |
| `patches/02-fan-control/` | **RPi5 fan control** patch for `device/brcm/rpi5`. |
| **Build patches** | |
| `apply_build_patches.sh` | Apply build-fix patches only. |
| `remove_build_patches.sh` | Remove (revert) build-fix patches only. |
| **Fan control patch** | |
| `apply_fan_patch.sh` | Apply fan-control patch only. |
| `remove_fan_patch.sh` | Remove (revert) fan-control patch only. |
| **Convenience (both)** | |
| `apply_patches.sh` | Apply build + fan patches. |
| `remove_patches.sh` | Remove build + fan patches (fan first, then build). |
| `docs/FAN_CONTROL.md` | Fan control overview and references. |

---

## Prerequisites

- **OS:** Ubuntu 22.04 LTS (recommended).
- **Disk:** ~400 GB free (less with shallow clone and `remove_projects.xml`).
- **Packages:**

```bash
sudo apt-get update
sudo apt-get install -y coreutils dosfstools e2fsprogs fdisk kpartx mtools ninja-build pkg-config python3-pip rsync
sudo pip3 install dataclasses jinja2 mako meson ply pyyaml
```

Follow [AOSP initial setup](https://source.android.com/setup/start) (install `repo`, git, etc.) if needed.

---

## 1. Download the source code

Clone this repo (for manifests and patches):

```bash
git clone https://github.com/francissunillobo/raspberry-vanilla_android-15.0.0_r14.git rpi-setup
cd rpi-setup
```

Initialize AOSP and add the Raspberry Vanilla overlay (shallow clone to save space):

```bash
mkdir -p aosp && cd aosp
repo init -u https://android.googlesource.com/platform/manifest -b android-15.0.0_r14 --depth=1
mkdir -p .repo/local_manifests
cp ../manifest/manifest_brcm_rpi.xml .repo/local_manifests/
cp ../manifest/remove_projects.xml .repo/local_manifests/
repo sync -j4
cd ..
```

---

## 2. Apply and remove patches

From the **repo root** (directory that contains the scripts and `aosp/`). If your AOSP tree is not in `./aosp`, set `AOSP_ROOT=/path/to/your/aosp`.

### Option A: Apply or remove both (build + fan)

```bash
./apply_patches.sh    # apply build fixes, then fan control
./remove_patches.sh   # remove fan control, then build fixes
```

### Option B: Build issues only

```bash
./apply_build_patches.sh   # apply patches in patches/01-build-fixes/
./remove_build_patches.sh # revert those patches
```

### Option C: Fan control only

```bash
./apply_fan_patch.sh   # apply patches/02-fan-control/device_brcm_rpi5_fancontrol.patch
./remove_fan_patch.sh  # revert the fan control patch
```

---

## 3. Build

```bash
cd aosp
. build/envsetup.sh
lunch aosp_rpi5-ap4a-userdebug
make bootimage systemimage vendorimage -j$(nproc)
./device/brcm/rpi5/rpi5-mkimg.sh
```

For **RPi4:** `lunch aosp_rpi4-ap4a-userdebug` and `./rpi4-mkimg.sh`.

Images are under `out/target/product/rpi5/` (or `rpi4/`).

---

## 4. Flash to device

Write the image to SD card or USB (replace `sdX` with your block device, e.g. `sdb`):

```bash
sudo dd if=aosp/out/target/product/rpi5/sdimg.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Or use Raspberry Pi Imager / Balena Etcher with the built image, then boot the device.

---

## Adding build-fix patches

1. Put one `.patch` file per modified repo in `patches/01-build-fixes/` (e.g. `build_make.patch`, `build_soong.patch`).
2. Add the same name and repo path in both `apply_build_patches.sh` and `remove_build_patches.sh` (see the `case "$name" in` block).

To generate a patch from a modified project:

```bash
cd aosp/build/make   # or the repo you changed
git diff origin/android-15.0.0_r14 -- . > /path/to/raspberry-vanilla_android-15.0.0_r14/patches/01-build-fixes/build_make.patch
```

---

## References

- [Raspberry Vanilla android_local_manifest (android-15.0.0_r14)](https://github.com/raspberry-vanilla/android_local_manifest/tree/android-15.0.0_r14)
- [AOSP source](https://source.android.com)
- [Raspberry Pi 5](https://www.raspberrypi.com/products/raspberry-pi-5/)
