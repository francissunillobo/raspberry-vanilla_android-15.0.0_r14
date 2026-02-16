# Build / compilation fixes

Place your **build-fix** patch files here. They are applied **first** (before the fan-control patch).

- **One patch per repo.** Name files after the repo path, e.g.:
  - `build_make.patch` → applied in `build/make`
  - `build_soong.patch` → applied in `build/soong`
  - `device_brcm_rpi5_build.patch` → applied in `device/brcm/rpi5`
- Add the same name and `repo_path` mapping in `apply_build_patches.sh` and `remove_build_patches.sh` in the repo root.

To generate a patch from a modified project (e.g. after fixing a build error):

```bash
cd aosp/build/make   # or the repo you changed
git diff origin/android-15.0.0_r14 -- . > /path/to/raspberry-vanilla_android-15.0.0_r14/patches/01-build-fixes/build_make.patch
```

If this folder has no `.patch` files, the apply script will skip it.
