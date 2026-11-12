#!/usr/bin/env bash
# Build a 32 MiB Samsung-compatible boot image from a gzipped kernel.
#
# Layout produced (identical to the previously working custom boot.img):
#   [ 4 KiB boot header v4 ][ gzip kernel ][ pad to 4 KiB ]
#   [ "SEANDROIDENFORCE" ][ AVB hash footer, 32 MiB partition ]
#
# The AVB footer is signed with a public AOSP test key. This is accepted by
# the bootloader on unlocked devices; it is NOT a Samsung signature.
#
# Usage:
#   MBOOTIMG=/path/mkbootimg.py AVBTOOL=/path/avbtool.py AVB_KEY=/path/key.pem \
#     ./build_boot_image.sh Image.gz boot.img
set -euo pipefail

KERNEL_GZ="${1:?usage: build_boot_image.sh <Image.gz> <output boot.img>}"
OUT_IMG="${2:?usage: build_boot_image.sh <Image.gz> <output boot.img>}"

MBOOTIMG="${MBOOTIMG:-mkbootimg}"
AVBTOOL="${AVBTOOL:-avbtool}"
AVB_KEY="${AVB_KEY:?AVB_KEY must point to a PEM signing key}"
AVB_ALGORITHM="${AVB_ALGORITHM:-SHA256_RSA4096}"
BOOT_PARTITION_SIZE="${BOOT_PARTITION_SIZE:-33554432}"
OS_VERSION="${OS_VERSION:-15.0.0}"
OS_PATCH_LEVEL="${OS_PATCH_LEVEL:-2026-07}"

PYTHON="${PYTHON:-python3}"
MBOOTIMG_DIR="$(dirname "$MBOOTIMG")"

[ -f "$KERNEL_GZ" ] || { echo "kernel image not found: $KERNEL_GZ" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> mkbootimg (header v4, os ${OS_VERSION}, patch ${OS_PATCH_LEVEL})"
"$PYTHON" "$MBOOTIMG" \
  --header_version 4 \
  --kernel "$KERNEL_GZ" \
  --os_version "$OS_VERSION" \
  --os_patch_level "$OS_PATCH_LEVEL" \
  --output "$TMP_DIR/boot.img"

echo "==> appending SEANDROIDENFORCE"
printf 'SEANDROIDENFORCE' >> "$TMP_DIR/boot.img"

echo "==> avbtool add_hash_footer (${AVB_ALGORITHM}, partition ${BOOT_PARTITION_SIZE} bytes)"
"$PYTHON" "$AVBTOOL" add_hash_footer \
  --image "$TMP_DIR/boot.img" \
  --partition_size "$BOOT_PARTITION_SIZE" \
  --partition_name boot \
  --key "$AVB_KEY" \
  --algorithm "$AVB_ALGORITHM"

ACTUAL_SIZE="$(stat -c '%s' "$TMP_DIR/boot.img")"
if [ "$ACTUAL_SIZE" != "$BOOT_PARTITION_SIZE" ]; then
  echo "ERROR: unexpected boot image size ${ACTUAL_SIZE} (want ${BOOT_PARTITION_SIZE})" >&2
  exit 1
fi

echo "==> verifying image"
"$PYTHON" "$AVBTOOL" info_image --image "$TMP_DIR/boot.img" | sed -n '1,12p'
"$PYTHON" "$MBOOTIMG_DIR/unpack_bootimg.py" --boot_img "$TMP_DIR/boot.img" 2>/dev/null || true

mkdir -p "$(dirname "$OUT_IMG")"
cp "$TMP_DIR/boot.img" "$OUT_IMG"

echo "==> wrote $OUT_IMG ($(stat -c '%s' "$OUT_IMG") bytes)"
sha256sum "$OUT_IMG"
