// Smaller C172S panel parts.
//
//   ignition    key-shaped knob + chrome escutcheon on a 1-pole 12-position rotary
//               switch (OFF R L BOTH START engraved on the panel round it).
//               Set the switch's stop washer to 5 positions.
//   knob_*      look-only push-pull knobs: ALT STATIC AIR (red), CABIN HT,
//               CABIN AIR, FUEL SHUTOFF (red, on the pedestal). A printed stem
//               goes through an 8.5 mm panel hole; a clip ring behind holds it.
//   cb_strip    a row block of circuit-breaker heads to glue on the lower panel
//   yoke_boot   trim ring with a rubber-boot look round the yoke shaft opening
//
// Modelled face-up (as seen from the seat), panel face at z = 0.

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, ignition_key, ignition_escutcheon, knob_alt_static, knob_cabin_heat, knob_cabin_air, knob_fuel_shutoff, knob_stem, stem_clip, cb_strip, yoke_boot]

/* [Yoke opening] */
// Diameter of the hole the yoke shaft passes through
yoke_hole_d = 60;

/* [Circuit breakers] */
cb_cols = 7;
cb_rows = 3;

/* [Hidden] */
f = "Liberation Sans:style=Bold";
ign_positions = [["OFF", -60], ["R", -30], ["L", 0], ["BOTH", 30], ["START", 60]];

// ------------------------------------------------------------------ ignition
// Key head on a hub that presses onto the switch's 6 mm (knurled) shaft. Printed flat.
module ignition_key() {
    difference() {
        union() {
            cylinder(d = 11, h = 9);
            hull() {                                   // the key bow
                translate([0, 0, 0]) cylinder(d = 11, h = 3.5);
                translate([0, 15, 0]) scale([1, 0.75, 1]) cylinder(d = 24, h = 3.5);
            }
        }
        translate([0, 0, 2]) cylinder(d = 5.9, h = 10);
        translate([0, 17, -1]) cylinder(d = 7, h = 6);   // key-ring hole
    }
}
module ignition_escutcheon() {   // hides the switch nut, sits on the panel
    difference() {
        union() { cylinder(d = 26, h = 4); translate([0, 0, 4]) cylinder(d1 = 26, d2 = 22, h = 2); }
        translate([0, 0, -1]) cylinder(d = 15, h = 3.6);        // nut pocket
        translate([0, 0, -1]) cylinder(d = 7, h = 10);          // shaft
        translate([-1.2, 7, 5]) cube([2.4, 5, 2]);               // keyway look
    }
}
// 2D: OFF R L BOTH START round the key (engrave into the panel)
module ignition_labels_2d() {
    for (p = ign_positions) rotate(-p[1]) translate([0, 20]) text(p[0], size = 3.2, font = f, halign = "center", valign = "center");
    for (p = ign_positions) rotate(-p[1]) translate([-0.4, 14.5]) square([0.8, 3]);
}

// ------------------------------------------------------------------ look-only knobs
module knob_body(d, h, ribbed = false) {
    if (ribbed) ribbed_cylinder(d / 2, h, n = 24, depth = 0.6); else cylinder(d = d, h = h);
}
module knob_with_label(d, h, txt, ribbed = false, tsize = 2.4) {
    difference() {
        union() {
            knob_body(d, h, ribbed);
            translate([0, 0, h - 0.01]) cylinder(d1 = d * 0.6, d2 = d * 0.45, h = 4);   // neck
        }
        translate([0, 0, h - 2]) cylinder(d = 6.3, h = 8);        // stem socket
        if (len(txt) > 0) translate([0, 0, -0.01]) linear_extrude(0.6) mirror([1, 0])
            text(txt, size = tsize, font = f, halign = "center", valign = "center");
    }
}
// Printed face-down: the label is on the bed side, reads correctly from the front.
module knob_alt_static()   knob_with_label(16, 10, "ALT", true, 3.2);
module knob_cabin_heat()   knob_with_label(24, 9, "HEAT", false, 3.4);
module knob_cabin_air()    knob_with_label(24, 9, "AIR", false, 3.4);
module knob_fuel_shutoff() knob_with_label(26, 12, "FUEL", true, 3.6);

// Stem: 6 mm, goes through the 8.5 mm panel hole, clip ring snaps on behind.
module knob_stem() {
    difference() {
        union() {
            cylinder(d = 6, h = 6 + panel_thickness + 8);
            translate([0, 0, 6]) cylinder(d = 10, h = 1.5);       // stop on the panel face
        }
        translate([0, 0, 6 + panel_thickness + 3]) rotate_extrude() translate([3, 0]) square([1, 1.6]);   // groove for the clip
    }
}
module stem_clip() {
    difference() {
        cylinder(d = 14, h = 1.5);
        translate([0, 0, -1]) cylinder(d = 4.2, h = 4);
        translate([-1.5, 0, -1]) cube([3, 10, 4]);
    }
}

// ------------------------------------------------------------------ circuit breakers
module cb_strip(cols = cb_cols, rows = cb_rows) {
    p = 11;
    w = cols * p + 4; h = rows * p + 4;
    difference() {
        linear_extrude(2) rounded_rect([w, h], 2);
    }
    for (c = [0 : cols - 1], r = [0 : rows - 1]) translate([(c - (cols - 1) / 2) * p, (r - (rows - 1) / 2) * p, 2 - 0.01]) {
        cylinder(d = 8.5, h = 1.2);                    // collar
        difference() {
            cylinder(d = 6.2, h = 5);                   // push button
            translate([0, 0, 4.4]) cylinder(d = 3.2, h = 1);
        }
    }
}
function cb_strip_size(cols = cb_cols, rows = cb_rows) = [cols * 11 + 4, rows * 11 + 4];

// ------------------------------------------------------------------ yoke boot
module yoke_boot() {
    difference() {
        union() {
            cylinder(d = yoke_hole_d + 24, h = 2.5);
            for (i = [0 : 3]) translate([0, 0, 2.5 + i * 1.6]) cylinder(d1 = yoke_hole_d + 16 - i * 3, d2 = yoke_hole_d + 12 - i * 3, h = 1.61);
        }
        translate([0, 0, -1]) cylinder(d = yoke_hole_d - 2, h = 20);
        for (a = [0, 120, 240]) rotate([0, 0, a]) translate([yoke_hole_d / 2 + 7.5, 0, -1]) {
            cylinder(d = m3_clear_d, h = 5);
            translate([0, 0, 3.5 - 1.6]) cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.4, h = 1.61);
        }
    }
}
module yoke_boot_screw_holes_2d() for (a = [0, 120, 240]) rotate(a) translate([yoke_hole_d / 2 + 7.5, 0]) circle(d = m3_pilot_d);

// ------------------------------------------------------------------ mounted (for the dashboard renders)
module ignition_mounted() {
    color([0.75, 0.76, 0.78]) ignition_escutcheon();
    color([0.75, 0.76, 0.78]) translate([0, 0, 15]) mirror([0, 0, 1]) rotate([0, 0, 0]) translate([0, 0, 0]) ignition_key();
}
module knob_mounted(kind) {
    c = (kind == "alt" || kind == "fuel") ? [0.75, 0.1, 0.1] : [0.1, 0.1, 0.1];
    color("silver") cylinder(d = 6, h = 4);
    color(c) translate([0, 0, 4 + 4 + (kind == "fuel" ? 12 : kind == "alt" ? 10 : 9)]) mirror([0, 0, 1]) {
        if (kind == "alt") knob_alt_static();
        else if (kind == "heat") knob_cabin_heat();
        else if (kind == "air") knob_cabin_air();
        else knob_fuel_shutoff();
    }
}

if (part == "assembly") {
    ignition_mounted();
    translate([40, 0]) knob_mounted("alt");
    translate([75, 0]) knob_mounted("heat");
    translate([110, 0]) knob_mounted("fuel");
    color([0.15, 0.15, 0.15]) translate([0, -50]) cb_strip();
    color([0.1, 0.1, 0.1]) translate([120, -60]) yoke_boot();
}
else if (part == "ignition_key") ignition_key();
else if (part == "ignition_escutcheon") ignition_escutcheon();
else if (part == "knob_alt_static") knob_alt_static();
else if (part == "knob_cabin_heat") knob_cabin_heat();
else if (part == "knob_cabin_air") knob_cabin_air();
else if (part == "knob_fuel_shutoff") knob_fuel_shutoff();
else if (part == "knob_stem") knob_stem();
else if (part == "stem_clip") stem_clip();
else if (part == "cb_strip") cb_strip();
else if (part == "yoke_boot") yoke_boot();
