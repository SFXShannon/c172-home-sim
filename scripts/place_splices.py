#!/usr/bin/env python3
"""Find room for splice plates on the back of the G1000 dashboard.

Splice plates join the panel pieces from behind: each one straddles a seam and
screws into blind pilot holes in the pieces on both sides. This script reads the
dashboard layout from panel/g1000_dashboard.scad, works out where a plate fits
without hitting anything mounted behind the panel (bezels, screen cradles,
control housings, the glareshield tabs ...), and writes panel/splices.scad.

Run it after moving controls or changing the seams, then re-render:

    python3 scripts/place_splices.py
    scripts/render.sh dashboard

It does it twice: for the printed tiles and for the CNC-cut pieces.
Needs OpenSCAD and shapely (pip install shapely).
"""
import ast, math, os, re, subprocess, tempfile
from shapely.geometry import Polygon, box, Point
from shapely.ops import unary_union

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAD = os.path.join(ROOT, "panel", "g1000_dashboard.scad")
OUT = os.path.join(ROOT, "panel", "splices.scad")

# plate size (x, y) and screw holes, as in g1000_dashboard.scad
SIZE = {"V": (34, 70), "H": (70, 34), "v": (40, 22), "h": (22, 40)}
HOLES = {"V": [(-10, -25), (10, -25), (-10, 25), (10, 25)], "H": [(-25, -10), (-25, 10), (25, -10), (25, 10)],
         "v": [(-12, 0), (12, 0)], "h": [(0, -12), (0, 12)]}
EDGE = 2.5          # plate stays this far inside the panel outline
SPACING = 140       # aim for a plate about this often along a long joint


def openscad(part, suffix):
    out = os.path.join(tempfile.mkdtemp(), "x." + suffix)
    quiet = [] if suffix == "csg" else ["-q"]
    r = subprocess.run(["openscad", *quiet, "-D", f'part="{part}"', "-o", out, SCAD],
                       capture_output=True, text=True)
    return out, r.stdout + r.stderr


def polys(svg):
    d = " ".join(re.findall(r'd="([^"]*)"', open(svg).read()))
    rings = []
    for sub in re.split(r"[Mm]", d)[1:]:
        pts = [(float(x), -float(y)) for x, y in re.findall(r"(-?[\d.e+-]+),(-?[\d.e+-]+)", sub)]
        if len(pts) > 2:
            rings.append(Polygon(pts).buffer(0))
    # even-odd: a ring inside another is a hole
    out = None
    for r in sorted(rings, key=lambda p: -p.area):
        out = r if out is None else (out.difference(r) if out.contains(r) else out.union(r))
    return out


def plate(kind, x, y):
    w, h = SIZE[kind]
    return box(x - w / 2, y - h / 2, x + w / 2, y + h / 2)


def place(seg, kind_big, kind_small, free, placed, n_target):
    """seg: ('v', x, y0, y1) or ('h', y, x0, x1). Spread n_target plates along it,
    each a full-size plate where it fits, otherwise a small one. Returns [(x, y, kind)]."""
    axis, c, a0, a1 = seg
    feasible = {}
    for kind in (kind_big, kind_small):
        w, h = SIZE[kind]
        half = (h if axis == "v" else w) / 2
        ok = []
        for i in range(int(a1 - a0 - 2 * half - 2 * EDGE) + 1):
            t = a0 + half + EDGE + i
            x, y = (c, t) if axis == "v" else (t, c)
            if free.contains(plate(kind, x, y)):
                ok.append(t)
        feasible[kind] = ok
    res = []
    L = a1 - a0
    for k in range(n_target):
        tg = a0 + L * (k + 0.5) / n_target
        for kind in (kind_big, kind_small):
            best = None
            for t in sorted(feasible[kind], key=lambda t: abs(t - tg)):
                if abs(t - tg) > L / n_target / 2 + 40:
                    break
                x, y = (c, t) if axis == "v" else (t, c)
                p = plate(kind, x, y)
                if not any(p.buffer(6).intersects(q) for q in placed):
                    best = (x, y, kind, p)
                    break
            if best:
                placed.append(best[3])
                res.append(best[:3])
                break
    return res


def main():
    _, log = openscad("seam_info", "csg")
    m = re.search(r'SEAMS=(\[.*\])"', log)
    (xl, xr, low, mid, top), ls, ms, us, cl, cu = ast.literal_eval(m.group(1))
    outline = polys(openscad("outline_2d", "svg")[0])
    keep = polys(openscad("keepout_2d", "svg")[0])
    inside = outline.buffer(-EDGE)

    def run(segments, seams_v):
        free = inside.difference(keep)
        placed, out, report = [], [], []
        for seg in segments:
            axis, c, a0, a1 = seg
            if axis == "h":
                # keep horizontal-joint plates clear of the vertical seams that meet the joint
                f = free
                for sx in seams_v:
                    f = f.difference(box(sx - 3, c - 30, sx + 3, c + 30))
                got = place(seg, "H", "h", f, placed, max(1, round((a1 - a0) / SPACING)))
            else:
                got = place(seg, "V", "v", free, placed, max(1, round((a1 - a0) / 110)))
            out += got
            report.append((seg, got))
        return out, report

    # printed tiles: vertical seams per row, two horizontal joints
    segs = [("v", s, 0, low) for s in ls] + [("v", s, low, mid) for s in ms] + \
           [("v", s, mid, top + 10) for s in us] + [("h", low, xl, xr), ("h", mid, xl, xr)]
    tiles, rep_t = run(segs, ls + ms + us)
    # CNC pieces: lower seam, stepped upper seam, one horizontal joint
    csegs = [("v", cl, 0, low)]
    if cu[0] == cu[1]:
        csegs.append(("v", cu[0], low, top + 10))
    else:
        csegs += [("v", cu[0], low, cu[2]), ("v", cu[1], cu[2], top + 10)]
    csegs.append(("h", low, xl, xr))
    cnc, rep_c = run(csegs, [cl, cu[0], cu[1]])

    fmt = lambda lst: "[" + ", ".join(f'[{x:g}, {y:g}, "{k}"]' for x, y, k in lst) + "]"
    open(OUT, "w").write(
        "// Written by scripts/place_splices.py - re-run it after moving things or changing the seams.\n"
        f"splices = {fmt(tiles)};\ncnc_splices = {fmt(cnc)};\n")

    for name, rep in (("Printed tiles", rep_t), ("CNC pieces", rep_c)):
        print(name + ":")
        for (axis, c, a0, a1), got in rep:
            where = f"seam x={c:g}, y {a0:g}..{a1:g}" if axis == "v" else f"joint y={c:g}"
            kinds = ", ".join(f"{k} at ({x:g}, {y:g})" for x, y, k in got) or "none - no room (a bezel or gauge must tie it)"
            print(f"  {where}: {kinds}")
        lst = tiles if name.startswith("Printed") else cnc
        big = sum(1 for _, _, k in lst if k in "VH"); small = len(lst) - big
        print(f"  -> {big} splice + {small} splice_small")


if __name__ == "__main__":
    main()
