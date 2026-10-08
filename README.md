# C172 Home Sim

3D-printable cockpit controls modelled on the Cessna 172, with a printable panel to mount them in. They're built to drive MSFS from a home-built cockpit.

The goal is **parts that look like the real aircraft's, with simple insides**: printed parts, a few screws, and off-the-shelf sensors such as microswitches, slide pots, an encoder and a rotary switch.

![Panel preview](panel/images/preview.png)

## Controls

| Control | Looks like | Inside | Sensor |
|---|---|---|---|
| [Parking brake](parts/parking-brake) | Black L-lever; pull and rotate down to set | Spring + bayonet slot | Microswitch |
| [Throttle](parts/throttle) | Smooth round knob, knurled friction nut | 8 mm rod, O-ring friction | 60 mm slide pot |
| [Mixture](parts/mixture) | Red ribbed vernier knob with lock button | Same as throttle | 60 mm slide pot |
| [Prop](parts/prop) (optional) | Blue crenellated knob | Same as throttle | 60 mm slide pot |
| [Elevator trim wheel](parts/trim-wheel) | Black ridged wheel in the pedestal, NOSE DN / T.O. / NOSE UP placard | 608 bearings, 3:1 gear | EC11 encoder |
| [Fuel selector](parts/fuel-selector) | Pointer handle on a LEFT / BOTH / RIGHT placard | 3:1 gear to rotary switch | 1P12T rotary switch |
| [Panel](panel) | Lower panel + pedestal face + floor, tiled for printing | — | — |
| [Firmware](firmware) | — | — | Arduino Pro Micro → one USB joystick |

The Moza AY210 yoke and base already cover the yoke buttons and the switch panel, so those aren't modelled here.

## Panel mounting (same for every control)

Every control bolts behind the panel the same way. Four **M3 countersunk screws** go in from the front, through the control's flange, into **M3 nuts captured in the back of the flange**. The screw heads sit flush, like the real panel. Each control folder has a `panel-template/` (SVG to print 1:1, DXF for laser/CNC) and a `panel_test_plate` STL for test-fitting.

## Layout

```
common/            shared settings (panel thickness, fit, M3 hardware, mount pattern, gears)
  push_pull.scad   shared throttle / mixture / prop mechanism
parts/<control>/
  <control>.scad   parametric source (OpenSCAD Customizer)
  stl/             print-ready STLs, already in print orientation
  panel-template/  cutout drawing
  images/          renders
  README.md        parts list, printing, assembly, wiring, MSFS binding
panel/             printable panel pieces + full-size templates
firmware/          Arduino Pro Micro sketch
scripts/render.sh  regenerate STLs/templates for the controls
```

## Rebuilding after changes

```bash
scripts/render.sh                  # all controls
scripts/render.sh throttle         # one control
PANEL=3 scripts/render.sh          # for a 3 mm panel
```

The panel STLs are rendered from `panel/c172_panel.scad` (see its README). Everything needs OpenSCAD 2021.01 or newer.

## Status

Every part has been checked in OpenSCAD for collisions through its full range of movement, but **none have been test-printed yet**. Expect to tune `clearance` for your printer. Dimensions are approximated from photos of real 172 parts, not factory drawings.

## License

MIT. See [LICENSE](LICENSE).
