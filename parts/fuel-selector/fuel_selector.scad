// Cessna 172-style FUEL SELECTOR (floor of the pedestal)
//
// Outside: a pointer handle over a LEFT / BOTH / RIGHT placard (172S style).
// Set has_off = true for an older-172 style placard with OFF at the back.
//
// Inside (kept simple): the handle turns a small gear that drives a larger gear
// on a standard 1-pole 12-position rotary switch (3:1). The switch clicks every
// 30 deg, so the handle clicks every 90 deg - one click per tank position.
// Printed stops limit the handle to LEFT..RIGHT.
//
// Coordinates: the "panel" here is the floor plate. Panel front (cabin side) at
// z = -panel_thickness, back (under the floor) at z = 0. +y = forward, +x = pilot's left.
//
// Render one part:  openscad -D 'part="handle"' -o handle.stl fuel_selector.scad

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, exploded, handle, shaft, handle_gear, switch_gear, housing, switch_bracket, placard, panel_test_plate, panel_cutout]
// Which tank the handle points at in the assembly view
show_position = "both"; // [left, both, right, off]

/* [Options] */
// Add an OFF position at the back (older 172s). Removes the printed stops.
has_off = false;

/* [Hidden] */
gm         = 1.5;      // gear module
z_small    = 12;       // handle gear teeth
z_big      = 36;       // switch gear teeth
centre     = gm * (z_small + z_big) / 2 + 0.25;
sw_pos     = [0, -centre];
shaft_d    = 12;
flat       = 1;
placard_t  = 2;
handle_h   = 20;
socket     = 12;
boss_len   = 12;
boss_d     = 22;
gear_t     = 6;
z_gear0    = boss_len + 0.3;           // handle gear / switch gear plane starts here
z_gear1    = z_gear0 + gear_t;
arm_t      = 3.7;
z_arm1     = z_gear1 + arm_t;
z_bracket  = 26;                       // switch bracket underside
bracket_t  = 3;
panel_hole_d = 16;
z_handle_bottom = -(panel_thickness + placard_t + 0.6 + 1);   // clear the raised placard lettering
shaft_top  = z_handle_bottom - socket + 0.5;
post_x     = gm * z_big / 2 + gm + 5.5;     // posts just outside the big gear
stop_r     = 14;
stop_angles = [-22, 202];
flange_y0  = sw_pos[1] - 14;
flange_y1  = mount_flange_size / 2;
flange_x   = post_x + 5;

pos_angle = anim >= 0 ? lookup(anim, [[0, 0], [0.08, 0], [0.2, -90], [0.38, -90], [0.5, 0], [0.58, 0], [0.7, 90], [0.88, 90], [1, 0]])
          : show_position == "left" ? -90 : show_position == "right" ? 90 : show_position == "off" ? 180 : 0;

// ------------------------------------------------------------------ handle
// Print coordinates: flat bottom on the bed, pointer along +y.

module handle_outline() {
    union() {
        hull() { circle(r = 15); translate([0, 62]) circle(r = 5); }
        hull() { circle(r = 15); translate([0, -35]) circle(r = 10); }
    }
}

module handle() {
    c = 4;
    difference() {
        hull() {
            linear_extrude(handle_h - c) handle_outline();
            linear_extrude(handle_h) offset(-c) handle_outline();
        }
        // D socket for the shaft (flat toward the pointer)
        translate([0, 0, -0.01]) linear_extrude(socket) difference() {
            circle(d = shaft_d + 2 * clearance);
            translate([-shaft_d, shaft_d/2 - flat + clearance]) square([2 * shaft_d, shaft_d]);
        }
        // countersunk M3 screw from the top into the shaft
        cylinder(d = m3_clear_d, h = handle_h + 1);
        translate([0, 0, handle_h - 2.2]) cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.6, h = 2.21);
        // pointer line
        translate([-0.8, 22, handle_h - 0.8]) cube([1.6, 38, 1]);
    }
}

module handle_placed() {
    translate([0, 0, z_handle_bottom]) rotate([0, 180, 0]) handle();
}

// ------------------------------------------------------------------ shaft
module shaft() {
    difference() {
        translate([0, 0, shaft_top]) linear_extrude(z_gear1 - shaft_top) difference() {
            circle(d = shaft_d);
            translate([-shaft_d, shaft_d/2 - flat]) square([2 * shaft_d, shaft_d]);
        }
        // M3 pilot holes both ends (handle screw on top, gear screw underneath)
        translate([0, 0, shaft_top - 1]) cylinder(d = m3_pilot_d, h = 14);
        translate([0, 0, z_gear1 - 13]) cylinder(d = m3_pilot_d, h = 14);
    }
}

// ------------------------------------------------------------------ gears
module handle_gear() {
    difference() {
        union() {
            translate([0, 0, z_gear0]) spur_gear(gm, z_small, gear_t);
            // stop arm (points the same way as the handle)
            if (!has_off) translate([-2, 0, z_gear1 - 0.01]) cube([4, stop_r + 2, arm_t]);
            translate([0, 0, z_gear1 - 0.01]) cylinder(d = 12, h = arm_t);
        }
        translate([0, 0, z_gear0 - 1]) linear_extrude(gear_t + 1.01) difference() {
            circle(d = shaft_d + 2 * clearance);
            translate([-shaft_d, shaft_d/2 - flat + clearance]) square([2 * shaft_d, shaft_d]);
        }
        translate([0, 0, z_gear1 - 1]) cylinder(d = m3_clear_d, h = arm_t + 2);
    }
}

// Knurled 6 mm switch shafts press into the 5.9 mm bore; open it up with a
// drill if your shaft is smooth/D and add glue.
module switch_gear() {
    translate(sw_pos) difference() {
        union() {
            translate([0, 0, z_gear0]) spur_gear(gm, z_big, gear_t);
            translate([0, 0, z_gear0 - 3]) cylinder(d = 12, h = 3.01);
        }
        translate([0, 0, z_gear0 - 4]) cylinder(d = 5.9, h = gear_t + 6);
        // lightening holes
        for (a = [0 : 60 : 359]) rotate([0, 0, a]) translate([16, 0, z_gear0 - 1]) cylinder(d = 8, h = gear_t + 2);
    }
}

// ------------------------------------------------------------------ housing
// Flange under the floor + bearing boss + stop columns + two posts for the
// switch bracket. Prints flange-down.

module housing() {
    difference() {
        union() {
            translate([-flange_x, flange_y0, 0]) linear_extrude(mount_flange_t)
                translate([flange_x, (flange_y1 - flange_y0) / 2]) rounded_rect([2 * flange_x, flange_y1 - flange_y0], 5);
            cylinder(d = boss_d, h = boss_len);
            if (!has_off) for (a = stop_angles) rotate([0, 0, a]) translate([stop_r - 2, -2, 0]) cube([4, 4, z_arm1 + 0.5]);
            for (s = [-1, 1]) translate([s * post_x - 4, sw_pos[1] - 4, 0]) cube([8, 8, z_bracket]);
        }
        translate([0, 0, -1]) cylinder(d = shaft_d + 0.5, h = boss_len + 2);
        mount_flange_holes();
        // clearance for a long switch shaft
        translate([sw_pos[0], sw_pos[1], -1]) cylinder(d = 10, h = mount_flange_t + 2);
        for (s = [-1, 1]) translate([s * post_x, sw_pos[1], z_bracket - 12]) cylinder(d = m3_tap_d(), h = 13);
        translate([0, flange_y1 - 4, mount_flange_t - 0.6]) linear_extrude(1)
            text("FWD", size = 3.5, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
}

// Holds the rotary switch (3/8" / M9-M10 bushing). Screws onto the posts.
module switch_bracket() {
    difference() {
        translate([-post_x - 5, sw_pos[1] - 10, z_bracket]) cube([2 * post_x + 10, 20, bracket_t]);
        translate([sw_pos[0], sw_pos[1], z_bracket - 1]) cylinder(d = 9.8, h = bracket_t + 2);
        // slot for the switch's anti-rotation tab (bend it off if it doesn't fit)
        translate([sw_pos[0] - 1.25, sw_pos[1] + 6, z_bracket - 1]) cube([2.5, 3.5, bracket_t + 2]);
        for (s = [-1, 1]) translate([s * post_x, sw_pos[1], z_bracket - 1]) cylinder(d = m3_clear_d, h = bracket_t + 2);
    }
}

// ------------------------------------------------------------------ placard
// Print coordinates: face up. Raised white lettering on a dark plate.

module placard_text() {
    f = "Liberation Sans:style=Bold";
    translate([0, 48]) text("BOTH", size = 7, halign = "center", valign = "center", font = f);
    translate([-46, 0]) text("LEFT", size = 7, halign = "center", valign = "center", font = f);
    translate([46, 0]) text("RIGHT", size = 7, halign = "center", valign = "center", font = f);
    if (has_off) translate([0, -48]) text("OFF", size = 7, halign = "center", valign = "center", font = f);
    translate([0, has_off ? -58 : -42]) text("FUEL SELECTOR", size = 4.5, halign = "center", valign = "center", font = f);
    // index marks
    for (a = has_off ? [0, 90, 180, 270] : [0, 90, 180]) rotate(a) translate([24, -0.75]) square([8, 1.5]);
}

module placard() {
    w = 130; h = has_off ? 132 : 116;
    yc = has_off ? 0 : 6;
    difference() {
        translate([0, yc]) linear_extrude(placard_t) rounded_rect([w, h], 6);
        translate([0, 0, -1]) cylinder(d = shaft_d + 1.5, h = placard_t + 2);
    }
    translate([0, 0, placard_t - 0.01]) linear_extrude(0.6) placard_text();
}

module placard_placed() {
    translate([0, 0, -panel_thickness]) rotate([0, 180, 0]) placard();
}

// ------------------------------------------------------------------ panel bits
module panel_cutout() {
    circle(d = panel_hole_d);
    mount_panel_holes();
    for (r = [0, 90]) rotate(r) square([60, 0.3], center = true);
}

module panel_test_plate() {
    difference() {
        linear_extrude(panel_thickness) difference() {
            translate([0, 6]) rounded_rect([140, 130], 6);
            circle(d = panel_hole_d);
            mount_panel_holes();
        }
        mount_panel_countersinks();
    }
}

// ------------------------------------------------------------------ views
module panel_slab() {
    color([0.30, 0.31, 0.33], ghost_a(0.55)) difference() {
        translate([0, 0, -panel_thickness]) linear_extrude(panel_thickness) difference() {
            translate([-85, -80]) square([170, 160]);
            circle(d = panel_hole_d);
            mount_panel_holes();
        }
        translate([0, 0, -panel_thickness]) mount_panel_countersinks();
    }
}

module switch_dummy() {
    translate([sw_pos[0], sw_pos[1], z_bracket + bracket_t]) color("dimgray") cylinder(d = 26, h = 16);
    translate([sw_pos[0], sw_pos[1], z_gear0 - 3]) color("silver") cylinder(d = 6, h = z_bracket - z_gear0 + 3);
    translate([sw_pos[0], sw_pos[1], z_bracket - 6.5]) color("silver") cylinder(d = 9.5, h = 6.5);
}

module assembly(slab = true) {
    if (slab) panel_slab();
    color([0.12, 0.12, 0.12]) placard_placed();
    color("darkorange", ghost_a()) housing();
    color("goldenrod", ghost_a()) switch_bracket();
    mount_hardware_dummy(panel_thickness);
    switch_dummy();
    rotate([0, 0, pos_angle]) {
        color([0.92, 0.92, 0.9]) handle_placed();
        color("silver") shaft();
        color("goldenrod") handle_gear();
    }
    color("goldenrod") translate(sw_pos) rotate([0, 0, -pos_angle / 3 + 5]) translate(-sw_pos) switch_gear();
}

// For the panel layout files (panel/*.scad), which `use` this file.
module fuel_selector_mounted() assembly(slab = false);
module fuel_selector_panel_cutout() { circle(d = panel_hole_d); mount_panel_holes(); }
module fuel_selector_panel_countersinks() mount_panel_countersinks();

module exploded() {
    panel_slab();
    color([0.12, 0.12, 0.12]) translate([0, 0, -20]) placard_placed();
    color([0.92, 0.92, 0.9]) translate([0, 0, -60]) handle_placed();
    color("silver") translate([0, 0, 60]) shaft();
    color("darkorange") translate([0, 0, 40]) housing();
    color("goldenrod") translate([0, 0, 120]) handle_gear();
    color("goldenrod") translate([0, 0, 120]) switch_gear();
    color("goldenrod") translate([0, 0, 150]) switch_bracket();
}

// Views: floor plate seen from above and behind the pilot's seat.
if (part == "assembly") rotate([180, 0, 0]) assembly();
else if (part == "exploded") rotate([180, 0, 0]) exploded();
else if (part == "handle") handle();
else if (part == "shaft") rotate([180, 0, 0]) translate([0, 0, -z_gear1]) shaft();
else if (part == "handle_gear") translate([0, 0, -z_gear0]) handle_gear();
else if (part == "switch_gear") rotate([180, 0, 0]) translate([-sw_pos[0], -sw_pos[1], -z_gear1]) switch_gear();
else if (part == "housing") housing();
else if (part == "switch_bracket") translate([0, 0, -z_bracket]) switch_bracket();
else if (part == "placard") placard();
else if (part == "panel_test_plate") panel_test_plate();
else if (part == "panel_cutout") panel_cutout();

echo(str("Fuel selector: 1P12T rotary switch, shaft >= ", ceil(z_bracket + bracket_t - (z_gear0 - 3)), " mm long from its mounting face (cut longer ones)"));
echo(str("Fuel selector: 2x M3 x 12 (handle + gear), 2x M3 x 8 (bracket), 4x M3 x ", mount_screw_len(panel_thickness), " countersunk + nuts"));
