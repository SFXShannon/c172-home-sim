// Smaller C172S panel parts.
//
//   ignition    a key in a lock face with a chrome-look bezel, on a 1-pole
//               12-position rotary switch (OFF R L BOTH START engraved on the
//               panel round it). Set the switch's stop washer to 5 positions.
//   knob_*      look-only push-pull knobs: ALT STATIC AIR (red), CABIN HT,
//               CABIN AIR, FUEL SHUTOFF (red, on the pedestal). A printed stem
//               goes through an 8.5 mm panel hole; a clip ring behind holds it.
//   cb_strip    a row block of circuit-breaker heads to glue on the lower panel
//   yoke_boot   trim ring with a rubber-boot look round the yoke shaft opening
//
// Modelled face-up (as seen from the seat), panel face at z = 0.

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, assembly_ignition, ignition_key, ignition_cylinder, ignition_escutcheon, knob_alt_static, knob_cabin_heat, knob_cabin_air, knob_fuel_shutoff, knob_stem, stem_clip, cb_strip, yoke_boot]

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
// A real-looking key in a lock face, on a 1P12T rotary switch (stop washer set to 5 positions).
//   ignition_escutcheon  chrome-look bezel round the lock, fixed: it hides the switch nut
//   ignition_cylinder    the lock face with its keyway; presses onto the switch shaft and turns
//   ignition_key         key with a black head; its tip pushes into the keyway (and pulls out again)
// Cut the switch shaft so it ends 9 mm in front of the panel face.

ign_esc_h   = 14;                   // bezel height off the panel
ign_cyl_d   = 16.6;                 // lock face diameter
ign_cyl_z0  = 4.5;                  // lock bottom, clear of the switch bushing + nut
ign_cyl_top = ign_esc_h + 0.4;      // lock face, just proud of the bezel
ign_insert  = 4.6;                  // how far the key goes into the keyway
key_w = 8; key_t = 2.4;             // blade width / thickness
key_tip = 5; key_blade = 17; key_neck = 19; key_len = 48;   // y stations along the key

// key, printed flat: x across the blade, y along it (tip at y = 0), z thickness (blade on the bed)
module key_head_2d() hull() {
    translate([0, key_neck + 2]) square([17, 4], center = true);
    translate([0, key_len - 14]) circle(d = 28, $fn = 96);
}
module key_metal() difference() {
    linear_extrude(key_t) union() {
        hull() {                                                  // tip that goes into the lock
            translate([0, 1]) square([key_w - 4, 2], center = true);
            translate([0, key_tip - 0.5]) square([key_w, 1], center = true);
        }
        difference() {                                            // blade with the cuts along one edge
            translate([-key_w / 2, key_tip - 1]) square([key_w, key_blade - key_tip + 1.01]);
            for (c = [[8, 1.6], [11, 2.4], [14, 1.2]]) translate([key_w / 2, c[0]]) rotate(45) square(c[1] * 1.414, center = true);
        }
        translate([-5.5, key_blade]) square([11, key_neck - key_blade + 3]);   // shoulder, runs into the head
    }
    translate([-1.6, 3, key_t - 0.45]) cube([1.2, key_blade - 3, 1]);           // milled groove
}
module key_head() difference() {
    union() {
        linear_extrude(4.2) key_head_2d();
        translate([0, 0, 4.19]) linear_extrude(0.6, scale = 0.94) offset(-1.2) key_head_2d();
    }
    translate([0, key_len - 6, -1]) cylinder(d = 6, h = 8);                      // key-ring hole
    translate([0, key_len - 18, 4.2]) scale([1, 0.65, 1]) cylinder(d = 15, h = 2); // grip recess
}
// print flat, as modelled (one colour, or swap to black at the head with a colour change at 2.4 mm)
module ignition_key() union() { key_metal(); key_head(); }

// lock face: keyway on top, D-bore for the switch shaft underneath. Prints as modelled.
module ignition_cylinder() {
    h = ign_cyl_top - ign_cyl_z0;
    difference() {
        union() {
            cylinder(d = ign_cyl_d, h = h - 0.6);
            translate([0, 0, h - 0.61]) cylinder(d1 = ign_cyl_d, d2 = ign_cyl_d - 1.2, h = 0.61);
        }
        // switch shaft: 6 mm with a flat (4.6 mm across)
        translate([0, 0, -0.01]) linear_extrude(h - ign_insert - 0.6) intersection() {
            circle(d = 6.15, $fn = 48);
            translate([-4, -3.2]) square([8, 1.6 + 4.6]);
        }
        // keyway: a snug fit for the key tip
        translate([0, 0, h - ign_insert]) linear_extrude(ign_insert + 1) square([key_t + 0.25, key_w + 0.25], center = true);
        translate([0, 0, h - 0.6]) linear_extrude(1, scale = 1.3) square([key_t + 0.25, key_w + 0.25], center = true);
        // face ring
        translate([0, 0, h - 0.3]) difference() { cylinder(d = ign_cyl_d - 3, h = 1); cylinder(d = ign_cyl_d - 3.8, h = 1); }
    }
}

module ignition_escutcheon() {   // fixed bezel round the lock; hides the switch nut
    difference() {
        union() {
            cylinder(d = 30, h = 2.5);
            translate([0, 0, 2.49]) cylinder(d1 = 27, d2 = 22.5, h = ign_esc_h - 2.49 - 1);
            translate([0, 0, ign_esc_h - 1.01]) cylinder(d1 = 22.5, d2 = 21, h = 1.01);
        }
        translate([0, 0, -1]) cylinder(d = 15, h = 4.6);                    // nut pocket
        translate([0, 0, -1]) cylinder(d = 10.4, h = ign_esc_h + 2);       // switch bushing
        translate([0, 0, ign_cyl_z0 - 0.6]) cylinder(d = ign_cyl_d + 0.5, h = ign_esc_h);   // the lock turns in here
    }
}

// key in the lock, in panel coordinates (key width points at the position label)
module ignition_key_in_lock() {
    translate([0, 0, ign_cyl_top - ign_insert]) multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1]])
        translate([0, 0, -key_t / 2]) children();
}

// 2D: OFF R L BOTH START round the key (engrave into the panel)
module ignition_labels_2d() {
    for (p = ign_positions) rotate(-p[1]) translate([0, 23]) text(p[0], size = 2.6, font = f, halign = "center", valign = "center");
    for (p = ign_positions) rotate(-p[1]) translate([-0.4, 16]) square([0.8, 3.5]);
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
// demo animation (README GIF): key angle, OFF -60 / R -30 / L 0 / BOTH 30 / START 60 (springs back to BOTH)
ign_anim = [[0, -60], [0.08, -60], [0.15, -30], [0.25, -30], [0.32, 0], [0.42, 0], [0.49, 30], [0.59, 30],
            [0.65, 60], [0.75, 60], [0.79, 30], [0.88, 30], [0.96, -60], [1, -60]];
function ign_angle() = anim < 0 ? 30 : lookup(anim, ign_anim);   // BOTH when not animating
module ignition_mounted() {
    color([0.78, 0.79, 0.81]) ignition_escutcheon();
    rotate(-ign_angle()) {
        color([0.62, 0.63, 0.65]) translate([0, 0, ign_cyl_z0]) ignition_cylinder();
        // blade silver, head black
        color([0.8, 0.8, 0.78]) ignition_key_in_lock() key_metal();
        color([0.08, 0.08, 0.09]) ignition_key_in_lock() key_head();
    }
}
// key switch behind the panel (look only): 5-position rotary switch, white mark on the rotor
module ignition_switch_dummy(t = panel_thickness) {
    color("silver") translate([0, 0, -t - 8]) cylinder(d = 6, h = t + 10);
    color([0.15, 0.15, 0.15], ghost_a(0.85)) translate([0, 0, -t - 22]) cylinder(d = 28, h = 14);
    color("silver") translate([0, 0, -t - 25]) cylinder(d = 6, h = 4);
    rotate(-ign_angle()) color("white") translate([-1, 0, -t - 25.5]) cube([2, 11, 1]);
}
module ignition_demo() {
    t = panel_thickness;
    color([0.11, 0.11, 0.12], ghost_a(0.6)) translate([0, 0, -t]) linear_extrude(t) difference() { square([80, 70], center = true); circle(d = 10); }
    color("white") translate([0, 0, 0.01]) linear_extrude(0.2) ignition_labels_2d();
    ignition_mounted();
    ignition_switch_dummy(t);
}
module knob_mounted(kind) {
    c = (kind == "alt" || kind == "fuel") ? [0.75, 0.1, 0.1] : [0.1, 0.1, 0.1];
    color("silver") cylinder(d = 6, h = 4);
    color(c) translate([0, 0, 4 + 4 + (kind == "fuel" ? 12 : kind == "alt" ? 10 : 9)]) rotate([0, 180, 0]) {
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
    // the key on its own, lying flat
    translate([70, -75, 0]) rotate(-90) { color([0.8, 0.8, 0.78]) key_metal(); color([0.08, 0.08, 0.09]) key_head(); }
}
else if (part == "assembly_ignition") ignition_demo();
else if (part == "ignition_key") ignition_key();
else if (part == "ignition_cylinder") ignition_cylinder();
else if (part == "ignition_escutcheon") ignition_escutcheon();
else if (part == "knob_alt_static") knob_alt_static();
else if (part == "knob_cabin_heat") knob_cabin_heat();
else if (part == "knob_cabin_air") knob_cabin_air();
else if (part == "knob_fuel_shutoff") knob_fuel_shutoff();
else if (part == "knob_stem") knob_stem();
else if (part == "stem_clip") stem_clip();
else if (part == "cb_strip") cb_strip();
else if (part == "yoke_boot") yoke_boot();
