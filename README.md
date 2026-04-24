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

The main artifact is:

- `${kernel_name}-${device}-lineage-anykernel3.zip`

This is a kernel-only AnyKernel3 package for LineageOS. It patches the currently
installed Lineage `boot` partition and preserves the Lineage ramdisk.

A second diagnostic artifact is also uploaded:

- `${kernel_name}-${device}-diagnostic.zip`

It contains the collected build outputs and `MANIFEST.txt` for debugging. It is
not intended to be flashed directly.

The workflow fails before packaging when it cannot find:

- kernel `Image` or `Image.lz4`
- device-tree output: `*.dtb`, `*.dtbo`, or `dtbo.img`
- vendor modules: `*.ko`, `vendor_dlkm.img`, or `vendor_dlkm.modules.load`
- key NetHunter options such as `CONFIG_USER_NS`, `CONFIG_NET_NS`, HID configfs,
  `CFG80211`, and `MAC80211`

For the Lineage flashable ZIP, `CFG80211` and `MAC80211` are requested as
built-ins (`=y`) so the boot-only package does not depend on replacing
Lineage's `vendor_dlkm` modules.

The workflow disables strict GKI KMI symbol-list enforcement during CI. This is
intentional for the Lineage/NetHunter experiment: `lto=none` disables CFI, while
the upstream Android 12 GKI symbol list still expects CFI symbols such as
`__cfi_slowpath`.

The workflow also suppresses `-Wframe-larger-than` because Xiaomi touchscreen
drivers can emit large stack-frame warnings that Android's kernel build treats
as forbidden warnings.
