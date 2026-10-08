#!/usr/bin/env python3
"""Write CNC router files for the G1000 dashboard panel (cut from 1/4" sheet).

For each piece it writes, in panel/dashboard/cnc/:
  <piece>.dxf / <piece>.svg            front side, one layer per operation:
      CUT          outline + openings, routed through (outside / inside profiles)
      DRILL        small through holes (circles) - drill or peck these
      ENGRAVE      labels, 0.6 mm deep with a V-bit
      COUNTERSINK  M3 countersinks: circles of the head diameter, 90 deg V-bit
  <piece>_back.dxf / .svg              blind pilot holes, mirrored left-right, for
                                       drilling from the back after flipping the piece

Each piece sits with its lower-left corner at 0,0, front view, units mm.

    python3 scripts/make_cnc.py
"""
import os, re, subprocess, tempfile
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAD = os.path.join(ROOT, "panel", "g1000_dashboard.scad")
OUT = os.path.join(ROOT, "panel", "dashboard", "cnc")
PIECES = ["lower_1", "lower_2", "upper_1", "upper_2", "pedestal_face", "pedestal_floor", "splice"]
FRONT = ["cut", "drill", "engrave", "countersink"]
COLORS = {"cut": ("CUT", 7, "#000000"), "drill": ("DRILL", 1, "#d0021b"),
          "engrave": ("ENGRAVE", 5, "#1f5fd6"), "countersink": ("COUNTERSINK", 3, "#2a9d3a"),
          "back": ("BACK_PILOTS", 6, "#9b30c8")}


def run(piece, layer, tmp):
    out = os.path.join(tmp, f"{piece}_{layer}.svg")
    subprocess.run(["openscad", "-q", "-D", f'part="cnc_{piece}"', "-D", f'cnc_layer="{layer}"',
                    "-o", out, SCAD], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return (piece, layer, out if os.path.exists(out) else None)


def loops(svg_path):
    """Closed polygons from an OpenSCAD SVG (M/L/z paths, y flipped back to up)."""
    if not svg_path:
        return []
    d = " ".join(re.findall(r'd="([^"]*)"', open(svg_path).read()))
    res = []
    for sub in re.split(r"[Mm]", d)[1:]:
        pts = [(float(x), -float(y)) for x, y in re.findall(r"(-?[\d.e+-]+),(-?[\d.e+-]+)", sub)]
        if len(pts) > 2:
            res.append(pts)
    return res


def as_circle(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    if abs(w - h) < 0.3 and len(pts) >= 8:
        return ((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, (w + h) / 4)
    return None


def dxf(path, layers):
    """layers: list of (name, color, [loops], circles?)"""
    L = ["0", "SECTION", "2", "HEADER", "9", "$ACADVER", "1", "AC1009", "9", "$INSUNITS", "70", "4",
         "0", "ENDSEC", "0", "SECTION", "2", "TABLES", "0", "TABLE", "2", "LAYER", "70", str(len(layers))]
    for name, col, _, _ in layers:
        L += ["0", "LAYER", "2", name, "70", "0", "62", str(col), "6", "CONTINUOUS"]
    L += ["0", "ENDTAB", "0", "ENDSEC", "0", "SECTION", "2", "ENTITIES"]
    for name, col, lps, circ in layers:
        for pts in lps:
            c = as_circle(pts) if circ else None
            if c:
                L += ["0", "CIRCLE", "8", name, "10", f"{c[0]:.4f}", "20", f"{c[1]:.4f}", "30", "0", "40", f"{c[2]:.4f}"]
                continue
            L += ["0", "POLYLINE", "8", name, "66", "1", "10", "0", "20", "0", "30", "0", "70", "1"]
            for x, y in pts:
                L += ["0", "VERTEX", "8", name, "10", f"{x:.4f}", "20", f"{y:.4f}", "30", "0"]
            L += ["0", "SEQEND", "8", name]
    L += ["0", "ENDSEC", "0", "EOF"]
    open(path, "w").write("\n".join(L) + "\n")


def svg(path, layers, W, H):
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" '
         f'width="{W:.3f}mm" height="{H:.3f}mm" viewBox="0 0 {W:.3f} {H:.3f}">']
    for name, _, lps, circ, color in layers:
        s.append(f'<g id="{name}" inkscape:groupmode="layer" inkscape:label="{name}" fill="none" stroke="{color}" stroke-width="0.2">')
        for pts in lps:
            c = as_circle(pts) if circ else None
            if c:
                s.append(f'<circle cx="{c[0]:.4f}" cy="{H - c[1]:.4f}" r="{c[2]:.4f}"/>')
            else:
                s.append('<path d="M ' + " L ".join(f"{x:.4f},{H - y:.4f}" for x, y in pts) + ' Z"/>')
        s.append("</g>")
    s.append("</svg>")
    open(path, "w").write("\n".join(s) + "\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    jobs = [(p, l) for p in PIECES for l in FRONT + ["back"]]
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 2) as ex:
        got = {(p, l): f for p, l, f in ex.map(lambda j: run(*j, tmp), jobs)}
    for p in PIECES:
        cut = loops(got[(p, "cut")])
        xs = [x for lp in cut for x, _ in lp]; ys = [y for lp in cut for _, y in lp]
        W, H = max(xs), max(ys)
        front = [(COLORS[l][0], COLORS[l][1], loops(got[(p, l)]), l in ("drill", "countersink"), COLORS[l][2]) for l in FRONT]
        front = [f for f in front if f[2]]
        dxf(os.path.join(OUT, f"{p}.dxf"), [f[:4] for f in front])
        svg(os.path.join(OUT, f"{p}.svg"), front, W, H)
        back = [[(x + W, y) for x, y in lp] for lp in loops(got[(p, "back")])]   # scad mirrors about x = 0
        for ext in ("dxf", "svg"):
            f = os.path.join(OUT, f"{p}_back.{ext}")
            if os.path.exists(f):
                os.remove(f)
        if back:
            name, col, color = COLORS["back"]
            # the outline too, mirrored, so the back job lines up with the flipped piece
            outline = [[(W - x, y) for x, y in max(cut, key=lambda lp: (max(x for x, _ in lp) - min(x for x, _ in lp)) * (max(y for _, y in lp) - min(y for _, y in lp)))]] if cut else []
            lay = [("OUTLINE", 7, outline, False, "#000000"), (name, col, back, True, color)]
            dxf(os.path.join(OUT, f"{p}_back.dxf"), [l[:4] for l in lay])
            svg(os.path.join(OUT, f"{p}_back.svg"), lay, W, H)
        print(f"  cnc/{p}  {W:.0f} x {H:.0f} mm  " + ", ".join(f"{f[0]} {len(f[2])}" for f in front)
              + (f", BACK {len(back)}" if back else ""))


if __name__ == "__main__":
    main()
