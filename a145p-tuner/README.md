# A145P Tuner

KernelSU module for the Galaxy A14 (SM-A145P) advanced kernel. It applies a
small set of standard, reversible runtime tunables; it does not patch the
kernel or override thermal/voltage limits.

## Install

Install `A145P-Tuner-v1.4-oc.zip` from the KernelSU manager and reboot.

The module runs after boot and applies the `balanced` profile by default.
A second apply happens 30 seconds later in case a framework service rewrites
a sysfs node.

## Usage

```sh
su -c "/data/adb/a145p-tuner/a145p-tuner status"
su -c "/data/adb/a145p-tuner/a145p-tuner profile battery"
su -c "/data/adb/a145p-tuner/a145p-tuner profile performance"
su -c "/data/adb/a145p-tuner/a145p-tuner profile balanced"
su -c "/data/adb/a145p-tuner/a145p-tuner apply"
```

The selected profile is stored in `/data/adb/a145p-tuner/config` and the
journal in `/data/adb/a145p-tuner/tuner.log`.

## Profiles

| Profile | Network | VM | Scheduler / I/O |
|---|---|---|---|
| `balanced` | BBR + fq, TCP fast open | swappiness 80, cache pressure 100 | schedutil 1000/2000 us, read-ahead 128 KiB |
| `performance` | larger TCP buffers, fast open | swappiness 60, cache pressure 50 | schedutil 500/1000 us, read-ahead 256 KiB |
| `battery` | BBR + fq, small buffers | swappiness 60, cache pressure 200, lazy writeback | schedutil 2000/4000 us, read-ahead 64 KiB |

Every write is guarded by `[ -e path ]`; unsupported nodes are skipped and
logged. All values are runtime-only. Reboot or uninstalling the module restores
the kernel defaults.
