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

// ---------- standard panel mount ----------
// Every control bolts to the back of the panel the same way: a square flange
// with 4 x M3 holes on a 28 mm square, nuts captured in the back of the flange,
// countersunk screws from the front of the panel (flush, like the real panel).

mount_pitch = 28;
mount_flange_size = 42;
mount_flange_t = 6;

module at_mount_holes(pitch = mount_pitch) {
    for (x = [-1, 1], y = [-1, 1]) translate([x * pitch / 2, y * pitch / 2]) children();
}

// Flange solid, front face at z = 0, extends to +z (behind the panel).
module mount_flange(size = mount_flange_size, t = mount_flange_t) {
    linear_extrude(t) rounded_rect([size, size], 5);
}

// Holes + nut pockets for mount_flange (subtract).
module mount_flange_holes(t = mount_flange_t, pitch = mount_pitch) {
    at_mount_holes(pitch) {
        translate([0, 0, -1]) cylinder(d = m3_clear_d, h = t + 2);
        translate([0, 0, t - m3_nut_t - 0.6]) m3_nut_pocket(m3_nut_t + 1);
    }
}

// 2D panel holes for the standard mount (screws are countersunk from the front).
module mount_panel_holes(pitch = mount_pitch) {
    at_mount_holes(pitch) circle(d = m3_clear_d);
}

// Countersinks in a panel whose front face is at z = 0 (panel extends to +z).
module mount_panel_countersinks(pitch = mount_pitch) {
    at_mount_holes(pitch) translate([0, 0, -0.01])
        cylinder(d1 = m3_head_d + 0.4, d2 = m3_clear_d, h = (m3_head_d + 0.4 - m3_clear_d) / 2);
}

function mount_screw_len(panel_t, flange_t = mount_flange_t) =
    [for (l = [10, 12, 14, 16, 18, 20, 25, 30]) if (l >= panel_t + flange_t) l][0];

// Standard visual-only hardware for renders: screws + nuts. Panel front at z = -panel_t.
module mount_hardware_dummy(panel_t, flange_t = mount_flange_t, pitch = mount_pitch) {
    color("silver") at_mount_holes(pitch) {
        translate([0, 0, -panel_t]) cylinder(d1 = m3_head_d, d2 = 3, h = 1.6);
        translate([0, 0, -panel_t]) cylinder(d = 3, h = mount_screw_len(panel_t, flange_t));
        translate([0, 0, flange_t - m3_nut_t - 0.6]) cylinder(d = m3_nut_af / cos(30), h = m3_nut_t, $fn = 6);
    }
}

// Ribbed (knurled) cylinder: n ribs around, radius r, height h.
module ribbed_cylinder(r, h, n = 24, depth = 0.8) {
    difference() {
        cylinder(r = r, h = h);
        for (i = [0 : n - 1]) rotate([0, 0, i * 360 / n])
            translate([r, 0, -1]) cylinder(r = depth, h = h + 2, $fn = 12);
    }
}

// Simple involute spur gear (module m, z teeth, thickness h). Good enough for FDM.
function _inv(a) = tan(a) - a * PI / 180;
module spur_gear(m, z, h, bore = 0, pa = 20) {
    rp = m * z / 2; rb = rp * cos(pa); ra = rp + m; rr = rp - 1.25 * m;
    tooth_ang = 360 / z;
    half = 90 / z + _inv(pa) * 180 / PI;   // half tooth angle at base circle
    function inv_pt(r, s) = let(a = acos(min(1, rb / r)), t = half - _inv(a) * 180 / PI)
        [r * cos(s * t), r * sin(s * t)];
    steps = 8;
    rs = [for (i = [0 : steps]) max(rb, rr) + (ra - max(rb, rr)) * i / steps];
    tooth = concat([[rr * cos(-half - 2), rr * sin(-half - 2)]],
                   [for (r = rs) inv_pt(r, -1)],
                   [for (i = [steps : -1 : 0]) inv_pt(rs[i], 1)],
                   [[rr * cos(half + 2), rr * sin(half + 2)]]);
    linear_extrude(h) difference() {
        union() {
            circle(r = rr + 0.01, $fn = z * 4);
            for (i = [0 : z - 1]) rotate(i * tooth_ang) polygon(concat([[0, 0]], tooth));
        }
        if (bore > 0) circle(d = bore);
    }
}
function gear_pitch_r(m, z) = m * z / 2;

// Rounded rectangle (2D), centred.
module rounded_rect(size, r) {
    hull() for (x = [-1, 1], y = [-1, 1])
        translate([x * (size[0] / 2 - r), y * (size[1] / 2 - r)]) circle(r = r);
}
