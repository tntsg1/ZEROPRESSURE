#!/usr/bin/env python3
# List what a Godot 4 export really carries: the .pck, or an .exe with the pck embedded.
#   python -X utf8 tools/pck_list.py build/playtest/ZeroPressure_Playtest.exe [substring]
import struct
import sys


def entries(path):
    with open(path, "rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(0)
        base = 0
        if f.read(4) != b"GDPC":
            # embedded: ... pck ... [u64 pck size] [GDPC]
            f.seek(size - 4)
            if f.read(4) != b"GDPC":
                raise SystemExit("no pck in " + path)
            f.seek(size - 12)
            pck = struct.unpack("<Q", f.read(8))[0]
            base = size - 12 - pck
            f.seek(base)
            if f.read(4) != b"GDPC":
                raise SystemExit("embedded pck not found")
        ver, major, minor, patch = struct.unpack("<4I", f.read(16))
        flags = struct.unpack("<I", f.read(4))[0]
        if flags & 1:
            raise SystemExit("the directory is encrypted")
        struct.unpack("<Q", f.read(8))          # file base
        if ver >= 3:
            d = struct.unpack("<Q", f.read(8))[0]
            f.seek(base + d)
        else:
            f.read(64)
        n = struct.unpack("<I", f.read(4))[0]
        out = []
        for _ in range(n):
            ln = struct.unpack("<I", f.read(4))[0]
            name = f.read(ln).rstrip(b"\0").decode("utf8")
            _off, sz = struct.unpack("<QQ", f.read(16))
            f.read(16)                          # md5
            f.read(4)                           # flags
            out.append((name, sz))
        return out


if __name__ == "__main__":
    want = sys.argv[2] if len(sys.argv) > 2 else ""
    all_ = entries(sys.argv[1])
    shown = [e for e in all_ if want in e[0]]
    for name, sz in sorted(shown):
        print("%10d  %s" % (sz, name))
    print("%d files, %.1f MB (of %d files, %.1f MB)" % (len(shown), sum(e[1] for e in shown) / 1e6, len(all_), sum(e[1] for e in all_) / 1e6))
