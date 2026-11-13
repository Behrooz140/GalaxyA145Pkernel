#!/system/bin/sh
# A145P Tuner - KernelSU uninstall
#
# All tunables are runtime-only; reboot (or the next boot) restores the
# kernel defaults. Remove the data directory for a clean uninstall.

rm -rf /data/adb/a145p-tuner
exit 0
