#!/system/bin/sh
# A145P Tuner - KernelSU late_start service
#
# Waits until Android has finished booting, then applies the configured
# profile twice (some framework services rewrite sysfs tunables late).

MODDIR=${0%/*}
DATA=/data/adb/a145p-tuner
CLI="$DATA/a145p-tuner"
SVC_LOG="$DATA/service.log"

mkdir -p "$DATA"

if [ ! -x "$CLI" ] && [ -f "$MODDIR/bin/a145p-tuner" ]; then
    cp -f "$MODDIR/bin/a145p-tuner" "$CLI"
    chmod 0755 "$CLI"
fi

[ -f "$DATA/config" ] || echo "PROFILE=balanced" > "$DATA/config"
[ -x "$CLI" ] || exit 0

# Wait for boot completion, up to four minutes.
i=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$i" -lt 120 ]; do
    sleep 2
    i=$((i + 1))
done

# Let the framework settle before touching scheduler/IO tunables.
sleep 20
"$CLI" apply >> "$SVC_LOG" 2>&1 || true

sleep 30
"$CLI" apply >> "$SVC_LOG" 2>&1 || true

exit 0
