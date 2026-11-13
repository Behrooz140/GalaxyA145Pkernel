#!/usr/bin/env python3
"""Compare exported-symbol CRCs of a built arm64 Image against a baseline.

The kernel is built with CONFIG_MODVERSIONS=y, so every exported symbol has a
32-bit CRC stored in __kcrctab/__kcrctab_gpl.  Modules embed the CRC they were
linked against, and the loader rejects a module when the CRC differs:

    module_layout: disagrees about version of symbol module_layout

module_layout is checked for every module, so if its CRC changes, no stock
module in /vendor can be loaded and the device bootloops (this happened with
the v1.1 feature bundle).  The CRC is derived by genksyms from the types used
in the symbol signature, including the full definition of referenced structs,
therefore an innocent-looking config option can change thousands of CRCs.

Usage:
    kmi_check.py emit   --image Image --system-map System.map --output base.txt
    kmi_check.py verify --image Image --system-map System.map --baseline base.txt

Exit status: 0 = compatible, 1 = incompatible, 2 = tool/parse error.
"""

import argparse
import struct
import sys

KSYMTAB_PREFIX = "__ksymtab_"


def die(msg):
    print("kmi_check: ERROR: %s" % msg, file=sys.stderr)
    sys.exit(2)


def parse_system_map(path):
    addrs = {}
    ksymtab = []
    try:
        fh = open(path, errors="ignore")
    except OSError as exc:
        die("cannot read %s: %s" % (path, exc))
    with fh:
        for line in fh:
            parts = line.split()
            if len(parts) < 3:
                continue
            try:
                addr = int(parts[0], 16)
            except ValueError:
                continue
            name = parts[2]
            addrs.setdefault(name, addr)
            if name.startswith(KSYMTAB_PREFIX) and not name.startswith("__ksymtab_gpl_"):
                ksymtab.append((addr, name[len(KSYMTAB_PREFIX):]))
    return addrs, ksymtab


def load_image(path):
    try:
        with open(path, "rb") as fh:
            return fh.read()
    except OSError as exc:
        die("cannot read %s: %s" % (path, exc))


def collect_crcs(image_path, map_path, validate_names=False):
    addrs, ksymtab = parse_system_map(map_path)
    for key in ("_text", "__start___ksymtab_gpl", "__start___kcrctab",
                "__start___kcrctab_gpl"):
        if key not in addrs:
            die("symbol %s not found in %s" % (key, map_path))

    text = addrs["_text"]
    gpl_start = addrs["__start___ksymtab_gpl"]
    crc_start = addrs["__start___kcrctab"]
    crc_gpl = addrs["__start___kcrctab_gpl"]
    img = load_image(image_path)

    uniq = {}
    for addr, name in ksymtab:
        uniq.setdefault(addr, name)
    items = sorted(uniq.items())

    crcs = {}
    plain_idx = gpl_idx = 0
    name_mismatch = 0
    for addr, name in items:
        if addr < gpl_start:
            index = plain_idx
            plain_idx += 1
            base = crc_start
        else:
            index = gpl_idx
            gpl_idx += 1
            base = crc_gpl
        off = base + 4 * index - text
        if off < 0 or off + 4 > len(img):
            die("CRC offset 0x%x for %s is outside %s" % (off, name, image_path))
        crcs[name] = struct.unpack_from("<I", img, off)[0]

        if validate_names:
            # struct kernel_symbol is 12 bytes: value_offset, name_offset,
            # namespace_offset (each relative to its own field).
            sym_off = addr - text
            try:
                _value, name_off, _ns = struct.unpack_from("<iii", img, sym_off)
            except struct.error:
                die("ksymtab entry 0x%x for %s is outside %s" % (sym_off, name, image_path))
            str_off = addr + 4 + name_off - text
            if str_off < 0 or str_off >= len(img):
                die("name offset for %s is outside %s" % (name, image_path))
            got = img[str_off:img.find(b"\0", str_off)].decode("latin1", "replace")
            if got != name:
                name_mismatch += 1
                if name_mismatch <= 5:
                    print("kmi_check: name mismatch at 0x%x: %r != %r"
                          % (addr, got, name), file=sys.stderr)

    if validate_names and name_mismatch:
        die("%d ksymtab name mismatches - refusing to trust CRC mapping" % name_mismatch)

    return crcs


def read_baseline(path):
    crcs = {}
    try:
        fh = open(path, errors="ignore")
    except OSError as exc:
        die("cannot read baseline %s: %s" % (path, exc))
    with fh:
        for lineno, line in enumerate(fh, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 2:
                die("%s:%d: expected '<name> <crc>'" % (path, lineno))
            name, value = parts
            try:
                crcs[name] = int(value, 16)
            except ValueError:
                die("%s:%d: bad CRC %r" % (path, lineno, value))
    return crcs


def cmd_emit(args):
    crcs = collect_crcs(args.image, args.system_map, validate_names=True)
    with open(args.output, "w") as fh:
        fh.write("# Exported-symbol CRCs captured from a known-good build.\n")
        fh.write("# Format: <symbol> <crc32-hex>.  Generated by scripts/kmi_check.py emit.\n")
        for name in sorted(crcs):
            fh.write("%s %08x\n" % (name, crcs[name]))
    print("kmi_check: wrote %d CRCs to %s" % (len(crcs), args.output))
    return 0


def cmd_verify(args):
    base = read_baseline(args.baseline)
    cur = collect_crcs(args.image, args.system_map, validate_names=True)

    changed = sorted(n for n in base if n in cur and base[n] != cur[n])
    missing = sorted(n for n in base if n not in cur)
    added = sorted(n for n in cur if n not in base)

    print("kmi_check: baseline=%d symbols, built=%d symbols" % (len(base), len(cur)))
    print("kmi_check: changed=%d removed=%d new=%d"
          % (len(changed), len(missing), len(added)))

    if "module_layout" in cur:
        expected = base.get("module_layout")
        print("kmi_check: module_layout=0x%08x (baseline %s)"
              % (cur["module_layout"],
                 "0x%08x" % expected if expected is not None else "absent"))

    if changed:
        print("\nkmi_check: ABI BREAK - exported symbol CRCs differ from baseline:")
        for name in changed[:40]:
            print("  %-46s 0x%08x -> 0x%08x" % (name, base[name], cur[name]))
        if len(changed) > 40:
            print("  ... and %d more" % (len(changed) - 40))
    if missing:
        print("\nkmi_check: ABI BREAK - exported symbols present in baseline are gone:")
        for name in missing[:40]:
            print("  %s" % name)
        if len(missing) > 40:
            print("  ... and %d more" % (len(missing) - 40))

    if changed or missing:
        print("\nkmi_check: FAIL - stock /vendor modules would be rejected at load time.")
        return 1

    print("kmi_check: PASS - every exported symbol matches the known-good baseline.")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    emit = sub.add_parser("emit", help="write a baseline from a known-good Image")
    emit.add_argument("--image", required=True)
    emit.add_argument("--system-map", required=True)
    emit.add_argument("--output", required=True)
    emit.set_defaults(func=cmd_emit)

    verify = sub.add_parser("verify", help="verify an Image against a baseline")
    verify.add_argument("--image", required=True)
    verify.add_argument("--system-map", required=True)
    verify.add_argument("--baseline", required=True)
    verify.set_defaults(func=cmd_verify)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
