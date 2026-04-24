# Kernel-GKI-12-5.10-release

GitHub Actions workflow for building a Xiaomi SM8450 Android 12 / 5.10 kernel
for NetHunter experiments.

The workflow intentionally builds from the device-specific
`xiaomi-sm8450-kernel/manifest` instead of plain upstream AOSP GKI. Xiaomi 12
Pro (`zeus`) needs the vendor kernel tree, Qualcomm external modules, and the
device-tree outputs. A bare `Image` from `android.googlesource.com/kernel/common`
can compile, but it is not enough to be a safe boot artifact for this device.

## Run

1. Open the repository on GitHub.
2. Go to `Actions`.
3. Select `Build Xiaomi SM8450 NetHunter Kernel`.
4. Click `Run workflow`.
5. Keep `device=zeus` for Xiaomi 12 Pro, or choose `cupid` for Xiaomi 12.
6. Use `lto=none` for the first CI builds. Try `thin` later if the build is
   stable enough.

## Output

The artifact is a ZIP with the collected build outputs and `MANIFEST.txt`.
It is not treated as a ready-to-flash AnyKernel package unless all required
pieces are present.

The workflow fails before packaging when it cannot find:

- kernel `Image` or `Image.lz4`
- device-tree output: `*.dtb`, `*.dtbo`, or `dtbo.img`
- vendor modules: `*.ko`, `vendor_dlkm.img`, or `vendor_dlkm.modules.load`
- key NetHunter options such as `CONFIG_USER_NS`, `CONFIG_NET_NS`, HID configfs,
  `CFG80211`, and `MAC80211`
