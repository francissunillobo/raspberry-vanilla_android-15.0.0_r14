# Raspberry Pi 5 Fan Control (AOSP)

This document describes the temperature-based fan control used on Raspberry Pi 5 Android (Raspberry Vanilla AOSP) and how to build, flash, and verify it.

---

## Changes made (code and locations)

This section lists every file that was **added** or **modified** for fan control, and the exact code that was added or changed. Paths are relative to the AOSP tree root (e.g. `aosp/`).

---

### 1. New file: `device/brcm/rpi5/fancontrol.sh`

**Purpose:** Main fan control script. Runs at boot, drives PWM or GPIO 12 based on SoC temperature.

**Install path:** `/vendor/bin/fancontrol.sh` (must be executable: `chmod +x fancontrol.sh` in the repo).

**What it does:**

- Tries, in order: hwmon `pwm1` → pwmchip0/pwm0 (GPIO 12) → GPIO 12 on/off.
- Reads `/sys/class/thermal/thermal_zone0/temp` every 2 seconds.
- Temperature curve: &lt; 45°C → 0 (OFF), 45–55°C → 64 (LOW), 55–65°C → 170 (MEDIUM), ≥ 65°C → 255 (FULL).
- First 60 seconds after start: runs fan at MEDIUM (170) for boot; then switches to the temp-based loop.

**Full contents:** See the file in the tree. Key parts:

- `T=/sys/class/thermal/thermal_zone0/temp`
- Loop over `/sys/class/hwmon/hwmon*/pwm1` to find PWM.
- Fallback: `/sys/class/pwm/pwmchip0/export`, then `pwm0/period`, `duty_cycle`, `enable`.
- Fallback: `/sys/class/gpio/export` (12), then `gpio12/direction` (out), `value` (0 or 1).
- `set_speed()` writes to the chosen path; `speed_from_temp()` returns 0, 64, 170, or 255.
- Boot: `set_speed 170` then `sleep 60`; then `while true` loop with `get_temp`, `speed_from_temp`, `set_speed`, `sleep 2`.

---

### 2. New file: `device/brcm/rpi5/fancontrol.rc`

**Purpose:** Init service definition so `fancontrol.sh` is started during boot (with the `late_start` class).

**Install path:** `/vendor/etc/init/fancontrol.rc`.

**Code added (entire file):**

```rc
# Fan control: temp-based PWM (OFF < 45C, LOW 45-55C, MEDIUM 55-65C, FULL >= 65C)
# Starts with late_start (during boot); fan runs at MEDIUM until thermal loop takes over.
service fancontrol /vendor/bin/fancontrol.sh
    class late_start
    user root
    group root system
```

---

### 3. Modified: `device/brcm/rpi5/boot/config.txt`

**Purpose:** Avoid kernel `gpio-fan` overlay so only the vendor script controls the fan (no double control on the same pin).

**Change:** At the end of the file, **replaced** the previous fan overlay line with a comment:

**Before (example):**

```txt
# Fan: turn on when SoC temp >= 55 C (PWM on GPIO 12)
dtoverlay=gpio-fan,gpiopin=12,temp=55000
```

**After (what is there now):**

```txt
# Fan: controlled by vendor fancontrol service (temp-based PWM)
# Do not use dtoverlay=gpio-fan here to avoid conflict.
```

So: **no** `dtoverlay=gpio-fan` line; only the two comment lines above.

---

### 4. Modified: `device/brcm/rpi5/ramdisk/init.rpi5.rc`

**Purpose:** Load the fan control service definition so init starts `fancontrol`.

**Change:** One line added after the first `import`.

**Added (line 2):**

```rc
import /vendor/etc/init/fancontrol.rc
```

So the top of the file is:

```rc
import /vendor/etc/init/hw/init.rpi5.usb.rc
import /vendor/etc/init/fancontrol.rc

on init
    ...
```

---

### 5. Modified: `device/brcm/rpi5/device.mk`

**Purpose:** Copy the script and the `.rc` file into the vendor image.

**Change:** One new `PRODUCT_COPY_FILES` block added after the Ramdisk block.

**Added (after the Ramdisk PRODUCT_COPY_FILES block):**

```makefile
# Fan control (temp-based: OFF < 45C, LOW 45-55C, MEDIUM 55-65C, FULL >= 65C)
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/fancontrol.sh:$(TARGET_COPY_OUT_VENDOR)/bin/fancontrol.sh \
    $(DEVICE_PATH)/fancontrol.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/fancontrol.rc
```

**Note:** `$(DEVICE_PATH)` is `device/brcm/rpi5`. The script must be executable in the repo (`chmod +x device/brcm/rpi5/fancontrol.sh`).

---

### Summary of changes

| Location | Action | What |
|----------|--------|------|
| `device/brcm/rpi5/fancontrol.sh` | **Created** | Script: PWM/GPIO discovery, temp curve, boot phase + loop. |
| `device/brcm/rpi5/fancontrol.rc` | **Created** | Init service `fancontrol` with class `late_start`. |
| `device/brcm/rpi5/boot/config.txt` | **Modified** | Removed `dtoverlay=gpio-fan`; added comment that fan is controlled by vendor service. |
| `device/brcm/rpi5/ramdisk/init.rpi5.rc` | **Modified** | Added `import /vendor/etc/init/fancontrol.rc`. |
| `device/brcm/rpi5/device.mk` | **Modified** | Added `PRODUCT_COPY_FILES` for `fancontrol.sh` and `fancontrol.rc`. |

No other files were changed (no sepolicy or Android.bp for this feature).

---

## Overview

Fan control runs as a **vendor service** started during boot. It:

- Turns the fan **on at medium speed** while the system is booting and for the first 60 seconds.
- Then switches to a **temperature-based curve** using the SoC thermal sensor.

### Temperature curve

| SoC temperature | Fan level | Approx. PWM |
|----------------|-----------|-------------|
| &lt; 45°C       | **OFF**   | 0%          |
| 45–55°C        | **LOW**   | ~25%        |
| 55–65°C        | **MEDIUM**| ~66%        |
| ≥ 65°C         | **FULL**  | 100%        |

The script reads `/sys/class/thermal/thermal_zone0/temp` (millidegrees) every 2 seconds and sets the fan speed accordingly.

---

## Where it lives in the AOSP tree

All fan-control files are under the **rpi5 device tree**:

```
aosp/device/brcm/rpi5/
├── boot/
│   └── config.txt          # No gpio-fan overlay; fan is controlled by the script
├── fancontrol.sh           # Main script (PWM / GPIO logic + temp curve)
├── fancontrol.rc           # Init service definition
├── device.mk               # Copies script and .rc into vendor image
└── ramdisk/
    └── init.rpi5.rc       # Imports fancontrol.rc
```

- **fancontrol.sh** → installed as `/vendor/bin/fancontrol.sh`
- **fancontrol.rc** → installed as `/vendor/etc/init/fancontrol.rc`
- **config.txt** → copied to the **boot** partition (no `dtoverlay=gpio-fan` to avoid conflict with the script).

---

## Device tree layout and support

The Raspberry Pi 5 device tree in this AOSP setup lives under **Broadcom (brcm)**:

| Path | Purpose |
|------|--------|
| `device/brcm/` | Top-level folder for Broadcom (RPi) devices. |
| `device/brcm/rpi5/` | RPi 5 device tree (board, init, boot, overlays, etc.). |
| `device/brcm/rpi4/` | RPi 4 device tree (same layout idea; fan control was added only for rpi5). |
| `device/brcm/rpi5/boot/` | Boot partition content: `config.txt`, kernel name, overlays. Copied into the image by `mkbootimg.mk`. |
| `device/brcm/rpi5/ramdisk/` | Init scripts and fstab: `init.rpi5.rc`, `init.rpi5.usb.rc`, `ueventd.rpi5.rc`, `fstab.rpi5`. |
| `device/brcm/rpi5/sepolicy/` | Device-specific SELinux policy. |
| `device/brcm/rpi5/device.mk` | Main device makefile: `PRODUCT_*`, `PRODUCT_COPY_FILES`, packages. |

Fan control adds files only under **`device/brcm/rpi5/`** (script, rc, and edits to config, init, device.mk). There is no separate "fan" subdirectory; the script and rc sit next to `device.mk`.

---

## Commands to find and verify fan control files

Run these from the **AOSP root** (the directory that contains `device/`, `build/`, `out/`, etc.).

### 1. List all fan-related files in the device tree

```bash
# Fan control files under rpi5
find device/brcm/rpi5 -maxdepth 1 -name '*fan*' -o -path 'device/brcm/rpi5/boot/config.txt'

# Or list the known paths explicitly
ls -la device/brcm/rpi5/fancontrol.sh device/brcm/rpi5/fancontrol.rc
ls -la device/brcm/rpi5/boot/config.txt
```

### 2. Check that the script is executable

```bash
ls -l device/brcm/rpi5/fancontrol.sh
# Should show -rwxr-xr-x (x = executable). If not: chmod +x device/brcm/rpi5/fancontrol.sh
```

### 3. Search the tree for "fancontrol" or "fan" references

```bash
# Any mention of fancontrol in device/brcm
grep -r -l fancontrol device/brcm/

# Lines that reference fan in rpi5
grep -n -r fan device/brcm/rpi5/
```

### 4. Verify device.mk copies (PRODUCT_COPY_FILES)

```bash
grep -A2 'Fan control' device/brcm/rpi5/device.mk
grep -n fancontrol device/brcm/rpi5/device.mk
```

### 5. Verify init loads fancontrol.rc

```bash
grep -n fancontrol device/brcm/rpi5/ramdisk/init.rpi5.rc
```

### 6. Verify boot config (no gpio-fan overlay)

```bash
grep -n -E 'gpio-fan|Fan' device/brcm/rpi5/boot/config.txt
# Expect comments only, no active dtoverlay=gpio-fan line
```

### 7. List full device tree structure for rpi5

```bash
find device/brcm/rpi5 -type f | sort
```

### 8. Check where boot contents are used (mkbootimg)

```bash
grep -n 'boot/' device/brcm/rpi5/mkbootimg.mk
# Confirms boot/* (including config.txt) is copied to the boot partition
```

### 9. After build: confirm fan files are in the vendor image

```bash
# From AOSP root, after building
ls -l out/target/product/rpi5/vendor/bin/fancontrol.sh
ls -l out/target/product/rpi5/vendor/etc/init/fancontrol.rc
```

### 10. On device (via ADB): confirm installed paths

```bash
adb shell "ls -l /vendor/bin/fancontrol.sh /vendor/etc/init/fancontrol.rc"
adb shell "cat /vendor/etc/init/fancontrol.rc"
```

Use these commands to confirm that fan control is present in the device tree, that the build includes it, and that the running image has the expected files.

---

## Hardware / kernel requirements

The script tries, in order:

1. **hwmon PWM** – `/sys/class/hwmon/hwmon*/pwm1` (if the kernel exposes a pwm-fan or similar).
2. **pwmchip0** – `/sys/class/pwm/pwmchip0/pwm0` (GPIO 12 = PWM0 on RPi). If present, the script exports PWM0, sets period, and drives duty cycle.
3. **GPIO 12** – `/sys/class/gpio/gpio12` as fallback: **on/off only** (no speed levels). Fan on when temp ≥ 45°C, off below.

If **none** of these exist (kernel does not expose PWM or GPIO 12 to userspace), the script exits and does nothing. In that case you can use a **kernel overlay** in `config.txt` for simple on/off (see "Fallback: kernel overlay" below).

**Wiring:** Typical 5 V PWM fan: 5 V and GND for power; PWM (control) to **GPIO 12** (Pin 32) if using PWM. For a two-wire 5 V fan, connect 5 V and GND only; the script can still use GPIO 12 to switch a transistor/MOSFET for on/off.

---

## Build and flash

From the AOSP root (e.g. `aosp/`):

```bash
. build/envsetup.sh
lunch aosp_rpi5-ap4a-userdebug
make bootimage systemimage vendorimage -j$(nproc)
./device/brcm/rpi5/rpi5-mkimg.sh   # or ./rpi5-mkimg.sh if run from device dir
```

Flash the resulting image (e.g. `out/target/product/rpi5/*.img`) to SD card or USB and boot the device.

---

## Verify after boot

1. **Service running**
   ```bash
   adb shell ps -A | grep fancontrol
   ```
   You should see a process running `/vendor/bin/fancontrol.sh`.

2. **Temperature** (optional)
   ```bash
   adb shell cat /sys/class/thermal/thermal_zone0/temp
   ```
   Value is in millidegrees (e.g. `45000` = 45°C).

3. **PWM/GPIO** (optional, if you know your kernel exposes them)
   ```bash
   adb shell "ls -la /sys/class/pwm/pwmchip0/"
   adb shell "ls -la /sys/class/gpio/"
   ```

---

## Customization

### Change temperature thresholds or speeds

Edit **`device/brcm/rpi5/fancontrol.sh`**:

- Function **`speed_from_temp`**: adjust the millidegree values (`45000`, `55000`, `65000`) and the echo values (`0`, `64`, `170`, `255`) for OFF / LOW / MEDIUM / FULL.
- **Boot phase**: the initial `set_speed 170` and `sleep 60` control the "fan on during boot" behavior; change `170` or the sleep time as needed.

Then rebuild **vendor** (at least `vendorimage`) and reflash.

### Fallback: kernel overlay (on/off only)

If the script cannot use PWM or GPIO (no suitable sysfs), you can use the kernel's built-in fan control for simple on/off.

In **`device/brcm/rpi5/boot/config.txt`**, add:

```
dtoverlay=gpio-fan,gpiopin=12,temp=55000
```

Remove or comment out that line if you use the script, to avoid two controllers driving the same pin.

---

## Troubleshooting

| Symptom | What to check |
|--------|----------------|
| Fan never spins | Kernel may not expose PWM or GPIO 12. Run `adb shell ls /sys/class/pwm /sys/class/gpio` and see "Hardware / kernel requirements" above. Consider kernel overlay fallback. |
| Fan always full speed | Script may be using GPIO fallback (on/off only) or PWM path that only supports full on. Check `ps` and sysfs paths. |
| Service not in process list | Init may not be loading `fancontrol.rc`. Ensure `import /vendor/etc/init/fancontrol.rc` is in `ramdisk/init.rpi5.rc` and that `device.mk` copies `fancontrol.rc` to `vendor/etc/init/`. Rebuild vendor and reflash. |
| Permission denied on sysfs | SELinux may be blocking access. Check `adb logcat` for avc denials; add allow rules in device sepolicy if needed. |

---

## Summary

- **Location in AOSP:** `device/brcm/rpi5/` (fancontrol.sh, fancontrol.rc, device.mk, init.rpi5.rc, boot/config.txt).
- **Behavior:** Fan on at medium during boot; then OFF / LOW / MEDIUM / FULL by temperature (&lt; 45°C / 45–55°C / 55–65°C / ≥ 65°C).
- **Build:** Standard AOSP build + `rpi5-mkimg.sh`; flash the new image.
- **Check:** `adb shell ps -A | grep fancontrol` and thermal/pwm/gpio sysfs as above.

For more on the device tree and image creation, see the Raspberry Vanilla Android and kernel documentation.
