// Cessna 172S FLAP lever: UP / 10 / 20 / FULL with a click at each position.
//
// Outside: a small white flap-shaped handle that slides up and down in a slot,
// with the UP 10 20 FULL scale beside it (engraved in the panel).
// Inside (kept simple): a printed carriage slides in a printed channel bolted
// behind the panel (4 x M3 countersunk screws from the front into captive nuts). A springy finger on the carriage
// clicks into 4 notches. The carriage drives a slide pot, the same pot as the
// throttle (default: 128 mm long, 100 mm travel) - bind it to the flaps axis.
//
// Coordinates like the other controls: panel back at z = 0, behind the panel
// is +z, pilot at -z, +y up, pilot's right = -x.

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, housing, carriage, handle, panel_cutout]
// Assembly view: 0 = UP, 1 = 10, 2 = 20, 3 = FULL
position = 0;

/* [Slide pot] */
// Your slide pot (measure it): travel, body length / width / height, lever height
pot_travel = 100;
pot_len = 128;
pot_w = 9.5;
pot_h = 8;
pot_lever_h = 15;
// Moves the pot toward UP (mm), so a long pot doesn't hang below the panel
pot_shift = 4;

/* [Hidden] */
travel = 60;                 // UP to FULL
step = travel / 3;           // 20 mm between detents
detents = [for (i = [0 : 3]) travel / 2 - i * step];   // carriage centre y for UP..FULL
flange_t = mount_flange_t;
fl_size = [44, 104];
fl_screws = [for (sx = [-1, 1], sy = [-1, 1]) [sx * 19, sy * 46]];   // outside the channel walls
slot = [8.6, travel + 9];
inner_w = 24;                // channel width (x)
wall = 3;
carr = [23, 16, 13];         // carriage x, y, z
z_carr0 = flange_t + 0.5;
z_carr1 = z_carr0 + carr[2];
lever_engage = 6;
z_pot_top = z_carr1 - lever_engage + pot_lever_h;
z_back = z_pot_top + pot_h;
stem = [8, 6];               // stem cross-section (x, z... it passes the slot with 0.3 clearance)
end_in = travel / 2 + carr[1] / 2;   // end stops (inner face)

// ------------------------------------------------------------------ housing
module housing() {
    difference() {
        union() {
            translate([0, 0, 0]) linear_extrude(flange_t) rounded_rect(fl_size, 5);
            // side walls
            for (s = [-1, 1]) translate([s > 0 ? inner_w / 2 : -inner_w / 2 - wall, -fl_size[1] / 2, 0])
                cube([wall, fl_size[1], z_back + 3]);
            // back plate
            translate([-inner_w / 2 - wall, -fl_size[1] / 2, z_back]) cube([inner_w + 2 * wall, fl_size[1], 3]);
            // end stops (only as deep as the carriage, so the pot body passes behind)
            for (s = [-1, 1]) translate([-inner_w / 2, s > 0 ? end_in : -end_in - 6, flange_t - 0.01]) cube([inner_w, 6, carr[2] + 1]);
        }
        // the slot
        translate([-slot[0] / 2, -slot[1] / 2, -1]) cube([slot[0], slot[1], flange_t + 2]);
        // detent notches in the +x wall (V grooves)
        for (y = detents) translate([inner_w / 2, y, z_carr0 + carr[2] / 2]) rotate([0, 0, 45]) cube([1.8, 1.8, carr[2] + 2], center = true);
        // mount screws + nut pockets
        for (s = fl_screws) translate(s) {
            translate([0, 0, -1]) cylinder(d = m3_clear_d, h = flange_t + 2);
            translate([0, 0, flange_t - m3_nut_t - 0.6]) m3_nut_pocket(m3_nut_t + 1);
        }
        // pot: zip-tie slots + wire exit in the back plate
        for (y = [-20, 20]) for (s = [-1, 1]) translate([s * (pot_w / 2 + 2) - 1, y, z_back - 1]) cube([2, 4, 5]);
    }
}
pot_y0 = pot_shift - pot_len / 2;   // pot body ends (y)
pot_y1 = pot_shift + pot_len / 2;
// narrow channels that carry a pot longer than the housing: two walls standing
// on the panel back, bridged at the back (prints with the housing, flange down)
module pot_spines() for (r = [[pot_y0, -fl_size[1] / 2 + 1], [fl_size[1] / 2 - 1, pot_y1]]) if (r[1] > r[0])
    translate([-pot_w / 2 - 4, r[0], 0]) difference() {
        union() {
            translate([0, 0, z_back]) cube([pot_w + 8, r[1] - r[0], 3]);
            for (x = [0, pot_w + 6]) cube([2, r[1] - r[0], z_back + 0.01]);
        }
        translate([pot_w / 2, r[0] < 0 ? 2 : r[1] - r[0] - 6, z_back - 1]) {     // zip-tie slots
            translate([-pot_w / 2 - 3, 0, 0]) cube([2, 4, 5]);
            translate([pot_w / 2 + 1, 0, 0]) cube([2, 4, 5]);
        }
    }
// ------------------------------------------------------------------ carriage (+ stem)
module carriage() {
    difference() {
        union() {
            translate([-carr[0] / 2 + 1.5, -carr[1] / 2, z_carr0]) cube([carr[0] - 3, carr[1], carr[2]]);
            // stem forward through the flange and the panel
            translate([-stem[0] / 2, -stem[1] / 2, -panel_thickness - 10]) cube([stem[0], stem[1], z_carr0 + panel_thickness + 10.01]);
            // detent finger on the +x side: anchored at the bottom, bump near the top
            translate([carr[0] / 2 - 1.5, -carr[1] / 2, z_carr0]) cube([0.01, 3, carr[2]]);
            hull() {
                translate([carr[0] / 2 - 2, -carr[1] / 2, z_carr0]) cube([1.2, 3, carr[2]]);
                translate([carr[0] / 2 - 2, carr[1] / 2 - 4, z_carr0]) cube([1.2, 2, carr[2]]);
            }
            translate([carr[0] / 2 - 1, 0, z_carr0]) linear_extrude(carr[2]) polygon([[0, -1.6], [1.4, 0], [0, 1.6]]);   // bump
        }
        // gap that makes the finger springy
        translate([carr[0] / 2 - 3.5, -carr[1] / 2 + 3, z_carr0 - 1]) cube([1.2, carr[1] - 2, carr[2] + 2]);
        // pot lever slot (cross shape fits a flat lever either way)
        for (sz = [[5.4, 2.0], [2.0, 5.4]]) translate([-sz[0] / 2, -sz[1] / 2, z_carr1 - lever_engage - 0.5]) cube([sz[0], sz[1], lever_engage + 1]);
        // M3 into the stem front for the handle
        translate([0, 0, -panel_thickness - 11]) cylinder(d = m3_pilot_d, h = 10);
    }
}

// ------------------------------------------------------------------ handle (white, flap-shaped)
// Built in place: the stem front is at z = -panel_thickness - 10.
module handle() {
    z0 = -panel_thickness - 10;
    difference() {
        translate([0, 0, z0 - 20]) hull() {
            // wing-section profile seen from the side, extruded across (x)
            rotate([0, 90, 0]) linear_extrude(30, center = true) hull() {
                translate([-17, 0]) circle(d = 9);
                translate([-3, 0]) circle(d = 4);
            }
        }
        // socket for the stem
        translate([-stem[0] / 2 - 0.2, -stem[1] / 2 - 0.2, z0 - 6]) cube([stem[0] + 0.4, stem[1] + 0.4, 10]);
        // screw from the front
        translate([0, 0, z0 - 30]) cylinder(d = m3_clear_d, h = 30);
        translate([0, 0, z0 - 30]) cylinder(d = 6, h = 7.5);
    }
}

// ------------------------------------------------------------------ panel
// Front view (x = pilot's right): slot + mount holes. Scale engraving separately.
module panel_cutout() {
    square(slot + [0.6, 0.6], center = true);
    for (s = fl_screws) translate(s) circle(d = m3_clear_d);
}
// Engraving for the panel face, front view: FLAP, and UP / 10° / 20° / FULL on the left of the slot
module scale_2d() {
    f = "Liberation Sans:style=Bold";
    lab = ["UP", "10°", "20°", "FULL"];
    for (i = [0 : 3]) {
        translate([-slot[0] / 2 - 3, detents[i]]) text(lab[i], size = 3.4, font = f, halign = "right", valign = "center");
        translate([-slot[0] / 2 - 2.4, detents[i] - 0.35]) square([1.8, 0.7]);
    }
    translate([0, slot[1] / 2 + 6]) text("FLAP", size = 3.6, font = f, halign = "center", valign = "center");
}

module flap_cutout_2d() panel_cutout();
module flap_scale_2d_() scale_2d();
module flap_countersinks() for (sc = fl_screws) translate([sc[0], sc[1], -0.01])
    cylinder(d1 = m3_head_d + 0.4, d2 = m3_clear_d, h = (m3_head_d + 0.4 - m3_clear_d) / 2);

// ------------------------------------------------------------------ views
module pot_dummy(dy) {
    color("dimgray") translate([-pot_w / 2, pot_y0, z_pot_top]) cube([pot_w, pot_len, pot_h]);
    color("silver") translate([-2.5, dy - 0.6, z_carr1 - lever_engage]) cube([5, 1.2, pot_lever_h]);
}
// animation: UP -> 10 -> 20 -> FULL (a pause at each click), then back UP
fl_anim = [[0, 0], [0.06, 0], [0.14, 1], [0.24, 1], [0.32, 2], [0.42, 2], [0.50, 3], [0.66, 3], [0.90, 0], [1, 0]];
module flap_mounted(pos = position) {
    dy = anim >= 0 ? travel / 2 - lookup(anim, fl_anim) * step : detents[pos];
    color("darkorange", ghost_a()) { housing(); pot_spines(); }
    color("silver") for (sc = fl_screws) translate(sc) {
        translate([0, 0, -panel_thickness]) cylinder(d1 = m3_head_d, d2 = 3, h = 1.6);
        translate([0, 0, -panel_thickness]) cylinder(d = 3, h = mount_screw_len(panel_thickness, flange_t));
    }
    pot_dummy(dy);
    translate([0, dy, 0]) { color("goldenrod") carriage(); color([0.95, 0.95, 0.92]) handle(); }
}

module panel_slab() {
    color([0.12, 0.12, 0.13], ghost_a(0.55)) translate([0, 0, -panel_thickness]) linear_extrude(panel_thickness) difference() {
        square([90, 130], center = true);
        panel_cutout();
    }
    color("white") translate([0, 0, -panel_thickness - 0.2]) linear_extrude(0.2) mirror([1, 0]) scale_2d();
}

if (part == "assembly") rotate([90, 0, 0]) { panel_slab(); flap_mounted(); }
else if (part == "housing") { housing(); pot_spines(); }
else if (part == "carriage") rotate([180, 0, 0]) translate([0, 0, -z_carr1]) carriage();
else if (part == "handle") translate([0, 0, panel_thickness + 10 + 20]) handle();
else if (part == "panel_cutout") panel_cutout();

echo(str("Flap lever: detents every ", step, " mm (UP, 10, 20, FULL); uses ", round(100 * (0.5 + (-travel / 2 - pot_shift) / pot_travel)), "% to ", round(100 * (0.5 + (travel / 2 - pot_shift) / pot_travel)), "% of the pot's travel"));
if (travel / 2 + abs(pot_shift) > pot_travel / 2) echo("WARNING: the flap carriage runs past the end of the pot's travel - reduce pot_shift");
