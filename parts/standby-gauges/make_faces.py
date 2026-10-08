#!/usr/bin/env python3
"""Draw printable faces for the standby instruments (SVG, real size in mm).

Print them at 100 % (no "fit to page") on photo paper, cut round, glue to the
printed face disc.  Markings follow the C172S: airspeed arcs in knots.

    python3 make_faces.py      ->  faces/airspeed.svg, attitude.svg, altimeter.svg
"""
import math, os

D = 76.0            # face diameter, mm
R = D / 2
C = R               # centre
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "faces")
FONT = "font-family='Arial Narrow, Liberation Sans Narrow, Arial, sans-serif' font-weight='bold'"

def svg(body, title):
    return (f"<svg xmlns='http://www.w3.org/2000/svg' width='{D}mm' height='{D}mm' viewBox='0 0 {D} {D}'>\n"
            f"<title>{title}</title>\n<circle cx='{C}' cy='{C}' r='{R}' fill='#0b0b0b'/>\n{body}\n"
            f"<circle cx='{C}' cy='{C}' r='{R - 0.2}' fill='none' stroke='#555' stroke-width='0.3'/>\n</svg>\n")

def pol(r, deg):     # 0 deg = 12 o'clock, clockwise
    a = math.radians(deg)
    return C + r * math.sin(a), C - r * math.cos(a)

def tick(r1, r2, deg, w=0.5, col="#fff"):
    x1, y1 = pol(r1, deg); x2, y2 = pol(r2, deg)
    return f"<line x1='{x1:.2f}' y1='{y1:.2f}' x2='{x2:.2f}' y2='{y2:.2f}' stroke='{col}' stroke-width='{w}'/>"

def arc(r, d0, d1, w, col):
    x0, y0 = pol(r, d0); x1, y1 = pol(r, d1)
    large = 1 if (d1 - d0) % 360 > 180 else 0
    return f"<path d='M{x0:.2f},{y0:.2f} A{r},{r} 0 {large} 1 {x1:.2f},{y1:.2f}' fill='none' stroke='{col}' stroke-width='{w}'/>"

def text(x, y, s, size, col="#fff", anchor="middle", rot=0):
    tr = f" transform='rotate({rot} {x:.2f} {y:.2f})'" if rot else ""
    return f"<text x='{x:.2f}' y='{y:.2f}' font-size='{size}' fill='{col}' text-anchor='{anchor}' dominant-baseline='middle' {FONT}{tr}>{s}</text>"

# ------------------------------------------------------------------ airspeed
def airspeed():
    lo, hi, a0, a1 = 40, 200, -150, 150
    ang = lambda v: a0 + (v - lo) / (hi - lo) * (a1 - a0)
    b = []
    b.append(arc(R - 6.6, ang(40), ang(85), 2.0, "#fff"))        # flap range (inner)
    b.append(arc(R - 4.4, ang(48), ang(129), 2.0, "#1fa33a"))    # normal (outer)
    b.append(arc(R - 4.4, ang(129), ang(163), 2.0, "#f2c200"))   # caution
    b.append(tick(R - 8, R - 2.5, ang(163), 1.1, "#e01b1b"))     # Vne
    for v in range(40, 201, 5):
        big = v % 10 == 0
        b.append(tick(R - (6 if big else 4), R - 1.2, ang(v), 0.6 if big else 0.35))
    for v in range(40, 201, 20):
        x, y = pol(R - 12.5, ang(v))
        b.append(text(x, y, v, 5.2))
    b.append(text(C, C - 10, "AIRSPEED", 3.4, "#ddd"))
    b.append(text(C, C + 11, "KNOTS", 3.0, "#ddd"))
    x, y = pol(R - 16, ang(95))
    b.append(f"<line x1='{C}' y1='{C}' x2='{x:.2f}' y2='{y:.2f}' stroke='#fff' stroke-width='1.6' stroke-linecap='round'/>")
    b.append(f"<circle cx='{C}' cy='{C}' r='2.2' fill='#333'/>")
    return svg("\n".join(map(str, b)), "Standby airspeed")

# ------------------------------------------------------------------ attitude
def attitude():
    b = [f"<clipPath id='c'><circle cx='{C}' cy='{C}' r='{R - 3}'/></clipPath>",
         f"<g clip-path='url(#c)'>",
         f"<rect x='0' y='0' width='{D}' height='{C}' fill='#2f74d0'/>",
         f"<rect x='0' y='{C}' width='{D}' height='{C}' fill='#8a5a2b'/>",
         f"<line x1='0' y1='{C}' x2='{D}' y2='{C}' stroke='#fff' stroke-width='0.8'/>"]
    for p in (5, 10, 15, 20):
        dy = p * 1.1
        w = 9 if p % 10 == 0 else 5
        for s in (-1, 1):
            b.append(f"<line x1='{C - w/2:.2f}' y1='{C + s*dy:.2f}' x2='{C + w/2:.2f}' y2='{C + s*dy:.2f}' stroke='#fff' stroke-width='0.5'/>")
            if p % 10 == 0:
                b.append(text(C - w/2 - 3, C + s * dy, p, 2.6))
                b.append(text(C + w/2 + 3, C + s * dy, p, 2.6))
    b.append("</g>")
    # roll scale
    b.append(arc(R - 6, -60, 60, 0.5, "#fff"))
    for a in (-60, -45, -30, -20, -10, 10, 20, 30, 45, 60):
        b.append(tick(R - 6, R - (2.5 if abs(a) in (30, 60) else 4), a, 0.6))
    x, y = pol(R - 6.3, 0)
    b.append(f"<polygon points='{x:.2f},{y:.2f} {x - 2:.2f},{y - 3:.2f} {x + 2:.2f},{y - 3:.2f}' fill='#fff'/>")
    # fixed aircraft symbol
    b.append(f"<path d='M{C - 18},{C} h11 l3,3 l3,-3 h11' fill='none' stroke='#ff9a00' stroke-width='1.6' stroke-linejoin='round'/>")
    b.append(f"<circle cx='{C}' cy='{C}' r='1.1' fill='#ff9a00'/>")
    b.append(f"<rect x='{C - 3}' y='{D - 9}' width='6' height='4' rx='1' fill='#222' stroke='#888' stroke-width='0.3'/>")
    return svg("\n".join(b), "Standby attitude")

# ------------------------------------------------------------------ altimeter
def altimeter():
    b = []
    for i in range(50):
        deg = i * 7.2
        big = i % 5 == 0
        b.append(tick(R - (6 if big else 3.8), R - 1.2, deg, 0.7 if big else 0.35))
    for n in range(10):
        x, y = pol(R - 11.5, n * 36)
        b.append(text(x, y, n, 6))
    b.append(text(C, C - 11, "ALT", 3.4, "#ddd"))
    b.append(text(C, C + 13, "100 FEET", 2.6, "#ddd"))
    # Kollsman window
    b.append(f"<rect x='{C + 9}' y='{C - 3}' width='15' height='6' fill='#111' stroke='#888' stroke-width='0.3'/>")
    b.append(text(C + 16.5, C + 0.2, "29.92", 3.2))
    # hands (static at 1,200 ft)
    for length, width, deg in ((26, 1.6, 72), (17, 2.8, 43), (12, 0.8, 4)):
        x, y = pol(length, deg)
        b.append(f"<line x1='{C}' y1='{C}' x2='{x:.2f}' y2='{y:.2f}' stroke='#fff' stroke-width='{width}' stroke-linecap='round'/>")
    b.append(f"<circle cx='{C}' cy='{C}' r='2.2' fill='#333'/>")
    return svg("\n".join(map(str, b)), "Standby altimeter")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("airspeed", airspeed), ("attitude", attitude), ("altimeter", altimeter)):
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(fn())
        print("faces/" + name + ".svg")
