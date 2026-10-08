# C172 Home Sim

3D-printable, parametric cockpit controls modeled on the Cessna 172, built to mount in a home-built dash panel and drive MSFS through a USB button/axis board.

Every part is written in [OpenSCAD](https://openscad.org) so it can be resized for your panel thickness, printer tolerances and fasteners. Ready-to-print STLs are included for the default settings.

![Parking brake](parts/parking-brake/images/assembly_set.png)

## Controls

| Control | Status | Sensor |
|---|---|---|
| [Parking brake](parts/parking-brake) | ✅ v1 | Microswitch → button |
| Throttle (push-pull) | Planned | Slide potentiometer → axis |
| Mixture (push-pull with lock button) | Planned | Slide potentiometer → axis |
| Carb heat | Planned | Microswitch → button |
| Elevator trim wheel + indicator | Planned | Rotary encoder |
| Flap switch | Planned | 3-position switch |
| Fuel selector (L / BOTH / R / OFF) | Planned | Rotary switch |
| Fuel shutoff valve | Planned | Microswitch |
| Magnetos / starter key | Planned | Rotary switch |
| Master / avionics rocker switches | Planned | Toggle switches |
| Primer | Planned | Microswitch |

## Panel conventions

All controls share [`common/sim_common.scad`](common/sim_common.scad):

- **Panel thickness:** `panel_thickness`, default 6.35 mm (¼" plywood/MDF). Change it once and re-render.
- **Mounting:** each control bolts through the panel with M3 screws and comes with a cutout template (SVG and DXF) in its `panel-template/` folder.
- **Fit:** `clearance` tunes all sliding fits for your printer.
- **Hardware:** M3 throughout. Holes are sized for self-tapping by default. Set `use_heat_set_inserts = true` for inserts.

## Layout

```
common/            shared settings and helpers
parts/<control>/
  <control>.scad   parametric source (Customizer-ready)
  stl/             print-ready STLs (default settings)
  panel-template/  cutout drawing: SVG to print 1:1, DXF for laser/CNC
  images/          renders
  README.md        BOM, print settings, assembly, wiring, sim binding
scripts/render.sh  regenerate all STLs/templates
```

## Rebuilding

```bash
scripts/render.sh                  # everything
scripts/render.sh parking-brake    # one control
PANEL=3 scripts/render.sh          # for a 3 mm panel
```

Requires OpenSCAD 2021.01 or newer.

## License

MIT. See [LICENSE](LICENSE).
