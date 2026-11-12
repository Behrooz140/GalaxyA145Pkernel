#!/system/bin/sh
# Battery Care - KernelSU post-fs-data stage
# Makes the CLI available at a stable path before Android finishes booting.
MODDIR=${0%/*}
DATA=/data/adb/battery-care

mkdir -p "$DATA"
if [ -f "$MODDIR/bin/battery-care" ]; then
    cp -f "$MODDIR/bin/battery-care" "$DATA/battery-care"
    chmod 0755 "$DATA/battery-care"
fi
exit 0
