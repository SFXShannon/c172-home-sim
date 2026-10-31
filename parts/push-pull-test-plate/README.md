# Push-pull test plate

**Download:** [throttle_mixture_prop_all.zip](https://github.com/SFXShannon/c172-home-sim/raw/main/parts/push-pull-test-plate/throttle_mixture_prop_all.zip): this plate plus every throttle, mixture and prop file in one zip.

A bench plate that holds the **throttle, prop and mixture** side by side, in the real 172 order (left to right from the seat). Use it to build, wire and calibrate the three controls before the dashboard is printed.

![Test plate from the pilot's seat](images/front.png)

![From behind, with the extrusion along the top and right](images/rear.png)

## What it is

- **Size:** 231 × 107 mm, 6.35 mm thick (same as `panel_thickness`, so the controls use the same M3 × 14 screws as on the real panel).
- **Controls:** 69 mm apart, the same spacing as the dashboard. Each spot has the 14 mm centre hole and the 4 countersunk M3 holes on the 28 mm square. THROTTLE / PROP / MIXTURE are engraved under the knobs.
- **Extrusion mount:** four 8 mm bolt holes, two along the top edge and two down the right edge (as seen from the pilot's side), centred on 40 mm extrusion (4040). The 40 mm strips they're in are kept 3 mm clear of the control flanges and housings, so the extrusion runs along the back of both edges without touching the slide-pot housings.
  - Holes are drawn 8.4 mm so an M8 or 5/16" bolt drops through after printing. Set `bolt_hole_d = 8` if you want them exactly 8 mm.
  - For other extrusion (2020, 1" 10-series), set `rail_w` (20, 25.4); the plate resizes and the holes stay centred.

## Printing

`stl/plate.stl` — prints front face down, no supports. The labels are engraved 0.6 mm into the front face.

## Parts

Each control is built exactly as in [`../throttle/README.md`](../throttle/README.md) (3 × 5/16" rod, 3 × size 011 O-rings, 3 × 128 mm slide pots, 12 × M3 × 14 countersunk screws + nuts), plus 4 bolts and T-nuts for your extrusion.
