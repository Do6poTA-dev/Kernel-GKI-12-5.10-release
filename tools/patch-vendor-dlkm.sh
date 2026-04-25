#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  tools/patch-vendor-dlkm.sh STOCK_VENDOR_DLKM_IMG MODULES_ZIP_OR_DIR OUT_IMG [PARTITION_SIZE_BYTES]

Creates a vendor_dlkm image by copying the stock image, erasing its AVB footer,
optionally growing the ext4 filesystem to PARTITION_SIZE_BYTES, and replacing
stock /lib/modules/*.ko files with matching rebuilt modules.

The script intentionally keeps stock modules.load/modules.dep and leaves modules
without a rebuilt counterpart untouched. That makes the first probe conservative:
only same-name modules are swapped.
EOF
}

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  usage >&2
  exit 2
fi

stock_img=$1
modules_src=$2
out_img=$3
partition_size=${4:-}

for tool in debugfs resize2fs e2fsck tune2fs unzip; do
  command -v "$tool" >/dev/null || {
    echo "Missing required tool: $tool" >&2
    exit 1
  }
done

if [ ! -f "$stock_img" ]; then
  echo "Stock vendor_dlkm image not found: $stock_img" >&2
  exit 1
fi

tmp=$(mktemp -d)
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

modules_dir=$modules_src
if [ -f "$modules_src" ]; then
  unzip -q "$modules_src" -d "$tmp/modules-zip"
  modules_dir=$(find "$tmp/modules-zip" -type d -path '*/lib/modules' | head -n1)
fi

if [ -z "${modules_dir:-}" ] || [ ! -d "$modules_dir" ]; then
  echo "Could not find rebuilt lib/modules directory in: $modules_src" >&2
  exit 1
fi

mkdir -p "$(dirname "$out_img")"
cp -f "$stock_img" "$out_img"

avbtool_py="${AVBTOOL:-/mnt/e/yeus/tools/avbtool.py}"
if [ -f "$avbtool_py" ]; then
  python3 "$avbtool_py" erase_footer --image "$out_img" >/dev/null
else
  echo "Warning: AVBTOOL not found, keeping any existing footer in $out_img" >&2
fi

if [ -n "$partition_size" ]; then
  truncate -s "$partition_size" "$out_img"
  resize2fs -f "$out_img" >/dev/null
fi

debugfs -R 'ls -p /lib/modules' "$out_img" 2>/dev/null \
  | awk -F/ '$6 ~ /\.ko$/ {print $6}' \
  | sort -u > "$tmp/stock-modules.names"

find "$modules_dir" -maxdepth 1 -type f -name '*.ko' -printf '%f\n' \
  | sort -u > "$tmp/rebuilt-modules.names"

comm -12 "$tmp/stock-modules.names" "$tmp/rebuilt-modules.names" > "$tmp/replace.names"
comm -23 "$tmp/stock-modules.names" "$tmp/rebuilt-modules.names" > "$tmp/stock-only.names"
comm -13 "$tmp/stock-modules.names" "$tmp/rebuilt-modules.names" > "$tmp/rebuilt-extra.names"

cmds="$tmp/debugfs.cmds"
while IFS= read -r name; do
  ko="$modules_dir/$name"
  printf 'rm /lib/modules/%s\n' "$name" >> "$cmds"
  printf 'write %s /lib/modules/%s\n' "$ko" "$name" >> "$cmds"
  printf 'ea_set /lib/modules/%s security.selinux u:object_r:vendor_file:s0\n' "$name" >> "$cmds"
done < "$tmp/replace.names"

if [ -s "$cmds" ]; then
  debugfs -w -f "$cmds" "$out_img" >/dev/null
fi

e2fsck -fy "$out_img" >/dev/null

report="${out_img}.report"
{
  echo "stock_img=$stock_img"
  echo "modules_src=$modules_src"
  echo "out_img=$out_img"
  echo "partition_size=${partition_size:-unchanged}"
  echo "stock_modules=$(wc -l < "$tmp/stock-modules.names")"
  echo "rebuilt_modules=$(wc -l < "$tmp/rebuilt-modules.names")"
  echo "replaced_modules=$(wc -l < "$tmp/replace.names")"
  echo "stock_only_modules=$(wc -l < "$tmp/stock-only.names")"
  echo "rebuilt_extra_modules=$(wc -l < "$tmp/rebuilt-extra.names")"
  echo
  echo "[stock-only]"
  sed -n '1,200p' "$tmp/stock-only.names"
  echo
  echo "[rebuilt-extra]"
  sed -n '1,200p' "$tmp/rebuilt-extra.names"
  echo
  tune2fs -l "$out_img" | grep -E 'Filesystem volume name|Block count|Free blocks|Block size'
} > "$report"

sha256sum "$out_img" "$report"
