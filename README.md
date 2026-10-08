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

## Moving the controls

Every control on the printable panel can be moved. The positions are plain numbers in [`panel/c172_panel.scad`](panel/c172_panel.scad). Change them, re-render, and the panel cutouts, countersinks and labels all move with them.

![Layout map](panel/images/layout_map.png)

The numbers are in millimetres, as seen from the pilot's seat:
- **x** is how far right of the panel centre (negative = left).
- **y** is how far up from the bottom edge of the panel.

Each control's position is the centre of its knob or shaft.

### What you can move

| Setting | What it moves | Default |
|---|---|---|
| `brake_pos` | Parking brake | `[-140, 45]` |
| `throttle_pos` | Throttle | `[0, 70]` |
| `mixture_pos` | Mixture | `[60, 70]` |
| `mixture_pos_with_prop` | Mixture, used instead when `has_prop = true` | `[110, 70]` |
| `prop_pos` | Prop (only when `has_prop = true`) | `[55, 70]` |
| `has_prop` | Adds the prop control between the throttle and mixture | `false` |
| `pedestal_x` | Moves the whole pedestal (trim wheel + fuel selector) left/right | `30` |
| `lower_w`, `lower_h` | Size of the lower panel | `330`, `120` |
| `pedestal_w`, `pedestal_h`, `floor_d` | Size of the pedestal face and floor plate | `130`, `170`, `150` |
| `yoke_hole` | Cuts a yoke-shaft opening: `[x, y, width, height]`, or `[]` for none | `[]` |
| `labels` | Engraved THROTTLE / MIXTURE / ... labels on or off | `true` |
| `lower_splits` | Where the lower panel is split into print tiles (x positions) | `[-75]` |
| `bed` | Your printer's bed size, so tiles are checked to fit | `250` |

### How to move them (easy way: OpenSCAD Customizer)

1. Install [OpenSCAD](https://openscad.org) and open `panel/c172_panel.scad`.
2. Open *Window → Customizer*. The settings above appear under **Layout - lower panel**, **Layout - pedestal** and **Printing**.
3. Change a value, for example `throttle_pos` to `[-10, 75]`. Press **F5** to see the whole cockpit with every control in its new place.
4. Check the console at the bottom for a **WARNING**. The file checks itself and warns if:
   - two controls are too close (their flanges behind the panel need about **46 mm** between centres),
   - a control hangs off the edge of the panel (keep it at least **21 mm** from every edge),
   - a tile seam cuts through a control (move the seam in `lower_splits`),
   - a tile is wider than your bed.
5. When it looks right, pick a piece in `part` (e.g. `lower_tile_1`), press **F6** to render, then **File → Export → STL**. Repeat for each piece you need.

### Or from the command line

Edit the numbers in the file, then rebuild every panel STL, the templates and the preview images:

```bash
scripts/render.sh panel
```

You can also try a layout without editing the file:

```bash
openscad -D 'throttle_pos=[-10,75]' -D 'mixture_pos=[55,75]' -D 'part="preview"' -o test.png panel/c172_panel.scad
```

### Tips

- **Match the sim cockpit.** In VR it matters more than anything that the real knob sits where your hand sees the virtual one. Measure from the sim's cockpit (or your yoke) and move the controls to match.
- **Adding a split:** if you make the panel wider, add more tile seams, e.g. `lower_splits = [-75, 90]`. The panel can be split into up to 3 tiles (`lower_tile_1` to `lower_tile_3`). Put each seam in a gap between controls.
- **Leave the trim wheel and fuel selector on the pedestal.** To move them, change `pedestal_x`, `pedestal_w`, `pedestal_h` or `floor_d`; the parts stay centred on their plates.
- **Pre-made controls.** The individual controls (`parts/...`) don't need re-rendering when you move them; only the panel changes.

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
scripts/render.sh                  # all controls + the panel
scripts/render.sh throttle         # one control
scripts/render.sh panel            # just the panel (after moving controls)
PANEL=3 scripts/render.sh          # for a 3 mm panel
```

Everything needs OpenSCAD 2021.01 or newer. The script runs on Linux, macOS, or Windows with Git Bash or WSL.

## Status

Every part has been checked in OpenSCAD for collisions through its full range of movement, but **none have been test-printed yet**. Expect to tune `clearance` for your printer. Dimensions are approximated from photos of real 172 parts, not factory drawings.

## License

MIT. See [LICENSE](LICENSE).
