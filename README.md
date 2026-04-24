# Kernel-GKI-12-5.10-release

GitHub Actions workflow for building a Xiaomi SM8450 Android 12 / 5.10 kernel
for NetHunter experiments.

The workflow intentionally builds from the device-specific
`xiaomi-sm8450-kernel/manifest` instead of plain upstream AOSP GKI. Xiaomi 12
Pro (`zeus`) needs the vendor kernel tree, Qualcomm external modules, and the
device-tree outputs. A bare `Image` from `android.googlesource.com/kernel/common`
can compile, but it is not enough to be a safe boot artifact for this device.

## Run

### Xiaomi OSS experimental workflow

1. Open the repository on GitHub.
2. Go to `Actions`.
3. Select `Build Xiaomi SM8450 NetHunter Kernel`.
4. Click `Run workflow`.
5. Keep `device=zeus` for Xiaomi 12 Pro, or choose `cupid` for Xiaomi 12.
6. Use `lto=none` for the first CI builds. Try `thin` later if the build is
   stable enough.
7. Use `profile=nethunter` for the NetHunter-oriented kernel options, or
   `profile=kvm` for a smaller virtualization/virtio-only test build.

### Lineage-matched workflow

Use `Build Lineage-Matched Zeus Kernel` for LineageOS 23.2 on Xiaomi 12 Pro
(`zeus`). This workflow is the safer path after the Xiaomi OSS kernel bootloop:
it clones `LineageOS/android_kernel_xiaomi_sm8450` branch `lineage-23.2`, starts
from the stock `LineageOS 23.2-20260414-NIGHTLY-zeus` `/proc/config.gz`, and
packages only a boot-image AnyKernel3 ZIP.

Start with `profile=baseline`. Do not flash `kvm-lite` or `nethunter-lite` until
the baseline ZIP boots and ADB comes online.

Use `toolchain=android-r563880c` and `lto_mode=thin` for the verified GitHub
Actions baseline. It booted on the test `zeus` device on slot `_b` while keeping
the stock Lineage source commit, config, compiler family, CFI, and boot-image
kernel format. `lto_mode=stock-full` is the closest config match, but GitHub's
hosted runner killed the full-LTO link with exit `143`; use it only on a larger
or local runner.

## Output

The Lineage-matched workflow uploads the flashable artifact as:

- `${kernel_name}-${device}-${profile}-${toolchain}-${lto_mode}-lineage-anykernel3.zip`

This is a kernel-only AnyKernel3 package for LineageOS. It patches the currently
installed Lineage `boot` partition and preserves the Lineage ramdisk.

It also uploads a diagnostic artifact:

- `${kernel_name}-${device}-${profile}-${toolchain}-${lto_mode}-diagnostic.zip`

It contains the collected build outputs and `MANIFEST.txt` for debugging. It is
not intended to be flashed directly.

For `zeus`, the Lineage stock `boot` image stores the kernel as an uncompressed
ARM64 `Image`, not `Image.lz4`, so the Lineage-matched AnyKernel3 package also
flashes `Image`.

The workflow fails before packaging when it cannot find:

- kernel `Image` or `Image.lz4`
- device-tree output: `*.dtb`, `*.dtbo`, or `dtbo.img`
- vendor modules: `*.ko`, `vendor_dlkm.img`, or `vendor_dlkm.modules.load`
- key NetHunter options such as `CONFIG_NET_NS`, HID configfs, `CFG80211`, and
  `MAC80211`

`CONFIG_USER_NS` and `CONFIG_PID_NS` are requested for the NetHunter profile,
but this Xiaomi vendor tree may still reject them during the final config merge.
The workflow warns instead of blocking the Lineage flashable ZIP when that
happens.

The Xiaomi vendor tree may keep `CFG80211` and `MAC80211` as modules (`=m`)
instead of built-ins (`=y`). The workflow accepts both forms and uploads a
diagnostic artifact with `vendor_dlkm` outputs, while the Lineage AnyKernel3 ZIP
remains boot-image-only and preserves the installed Lineage ramdisk.

The workflow disables strict GKI KMI symbol-list enforcement during CI. This is
intentional for the Lineage/NetHunter experiment: `lto=none` disables CFI, while
the upstream Android 12 GKI symbol list still expects CFI symbols such as
`__cfi_slowpath`.

The workflow also removes the generated `-Wframe-larger-than` compiler flag
because Xiaomi touchscreen drivers can emit large stack-frame warnings that
Android's kernel build treats as forbidden warnings.

The `kvm` profile requests the core ARM64 KVM, virtio, vhost, TUN, and
virtio-fs options. A successful build only proves the kernel accepted those
options and produced a Lineage boot-image package; actual VM support still
depends on the device firmware, EL2 availability, device tree, and the installed
Lineage userspace.

For the `kvm` profile, `CONFIG_KVM`, `CONFIG_VIRTIO`, and `CONFIG_TUN` are
treated as required. Specific virtio transport/device drivers are warnings
because this vendor tree may reject them during the final config merge; without
virtio net/block support, practical guest I/O can be limited even if the kernel
boot image flashes successfully.

## Lineage 23.2 baseline notes

The checked-in baseline config is stored at:

- `configs/zeus-lineage-23.2-20260414.config`

It was extracted from the currently booting LineageOS 23.2 build on `zeus`. The
Lineage-matched workflow fails if the build drifts too far from that config, if
the kernel is not `5.10.252`, or if Clang is not version 21-class. This follows
the XDA lesson from tested custom kernels: match ROM generation, source tree,
compiler family, and config before adding KernelSU, NetHunter, or virtualization
patches.

The stock phone config uses Android clang build `14054515` from
`git_llvm-r563880-release` and full LTO/CFI. The boot-verified CI baseline keeps
that exact compiler and CFI, but switches full LTO to ThinLTO. A previous ZyC
Clang 21 plus ThinLTO fallback produced a valid ZIP after packaging fixes, but
the phone still fell back to fastboot before userspace, so it is not considered
bootable.
