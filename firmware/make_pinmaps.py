#!/usr/bin/env python3
"""Write the Arduino Mega pin maps for the G1000 bezels and the switch panels.

Each board runs MobiFlight. Every switch goes between its pin and GND
(MobiFlight uses the internal pull-ups). Encoders: A and B to two pins,
the middle pin (C) to GND."""
import os

POOL = [f"D{i}" for i in range(2, 54) if i != 13] + [f"A{i}" for i in range(16)]   # D13 has the onboard LED

def assign(items):
    """items: (name, kind) with kind in 'button', 'encoder'. Returns rows."""
    pins = iter(POOL)
    rows = []
    for name, kind in items:
        if kind == "encoder":
            rows.append((name, "Encoder", f"{next(pins)} (A), {next(pins)} (B)"))
        elif kind == "analog":
            rows.append((name, "Analog input", "see note"))
        elif kind == "output":
            rows.append((name, "LED output", next(pins)))
        else:
            rows.append((name, "Button / switch", next(pins)))
    used = sum(2 if k == "encoder" else 0 if k == "analog" else 1 for _, k in items)
    return rows, used

def gdu(unit):
    it = []
    it += [(f"{unit} NAV VOL (turn)", "encoder"), (f"{unit} NAV VOL push (ID)", "button"),
           (f"{unit} NAV outer knob", "encoder"), (f"{unit} NAV inner knob", "encoder"),
           (f"{unit} NAV flip key", "button"),
           (f"{unit} HDG knob", "encoder"), (f"{unit} HDG push (sync)", "button"),
           (f"{unit} ALT outer knob", "encoder"), (f"{unit} ALT inner knob", "encoder"),
           (f"{unit} COM VOL (turn)", "encoder"), (f"{unit} COM VOL push (squelch)", "button"),
           (f"{unit} COM outer knob", "encoder"), (f"{unit} COM inner knob", "encoder"),
           (f"{unit} COM flip key", "button"),
           (f"{unit} CRS knob (inner)", "encoder"), (f"{unit} BARO knob (outer)", "encoder"),
           (f"{unit} RANGE knob", "encoder"), (f"{unit} RANGE push (pan)", "button"),
           (f"{unit} FMS outer knob", "encoder"), (f"{unit} FMS inner knob", "encoder")]
    it += [(f"{unit} softkey {i}", "button") for i in range(1, 13)]
    it += [(f"{unit} {k}", "button") for k in ["AP", "FD", "HDG", "ALT", "NAV", "VNV", "APR", "BC", "VS", "NOSE UP", "FLC", "NOSE DN"]]
    it += [(f"{unit} {k}", "button") for k in ["DIRECT-TO", "MENU", "FPL", "PROC", "CLR", "ENT"]]
    return it

def panel3():
    it = []
    gma = ["COM1 MIC", "COM1", "COM2 MIC", "COM2", "COM3 MIC", "COM3", "COM1/2", "TEL", "PA", "SPKR", "MKR/MUTE",
           "HI SENS", "DME", "NAV1", "ADF", "NAV2", "AUX", "MAN SQ", "PLAY", "PILOT", "COPLT"]
    it += [(f"GMA {k}", "button") for k in gma]
    it += [("GMA volume knob", "encoder"), ("GMA volume push", "button"), ("GMA DISPLAY BACKUP", "button")]
    it += [("STBY BATT ON", "button"), ("STBY BATT TEST", "button"), ("STBY BATT test light", "output"),
           ("MASTER ALT", "button"), ("MASTER BAT", "button"), ("AVIONICS BUS 1", "button"), ("AVIONICS BUS 2", "button")]
    it += [(f"{k} light", "button") for k in ["BEACON", "LAND", "TAXI", "NAV", "STROBE"]]
    it += [("FUEL PUMP", "button"), ("PITOT HEAT", "button"), ("CABIN PWR 12V", "button")]
    it += [(f"Ignition {k}", "button") for k in ["OFF", "R", "L", "BOTH", "START"]]
    return it

def table(title, items, note):
    rows, used = assign(items)
    out = [f"## {title}", "", note, "", f"{used} pins used of {len(POOL)}.", "",
           "| Input | Type | Mega pin(s) |", "|---|---|---|"]
    out += [f"| {a} | {b} | {c} |" for a, b, c in rows]
    return "\n".join(out) + "\n"

if __name__ == "__main__":
    doc = [open(os.path.join(os.path.dirname(__file__), "G1000_WIRING.intro.md")).read()]
    doc.append(table("Board 1: PFD bezel", gdu("PFD"),
        "One Arduino Mega 2560 behind the PFD. 32 keys + 9 knobs (5 of them dual)."))
    doc.append(table("Board 2: MFD bezel", gdu("MFD"),
        "Identical to board 1, for the MFD. Name it differently in MobiFlight (e.g. \"MFD\")."))
    doc.append(table("Board 3: audio panel, switch panels, ignition", panel3(),
        "One Mega for everything else that is a switch. The four dimmer pots go to A12-A15 "
        "as MobiFlight analog inputs (pin numbers shown above stop before them)."))
    with open(os.path.join(os.path.dirname(__file__), "G1000_WIRING.md"), "w") as f:
        f.write("\n".join(doc))
    print("G1000_WIRING.md")
