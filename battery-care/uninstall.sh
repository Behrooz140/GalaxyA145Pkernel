#!/system/bin/sh
# Battery Care - restore normal charging when the module is removed.
SYS=/sys/class/power_supply/battery/batt_full_capacity
if [ -e "$SYS" ]; then
    echo "100" > "$SYS"
fi
exit 0
