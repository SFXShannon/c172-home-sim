// Shared settings and helpers for every C172 home-sim part.
// Parts `include` this file first, then may override any value.

/* [Panel] */
// Thickness of your dash panel (6.35 = 1/4" plywood/MDF, 3 = 1/8" acrylic)
panel_thickness = 6.35;

/* [Printer fit] */
// Extra gap added to sliding/press fits. Raise if parts bind, lower if sloppy.
clearance = 0.25;

/* [Fasteners] */
// true = holes sized for M3 heat-set inserts, false = self-tapping M3 pilot holes
use_heat_set_inserts = false;

m3_clear_d   = 3.4;   // through hole for an M3 screw
m3_pilot_d   = 2.6;   // screw threads straight into plastic
m3_insert_d  = 4.0;   // typical M3 x 4 x 5 heat-set insert
m3_head_d    = 6.0;   // countersink / counterbore head size
m3_nut_af    = 5.5;   // nut across flats
m3_nut_t     = 2.4;   // nut thickness

m2_clear_d   = 2.3;   // microswitch mounting screws

function m3_tap_d() = use_heat_set_inserts ? m3_insert_d : m3_pilot_d;

$fn = 72;

// ---------- helpers ----------

// Countersunk M3 hole, head at z = top, going down by depth.
module m3_countersunk(depth, top = 0) {
    translate([0, 0, top - depth - 0.01]) cylinder(d = m3_clear_d, h = depth + 0.02);
    translate([0, 0, top - (m3_head_d - m3_clear_d) / 2])
        cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.2, h = (m3_head_d - m3_clear_d) / 2 + 0.01);
}

// Hex nut pocket, axis along Z.
module m3_nut_pocket(h) {
    cylinder(d = (m3_nut_af + 2 * clearance) / cos(30), h = h, $fn = 6);
}

// Rounded rectangle (2D), centred.
module rounded_rect(size, r) {
    hull() for (x = [-1, 1], y = [-1, 1])
        translate([x * (size[0] / 2 - r), y * (size[1] / 2 - r)]) circle(r = r);
}
