#!/usr/bin/env python3
"""Draw printable faces for the standby instruments (SVG, real size in mm).

Print them at 100 % (no "fit to page") on photo paper, cut out, glue on the
printed parts.  Markings follow the C172S: airspeed arcs in knots.

    python3 make_faces.py  ->  faces/airspeed.svg     on asi_face_plate (centre hole: the X27 shaft)
                               faces/altimeter.svg    on alt_front_plate (centre hole: the hand tube)
                               faces/att_ring.svg     bank scale, on att_ring
                               faces/att_roll_disc.svg  sky / ground ring with the bank pointer, on the roll frame
                               faces/att_drum.svg     wraps round the horizon drum (sky toward the top)
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
    b.append(f"<circle cx='{C}' cy='{C}' r='1.5' fill='#fff'/>")      # cut out: shaft hole
    return svg("\n".join(map(str, b)), "Standby airspeed")

# ------------------------------------------------------------------ attitude (three pieces)
def ring_svg(d_out, d_in, body, title):
    r = d_out / 2
    return (f"<svg xmlns='http://www.w3.org/2000/svg' width='{d_out}mm' height='{d_out}mm' viewBox='0 0 {d_out} {d_out}'>\n"
            f"<title>{title}</title>\n{body}\n"
            f"<circle cx='{r}' cy='{r}' r='{d_in / 2}' fill='#fff' stroke='#999' stroke-width='0.2'/>\n"
            f"<circle cx='{r}' cy='{r}' r='{r - 0.1}' fill='none' stroke='#999' stroke-width='0.2'/>\n</svg>\n")

def att_ring():          # fixed bank scale, 75.6 / 66 mm
    d, di = 75.6, 66
    r = d / 2
    def p(rr, deg): a = math.radians(deg); return r + rr * math.sin(a), r - rr * math.cos(a)
    b = [f"<circle cx='{r}' cy='{r}' r='{r}' fill='#0b0b0b'/>"]
    for a in (-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60):
        big = a % 30 == 0
        (x1, y1), (x2, y2) = p(di / 2 + 0.6, a), p(di / 2 + (4.2 if big else 2.6), a)
        b.append(f"<line x1='{x1:.2f}' y1='{y1:.2f}' x2='{x2:.2f}' y2='{y2:.2f}' stroke='#fff' stroke-width='{0.8 if big else 0.5}'/>")
    return ring_svg(d, di, "\n".join(b), "Attitude: bank scale ring")

def att_roll_disc():     # turns with the roll frame, 64 / 46 mm
    d, di = 64.0, 46.0
    r = d / 2
    b = [f"<path d='M0,{r} A{r},{r} 0 0 1 {d},{r} Z' fill='#2f74d0'/>",
         f"<path d='M0,{r} A{r},{r} 0 0 0 {d},{r} Z' fill='#8a5a2b'/>",
         f"<line x1='0' y1='{r}' x2='{d}' y2='{r}' stroke='#fff' stroke-width='0.6'/>",
         f"<polygon points='{r},{0.6} {r - 2.2},{4.6} {r + 2.2},{4.6}' fill='#fff'/>"]
    return ring_svg(d, di, "\n".join(b), "Attitude: roll disc")

def att_drum():          # wraps round the 56 mm drum: 175.9 x 50 mm, horizon across the middle
    L, W = math.pi * 56, 50.0
    mm_per_deg = 28 * 2 * math.pi / 180      # the drum turns 2 deg per deg of pitch
    h = L / 2
    b = [f"<svg xmlns='http://www.w3.org/2000/svg' width='{W}mm' height='{L:.2f}mm' viewBox='0 0 {W} {L:.2f}'>",
         "<title>Attitude: horizon drum wrap (glue round the drum, sky toward the top, horizon at the front)</title>",
         f"<rect x='0' y='0' width='{W}' height='{h:.2f}' fill='#2f74d0'/>",
         f"<rect x='0' y='{h:.2f}' width='{W}' height='{h:.2f}' fill='#8a5a2b'/>",
         f"<line x1='0' y1='{h:.2f}' x2='{W}' y2='{h:.2f}' stroke='#fff' stroke-width='0.7'/>"]
    for p in range(5, 35, 5):
        for sgn in (-1, 1):
            y = h + sgn * p * mm_per_deg
            w = 14 if p % 10 == 0 else 7
            b.append(f"<line x1='{W/2 - w/2:.2f}' y1='{y:.2f}' x2='{W/2 + w/2:.2f}' y2='{y:.2f}' stroke='#fff' stroke-width='0.45'/>")
            if p % 10 == 0:
                for x in (W/2 - w/2 - 3.2, W/2 + w/2 + 3.2):
                    b.append(f"<text x='{x:.2f}' y='{y:.2f}' font-size='2.8' fill='#fff' text-anchor='middle' dominant-baseline='middle' {FONT}>{p}</text>")
    b.append(f"<rect x='0.1' y='0.1' width='{W - 0.2}' height='{L - 0.2:.2f}' fill='none' stroke='#999' stroke-width='0.2'/>")
    return "\n".join(b) + "\n</svg>\n"

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
    b.append(f"<circle cx='{C}' cy='{C}' r='3.4' fill='#fff'/>")      # cut out: hand tube hole
    return svg("\n".join(map(str, b)), "Standby altimeter")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    old = os.path.join(OUT, "attitude.svg")
    if os.path.exists(old):
        os.remove(old)
    for name, fn in (("airspeed", airspeed), ("altimeter", altimeter), ("att_ring", att_ring),
                     ("att_roll_disc", att_roll_disc), ("att_drum", att_drum)):
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(fn())
        print("faces/" + name + ".svg")
