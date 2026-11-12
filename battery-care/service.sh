#!/system/bin/sh
# Battery Care - KernelSU late_start service
#
# Uses the Samsung power-supply node:
#   /sys/class/power_supply/battery/batt_full_capacity
# Accepted values:
#   "100"          -> full charge
#   "<n> OPTION"   -> stop battery charging at n% (charger stays connected)
#   "80 SLEEP"     -> stop at 80%, keep port charging
#   "80 HIGHSOC"   -> stop at 80%, cut port charging
#
# Config file: /data/adb/battery-care/config  (shell syntax)
#   LIMIT=85      (50-100, or "off")
MODDIR=${0%/*}
DATA=/data/adb/battery-care
CONF="$DATA/config"
SYS=/sys/class/power_supply/battery/batt_full_capacity
LOG="$DATA/log.txt"

mkdir -p "$DATA"

LIMIT=85
if [ -f "$CONF" ]; then
    . "$CONF"
fi
[ "${LIMIT:-85}" = "off" ] && LIMIT=100

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

log "boot: limit=${LIMIT}"

if [ ! -e "$SYS" ]; then
    log "node $SYS not found; is this an A14/A145P kernel?"
    exit 0
fi

apply() {
    if [ "$LIMIT" -ge 50 ] 2>/dev/null && [ "$LIMIT" -le 100 ] 2>/dev/null; then
        if [ "$LIMIT" -eq 100 ]; then
            echo "100" > "$SYS"
        else
            echo "$LIMIT OPTION" > "$SYS"
        fi
    else
        echo "100" > "$SYS"
    fi
}

# Wait for Android to finish booting; Samsung's framework may rewrite the node.
i=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ] && [ "$i" -lt 90 ]; do
    sleep 2
    i=$((i + 1))
done
sleep 5

# Keep re-applying for about a minute so a late framework write cannot win.
expected=1
[ "$LIMIT" -eq 100 ] && expected=0

n=0
while [ "$n" -lt 12 ]; do
    cur="$(cat "$SYS" 2>/dev/null)"
    if [ "$cur" != "$expected" ]; then
        apply
        log "attempt=$n was=$cur now=$(cat "$SYS" 2>/dev/null)"
    fi
    n=$((n + 1))
    sleep 5
done

# Copy CLI to the stable path as well (post-fs-data normally does this).
if [ -f "$MODDIR/bin/battery-care" ]; then
    cp -f "$MODDIR/bin/battery-care" "$DATA/battery-care"
    chmod 0755 "$DATA/battery-care"
fi

log "done: mode=$(cat "$SYS" 2>/dev/null) limit=${LIMIT}"
exit 0
