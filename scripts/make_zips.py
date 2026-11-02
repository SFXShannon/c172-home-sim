#!/usr/bin/env python3
"""Zip the throttle / mixture / prop files so they download in one click.

Writes parts/<control>/<control>_files.zip (STLs, panel templates, README,
.scad source) and parts/push-pull-test-plate/throttle_mixture_prop_all.zip
(all three controls + the test plate). render.sh runs this at the end.
"""
import os, zipfile

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
COMMON = ["common/push_pull.scad", "common/sim_common.scad"]


def files_for(c):
    d = f"parts/{c}"
    out = []
    for sub in ["stl", "panel-template"]:
        for f in sorted(os.listdir(f"{d}/{sub}")):
            out.append((f"{d}/{sub}/{f}", f"{c}/{sub}/{f}"))
    out += [(f"{d}/README.md", f"{c}/README.md"), (f"{d}/{c}.scad", f"{c}/{c}.scad")]
    return out


def write(path, entries):
    # fixed timestamps so the zip only changes when its contents do
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for src, arc in entries:
            info = zipfile.ZipInfo(arc, (2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(src, "rb") as f:
                z.writestr(info, f.read())
    print("  " + path)


every = []
for c in ["throttle", "mixture", "prop"]:
    entries = files_for(c)
    every += entries
    write(f"parts/{c}/{c}_files.zip", entries + [(p, p) for p in COMMON])

tp = "parts/push-pull-test-plate"
every += [(f"{tp}/stl/{f}", f"test-plate/stl/{f}") for f in sorted(os.listdir(f"{tp}/stl"))]
every += [(f"{tp}/{f}", f"test-plate/{f}") for f in ["README.md", "push_pull_test_plate.scad"]]
write(f"{tp}/throttle_mixture_prop_all.zip", every + [(p, p) for p in COMMON])
