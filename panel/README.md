# Printable Panel

Panel pieces with every control's cutouts, mounting holes and countersinks already in place. The layout follows the 172S lower panel and centre pedestal.

![preview](images/preview.png)

| With the optional prop control | Behind the panel |
|---|---|
| ![](images/preview_with_prop.png) | ![](images/preview_rear.png) |

## Pieces

| Piece | What's on it | Size | STL |
|---|---|---|---|
| Lower panel | Parking brake, throttle, (prop), mixture, engraved labels | 330 × 120 mm, split into 2 tiles | `lower_tile_1`, `lower_tile_2` + `splice` |
| Pedestal face | Trim wheel slot + placard outline | 130 × 170 mm | `pedestal` |
| Pedestal floor | Fuel selector | 150 × 150 mm | `floor` |

- **Thickness:** all pieces are `panel_thickness` thick (6.35 mm by default, set in `common/sim_common.scad`).
- **Printing:** print **front face down** for a smooth face; the engraved labels print correctly that way.
- **Joining the lower panel:** the tiles butt together. Glue the `splice` strip across the seam on the back, plus 4 × M3 × 10 screws into the blind pilot holes.
- **Mounting:** the 4.5 mm holes around the edges are for #8 or M4 screws into your frame.
- **Cutting from plywood instead:** [`templates/`](templates) has full-size SVG and DXF files (front view) for a laser or CNC, or to print and drill through.

## Changing the layout

See **[Moving the controls](../README.md#moving-the-controls)** in the main README for the full guide. In short:

![Layout map](images/layout_map.png)

Open `c172_panel.scad` in OpenSCAD and use the Customizer:

- **Control positions:** `brake_pos`, `throttle_pos`, `prop_pos`, `mixture_pos`, in mm right of panel centre and up from the panel bottom.
- **Prop:** `has_prop` adds the blue prop knob between the throttle and mixture.
- **Yoke:** `yoke_hole = [x, y, w, h]` cuts an opening for a yoke shaft. Your Moza AY210 sits on the desk, so leave it empty unless the yoke shaft has to pass through this panel.
- **Labels:** `labels` turns the engraved labels on or off.
- **Bed size:** `bed` (your print bed size) and `lower_splits` (where tiles split). OpenSCAD warns if a tile is too big.

The positions are approximate 172S proportions taken from photos, not from factory drawings. Move them to suit your seat, yoke and monitor.

## Not included (already on your Moza AY210)

The AY210 base has its own 13-switch panel, and the yoke has the buttons and hats. So master, avionics, lights and magneto switches aren't modelled here.
