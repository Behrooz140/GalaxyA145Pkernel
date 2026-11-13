#!/system/bin/sh
# A145P Tuner - KernelSU post-fs-data
#
# Installs the CLI at a stable path and makes sure a default profile exists.
# No tuning is applied here; late boot is handled by service.sh.

MODDIR=${0%/*}
DATA=/data/adb/a145p-tuner

mkdir -p "$DATA"

if [ -f "$MODDIR/bin/a145p-tuner" ]; then
    cp -f "$MODDIR/bin/a145p-tuner" "$DATA/a145p-tuner"
    chmod 0755 "$DATA/a145p-tuner"
fi

[ -f "$DATA/config" ] || echo "PROFILE=balanced" > "$DATA/config"

exit 0
