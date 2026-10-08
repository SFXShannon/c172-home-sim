#!/usr/bin/env python3
"""Convert ASCII STL files (what OpenSCAD 2021 writes) to binary STL in place.
Binary files are ~5x smaller and every slicer reads them.

    python3 scripts/stl2bin.py path/to/file.stl [more.stl ...]
"""
import struct, sys

def convert(path):
    with open(path, "rb") as f:
        head = f.read(5)
        if head != b"solid":
            return False                     # already binary
        data = head + f.read()
    words = data.decode("ascii", errors="ignore").split()
    tris, i, n = [], 0, len(words)
    while i < n:
        if words[i] == "facet":
            nx, ny, nz = map(float, words[i + 2:i + 5])
            v = []
            j = i + 5
            while len(v) < 3 and j < n:
                if words[j] == "vertex":
                    v.append(tuple(map(float, words[j + 1:j + 4])))
                    j += 4
                else:
                    j += 1
            tris.append(((nx, ny, nz), v))
            i = j
        else:
            i += 1
    with open(path, "wb") as f:
        f.write(b"binary STL from OpenSCAD".ljust(80, b" "))
        f.write(struct.pack("<I", len(tris)))
        for nrm, v in tris:
            f.write(struct.pack("<12fH", *nrm, *v[0], *v[1], *v[2], 0))
    return True

if __name__ == "__main__":
    for p in sys.argv[1:]:
        if convert(p):
            print("  binary:", p)
