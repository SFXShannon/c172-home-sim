#!/usr/bin/env python3
"""Render the README animations: each control working, seen from the pilot's
seat and from behind the panel (housings drawn see-through).

Needs OpenSCAD, Pillow (pip install pillow) and, on a headless Linux box, Xvfb.

    python3 scripts/make_gifs.py            # all controls
    python3 scripts/make_gifs.py throttle   # one
"""
import os, subprocess, sys, tempfile, shutil
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "anim")
FRAMES = 40
W, H = 560, 420
FRAME_MS = 80

# eye x,y,z , centre x,y,z  (view coordinates: +z up, pilot on the +y side).
# A camera can also be a list of (from t, camera) cuts. The bezels and switch
# plates are modelled face-up, so their cameras look down the z axis.
SEAT, BEHIND = "FROM THE SEAT", "BEHIND THE PANEL (housing see-through)"
CONTROLS = {
    "parking-brake": dict(
        scad="parts/parking-brake/parking_brake.scad",
        title="Parking brake",
        front=(-250, 380, 30, -45, 20, -50), rear=(210, -210, 110, -5, -40, -5),
        captions=[(0.00, 0.30, "Pull the handle out"),
                  (0.30, 0.48, "Rotate it down - the lug drops into the notch"),
                  (0.48, 0.62, "SET - the spring holds it"),
                  (0.62, 0.78, "Lift and rotate it back up"),
                  (0.78, 1.01, "The spring pulls it home - RELEASED")]),
    "throttle": dict(
        scad="parts/throttle/throttle.scad", title="Throttle",
        front=(-300, 300, 120, 0, 40, -5), rear=(300, -280, 170, 0, -70, -10),
        captions=[(0.00, 0.08, "Pushed in - FULL THROTTLE"),
                  (0.08, 0.50, "Pull out to IDLE - the carriage slides the pot"),
                  (0.50, 0.58, "IDLE"),
                  (0.58, 1.01, "Push in for power - O-ring friction holds it anywhere")]),
    "mixture": dict(
        scad="parts/mixture/mixture.scad", title="Mixture",
        front=(-300, 300, 120, 0, 40, -5), rear=(300, -280, 170, 0, -70, -10),
        captions=[(0.00, 0.08, "In - FULL RICH"),
                  (0.08, 0.50, "Pull out to lean / IDLE CUT-OFF"),
                  (0.50, 0.58, "IDLE CUT-OFF"),
                  (0.58, 1.01, "Push back in - RICH")]),
    "prop": dict(
        scad="parts/prop/prop.scad", title="Prop",
        front=(-300, 300, 120, 0, 40, -5), rear=(300, -280, 170, 0, -70, -10),
        captions=[(0.00, 0.08, "In - HIGH RPM"),
                  (0.08, 0.50, "Pull out for LOW RPM"),
                  (0.50, 0.58, "LOW RPM"),
                  (0.58, 1.01, "Push back in - HIGH RPM")]),
    "trim-wheel": dict(
        scad="parts/trim-wheel/trim_wheel.scad", title="Elevator trim wheel",
        front=(-230, 300, 110, 0, 0, 0), rear=(280, -170, 150, 0, -45, 0),
        captions=[(0.00, 0.38, "Roll the top forward - NOSE DOWN"),
                  (0.38, 0.85, "Roll it back - NOSE UP"),
                  (0.85, 1.01, "The encoder gear turns 3x as fast as the wheel")]),
    "fuel-selector": dict(
        scad="parts/fuel-selector/fuel_selector.scad", title="Fuel selector",
        front=(-60, 260, 300, 0, 10, 0), rear=(250, -150, -230, 0, 20, -25),
        captions=[(0.00, 0.14, "BOTH"), (0.14, 0.44, "LEFT tank"), (0.44, 0.64, "BOTH"),
                  (0.64, 0.94, "RIGHT tank"), (0.94, 1.01, "BOTH")]),
    "flap-lever": dict(
        scad="parts/flap-lever/flap_lever.scad", title="Flap lever",
        front=(-180, 230, 50, 0, 0, 0), rear=(110, -300, 70, 0, -25, 0),
        captions=[(0.00, 0.06, "UP"), (0.06, 0.24, "Push down - click at 10 deg"),
                  (0.24, 0.42, "Click at 20 deg"), (0.42, 0.66, "FULL - the carriage slides the pot"),
                  (0.66, 0.90, "Lift back to UP"), (0.90, 1.01, "UP")]),
    "g1000-gdu": dict(
        scad="parts/g1000-gdu/gdu1040.scad", title="G1000 PFD / MFD bezel",
        labels=("THE WHOLE BEZEL", "CLOSE UP"),
        front=(0, -150, 620, 0, -3, 0),
        rear=[(0.00, (0, -300, 200, 0, -60, 0)), (0.30, (-30, -170, 190, -120, 10, 0)),
              (0.57, (40, -165, 215, 115, 15, 0))],
        captions=[(0.00, 0.30, "Softkeys - each cap presses a 6 mm tactile switch"),
                  (0.30, 0.34, "NAV flip-flop key"),
                  (0.34, 0.47, "HDG knob - an EC11 encoder"),
                  (0.47, 0.57, "Autopilot keys: AP, HDG, ALT"),
                  (0.57, 0.61, "COM flip-flop key"),
                  (0.61, 0.69, "Dual knob: the outer ring..."),
                  (0.69, 0.78, "...and the inner knob turn separately"),
                  (0.78, 0.86, "FMS keys: D->, FPL, ENT"),
                  (0.86, 1.01, "RANGE knob - map zoom")]),
    "g1000-gma": dict(
        scad="parts/g1000-gma/gma1347.scad", title="GMA 1347 audio panel",
        labels=("THE WHOLE PANEL", "CLOSE UP"),
        front=(0, -125, 470, 0, -5, 0),
        rear=[(0.00, (55, -40, 150, 0, 45, 0)), (0.17, (55, -80, 150, 0, 5, 0)),
              (0.56, (55, -150, 130, 0, -55, 0))],
        captions=[(0.00, 0.18, "COM1 / COM2 - pick the radio to listen to"),
                  (0.18, 0.44, "NAV1, NAV2, ADF and MKR audio"),
                  (0.44, 0.58, "SPKR, PLAY - each key is a tactile switch"),
                  (0.58, 0.82, "Volume / squelch knob - an EC11 encoder"),
                  (0.82, 1.01, "DISPLAY BACKUP (print this cap red)")]),
    "switch-panel": dict(
        scad="parts/switch-panel/switch_panel.scad", title="C-post and lights panels",
        labels=("BOTH PANELS", "CLOSE UP"),
        front=(-5, -170, 470, -5, 0, 0),
        rear=[(0.00, (-40, -150, 150, -80, 0, 0)), (0.36, (130, -150, 130, 100, 0, 0)),
              (0.69, (20, -150, 140, 5, 0, 0)), (0.92, (-40, -150, 150, -80, 0, 0))],
        captions=[(0.00, 0.17, "MASTER: BAT, then ALT (off-the-shelf rockers)"),
                  (0.17, 0.25, "STANDBY BATT: ARM"),
                  (0.25, 0.36, "AVIONICS: BUS 1, BUS 2"),
                  (0.36, 0.63, "Lights: BEACON, LAND, TAXI, NAV, STROBE (mini toggles)"),
                  (0.63, 0.70, "FUEL PUMP, PITOT HEAT"),
                  (0.70, 0.92, "Dimmers - 16 mm pots"),
                  (0.92, 1.01, "Shut down")]),
    "ignition": dict(
        scad="parts/panel-extras/panel_extras.scad", part="assembly_ignition", title="Ignition key",
        labels=(SEAT, "BEHIND THE PANEL (panel see-through)"),
        front=(0, -45, 165, 0, 3, 0), rear=(45, 70, -115, 0, 0, -18),
        captions=[(0.00, 0.10, "OFF"), (0.10, 0.28, "R magneto"), (0.28, 0.45, "L magneto"),
                  (0.45, 0.62, "BOTH"), (0.62, 0.77, "START"),
                  (0.77, 0.90, "Back to BOTH (the real key springs back)"), (0.90, 1.01, "OFF")]),
}

def font(size, bold=False):
    for f in (["/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"] if bold else []) + \
             ["/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()

def cam_at(cam, t):
    if isinstance(cam, list):
        return [c for t0, c in cam if t0 <= t + 1e-9][-1]
    return cam

def render(scad, part, t, cam, path, env):
    cmd = ["openscad", "-q", "--preview", f"--imgsize={W},{H}", "--colorscheme=Tomorrow",
           "--projection=p", "--camera=" + ",".join(str(c) for c in cam_at(cam, t)),
           "-D", f'part="{part}"', "-D", f"anim={t:.4f}", "-D", "ghost=true",
           "-o", path, os.path.join(ROOT, scad)]
    for attempt in range(4):   # headless GL occasionally drops a frame - just retry it
        r = subprocess.run(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if r.returncode == 0 and os.path.exists(path):
            return
    raise RuntimeError("OpenSCAD failed: " + " ".join(cmd))

def caption(cfg, t):
    for a, b, txt in cfg["captions"]:
        if a <= t < b:
            return txt
    return ""

def make(name, cfg, env):
    tmp = tempfile.mkdtemp()
    jobs = []
    for i in range(FRAMES):
        t = i / FRAMES
        for view in ("front", "rear"):
            jobs.append((cfg["scad"], cfg.get("part", "assembly"), t, cfg[view], os.path.join(tmp, f"{view}_{i:03d}.png")))
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 2) as ex:
        list(ex.map(lambda j: render(*j, env), jobs))

    bar = 46
    f_title, f_cap, f_lab = font(20, True), font(18), font(14, True)
    frames = []
    for i in range(FRAMES):
        t = i / FRAMES
        img = Image.new("RGB", (2 * W, H + bar), (248, 248, 248))
        img.paste(Image.open(os.path.join(tmp, f"front_{i:03d}.png")).convert("RGB"), (0, bar))
        img.paste(Image.open(os.path.join(tmp, f"rear_{i:03d}.png")).convert("RGB"), (W, bar))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 2 * W, bar], fill=(40, 44, 49))
        d.text((14, 12), cfg["title"], font=f_title, fill=(232, 234, 228))
        d.text((14 + d.textlength(cfg["title"], font=f_title) + 18, 14), caption(cfg, t), font=f_cap, fill=(240, 170, 90))
        left, right = cfg.get("labels", (SEAT, BEHIND))
        d.text((12, bar + 8), left, font=f_lab, fill=(90, 96, 102))
        d.text((W + 12, bar + 8), right, font=f_lab, fill=(90, 96, 102))
        d.line([(W, bar), (W, H + bar)], fill=(210, 212, 210), width=2)
        frames.append(img)
    os.makedirs(OUT, exist_ok=True)
    pal = frames[FRAMES // 2].quantize(colors=128, method=Image.Quantize.MEDIANCUT)
    q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    out = os.path.join(OUT, f"{name}.gif")
    q[0].save(out, save_all=True, append_images=q[1:], duration=FRAME_MS, loop=0, optimize=True)
    shutil.rmtree(tmp)
    print(f"  {os.path.relpath(out, ROOT)}  ({os.path.getsize(out) // 1024} KB)")

def main():
    names = sys.argv[1:] or list(CONTROLS)
    env = dict(os.environ)
    xvfb = None
    if not env.get("DISPLAY") and shutil.which("Xvfb"):
        xvfb = subprocess.Popen(["Xvfb", ":97", "-screen", "0", "1280x1024x24"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        env["DISPLAY"] = ":97"
        import time; time.sleep(1.5)
    try:
        for n in names:
            make(n, CONTROLS[n], env)
    finally:
        if xvfb:
            xvfb.terminate()

if __name__ == "__main__":
    main()
