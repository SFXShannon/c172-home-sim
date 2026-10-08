// Cessna 172-style ELEVATOR TRIM WHEEL for a home sim pedestal
//
// Outside: a black wheel with cross ridges sticking out of a slot in the
// pedestal face, with a NOSE DN / TAKEOFF / NOSE UP placard beside it.
// Roll it forward (top away from you) for nose down, like the real one.
//
// Inside (kept simple): the wheel spins on an M8 bolt in two 608 skateboard
// bearings. A gear moulded onto the side of the wheel turns a small gear on an
// EC11 rotary encoder (3:1, so you get fine trim steps).
//
// Render one part:  openscad -D 'part="wheel"' -o wheel.stl trim_wheel.scad

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, exploded, wheel, housing, encoder_gear, placard, panel_test_plate, panel_cutout]

/* [Wheel] */
wheel_d = 110;
wheel_w = 22;
// How far the wheel sticks out in front of the panel face
expose = 18;
ridges = 40;

/* [Hidden] */
R        = wheel_d / 2;
gear_m   = 1;
wheel_gear_z = 48;   // must stay behind the panel: tip radius < axle depth
enc_gear_z   = 16;   // 3:1
gear_t   = 5;
backlash = 0.25;
centre_dist = gear_m * (wheel_gear_z + enc_gear_z) / 2 + backlash;
z_c      = R - expose - panel_thickness;     // axle, behind the panel back face (z = 0)
bearing_d = 22; bearing_w = 7; bearing_bore = 8;
x_wheel  = wheel_w / 2;                       // wheel faces at +/- x_wheel
x_gear1  = x_wheel + gear_t;                  // outer face of the wheel gear
wall_t   = 4;
x_wall_p = x_gear1 + 4;                       // +x wall inner face (room for the encoder bushing + nut)
x_wall_n = -(x_wheel + 1.5);                  // -x wall inner face
y_half   = R + 4;                             // housing half height
plate_t  = 5;
// the wheel is widest where it crosses the back of the housing plate, so size the slot there
slot_len = 2 * sqrt(R * R - (z_c - 5) * (z_c - 5)) + 6;
slot_w   = wheel_w + 4;
enc_pos  = [0, z_c + centre_dist];            // (y, z) of the encoder shaft
enc_hole = 7.2;                               // EC11 M7 bushing
flange_x1 = x_wall_p + wall_t + 8; flange_x0 = -flange_x1;
hole_x   = flange_x1 - 5; hole_y = y_half - 4; // flange screw positions

// ------------------------------------------------------------------ wheel
// Modelled with its axle along +z for printing (gear side up); assembly turns it.

module wheel_local() {
    difference() {
        union() {
            // rim with cross ridges, like the real wheel's tread
            cylinder(r = R - 1.5, h = wheel_w, $fn = 160);
            for (i = [0 : ridges - 1]) rotate([0, 0, i * 360 / ridges])
                translate([R - 2, -1.4, 0]) hull() {
                    cube([0.1, 2.8, wheel_w]);
                    translate([1.9, 0.5, 0.8]) cube([0.1, 1.8, wheel_w - 1.6]);
                }
            // gear on the top face
            translate([0, 0, wheel_w - 0.01]) spur_gear(gear_m, wheel_gear_z, gear_t);
        }
        // bearing seats both sides + through bore
        translate([0, 0, -0.01]) cylinder(d = bearing_d + 0.15, h = bearing_w);
        translate([0, 0, wheel_w + gear_t - bearing_w - gear_t + 0.01]) cylinder(d = bearing_d + 0.15, h = bearing_w + gear_t);
        cylinder(d = bearing_d - 3, h = 100, center = true);
        // dished faces (the real wheel is thinner in the middle) - only on the plain side
        translate([0, 0, -0.01]) difference() {
            cylinder(r = R - 8, h = 2);
            cylinder(r = 17, h = 2);
        }
        // clear the inside of the gear ring down to the bearing so the boss can reach it
        translate([0, 0, wheel_w]) cylinder(r = 15, h = gear_t + 1);
    }
}

// in assembly coords: axle along x, gear on +x side
module wheel() {
    translate([-x_wheel, 0, z_c]) rotate([0, 90, 0]) rotate([0, 0, 0]) wheel_local();
}

// ------------------------------------------------------------------ encoder gear
module encoder_gear() {
    difference() {
        union() {
            spur_gear(gear_m, enc_gear_z, gear_t);
        }
        // 6 mm D shaft (EC11)
        translate([0, 0, -1]) linear_extrude(gear_t + 6) difference() {
            circle(d = 6.15);
            translate([-5, 1.6]) square([10, 5]);   // 4.5 mm across the flat
        }
    }
}

// ------------------------------------------------------------------ housing
// Front plate (behind the panel) + two side walls. Prints front plate down.

module wall_profile(enc) {   // 2D in (y, z)
    hull() {
        translate([-y_half, 0]) square([2 * y_half, 1]);
        translate([0, z_c]) circle(r = 15);
        if (enc) translate(enc_pos) circle(r = 11);
    }
}

module housing() {
    difference() {
        union() {
            // front plate
            translate([flange_x0, -y_half, 0]) cube([flange_x1 - flange_x0, 2 * y_half, plate_t]);
            // side walls
            // 2D (y, z) profile -> wall of thickness wall_t along x
            translate([x_wall_p, 0, 0]) multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0]]) linear_extrude(wall_t) wall_profile(true);
            translate([x_wall_n - wall_t, 0, 0]) multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0]]) linear_extrude(wall_t) wall_profile(false);
            // bosses that press on the bearing inner races (centre the wheel)
            translate([x_wall_n - 0.01, 0, z_c]) rotate([0, 90, 0]) cylinder(d = 12, h = (-x_wheel - 0.3) - x_wall_n);
            translate([x_wheel + 0.3, 0, z_c]) rotate([0, 90, 0]) cylinder(d = 12, h = x_wall_p - x_wheel - 0.3 + 0.01);
        }
        // wheel slot
        translate([-slot_w/2, -slot_len/2, -1]) cube([slot_w, slot_len, plate_t + 2]);
        // axle
        translate([x_wall_n - wall_t - 1, 0, z_c]) rotate([0, 90, 0]) cylinder(d = 8.4, h = 100);
        // encoder
        translate([x_wall_p - 1, enc_pos[0], enc_pos[1]]) rotate([0, 90, 0]) cylinder(d = enc_hole, h = wall_t + 2);
        // flange screws + nuts
        for (x = [-hole_x, hole_x], y = [-hole_y, hole_y]) translate([x, y, 0]) {
            translate([0, 0, -1]) cylinder(d = m3_clear_d, h = plate_t + 2);
            translate([0, 0, plate_t - m3_nut_t - 0.6]) m3_nut_pocket(m3_nut_t + 1);
        }
    }
}

// ------------------------------------------------------------------ placard
// Sits on the panel face to the left of the wheel slot. Raised letters: paint
// the plate black and dry-brush the letters white.

module placard() {
    w = 24; h = slot_len;
    translate([0, 0, 0]) {
        linear_extrude(1.2) rounded_rect([w, h], 2);
        translate([0, 0, 1.2]) linear_extrude(0.6) {
            translate([0, h/2 - 6]) text("NOSE", size = 3.4, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
            translate([0, h/2 - 11]) text("DN", size = 3.4, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
            translate([0, h/2 - 17]) polygon([[-3, -2], [3, -2], [0, 2]]);
            // takeoff mark slightly nose-up of centre, like the real indicator
            translate([0, -6]) {
                translate([-w/2 + 1.5, -0.4]) square([5, 0.8]);
                text("T.O.", size = 3.4, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
            }
            translate([0, -h/2 + 17]) polygon([[-3, 2], [3, 2], [0, -2]]);
            translate([0, -h/2 + 11]) text("NOSE", size = 3.4, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
            translate([0, -h/2 + 6]) text("UP", size = 3.4, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        }
    }
}

// ------------------------------------------------------------------ panel bits

module panel_cutout() {
    translate([0, 0]) rounded_rect([slot_w, slot_len], 4);
    for (x = [-hole_x, hole_x], y = [-hole_y, hole_y]) translate([x, y]) circle(d = m3_clear_d);
    // placard outline (left of the wheel as the pilot sees it)
    translate([slot_w/2 + 18, 0]) difference() { rounded_rect([24.6, slot_len + 0.6], 2); rounded_rect([24, slot_len], 2); }
}

module panel_test_plate() {
    difference() {
        linear_extrude(panel_thickness) difference() {
            rounded_rect([flange_x1 - flange_x0 + 50, 2 * y_half + 20], 4);
            rounded_rect([slot_w, slot_len], 4);
            for (x = [-hole_x, hole_x], y = [-hole_y, hole_y]) translate([x, y]) circle(d = m3_clear_d);
        }
        for (x = [-hole_x, hole_x], y = [-hole_y, hole_y]) translate([x, y, -0.01])
            cylinder(d1 = m3_head_d + 0.4, d2 = m3_clear_d, h = (m3_head_d + 0.4 - m3_clear_d) / 2);
    }
}

// ------------------------------------------------------------------ views

module panel_slab() {
    color([0.30, 0.31, 0.33], ghost_a(0.55)) translate([0, 0, -panel_thickness]) linear_extrude(panel_thickness) difference() {
        translate([-90, -85]) square([180, 170]);
        rounded_rect([slot_w, slot_len], 4);
    }
}

module encoder_dummy() {
    translate([x_wall_p + wall_t, enc_pos[0], enc_pos[1]]) rotate([0, 90, 0]) {
        color("dimgray") translate([-6, -6.2, 0]) cube([12, 12.4, 6.5]);
        color("silver") translate([0, 0, -wall_t - 0.01]) cylinder(d = 7, h = wall_t);
        color("silver") translate([0, 0, -(x_wall_p + wall_t - x_wheel - 0.5)]) cylinder(d = 6, h = x_wall_p + wall_t - x_wheel - 0.5);
    }
}

module enc_gear_placed() {
    translate([x_wheel + 0.3, enc_pos[0], enc_pos[1]]) rotate([0, 90, 0]) rotate([0, 0, 180 / enc_gear_z]) encoder_gear();
}

// Demo animation: roll the top forward (nose down), then back (nose up).
tw_anim = [[0, 0], [0.30, 150], [0.38, 150], [0.75, -60], [0.85, -60], [1, 0]];

module assembly(slab = true) {
    w = anim >= 0 ? lookup(anim, tw_anim) : 0;   // wheel angle, + = top rolls forward
    if (slab) panel_slab();
    color([0.85, 0.85, 0.85]) translate([slot_w/2 + 18, 0, -panel_thickness]) rotate([0, 180, 0]) placard();
    color("darkorange", ghost_a()) housing();
    color([0.08, 0.08, 0.08]) translate([0, 0, z_c]) rotate([w, 0, 0]) translate([0, 0, -z_c]) wheel();
    color("goldenrod") translate([0, enc_pos[0], enc_pos[1]]) rotate([-w * wheel_gear_z / enc_gear_z, 0, 0])
        translate([0, -enc_pos[0], -enc_pos[1]]) enc_gear_placed();
    encoder_dummy();
    color("silver") translate([x_wall_n - wall_t - 2, 0, z_c]) rotate([0, 90, 0]) cylinder(d = 8, h = x_wall_p - x_wall_n + 2 * wall_t + 6);
}

// For the panel layout files (panel/*.scad), which `use` this file.
module trim_wheel_mounted() assembly(slab = false);
module trim_wheel_panel_cutout() {   // slot + screw holes only (no placard outline)
    rounded_rect([slot_w, slot_len], 4);
    for (x = [-hole_x, hole_x], y = [-hole_y, hole_y]) translate([x, y]) circle(d = m3_clear_d);
}
module trim_wheel_panel_countersinks() for (x = [-hole_x, hole_x], y = [-hole_y, hole_y]) translate([x, y, -0.01])
    cylinder(d1 = m3_head_d + 0.4, d2 = m3_clear_d, h = (m3_head_d + 0.4 - m3_clear_d) / 2);
function trim_wheel_size() = [flange_x1 - flange_x0, 2 * y_half];

module exploded() {
    panel_slab();
    color("darkorange") translate([0, 0, 40]) housing();
    color([0.08, 0.08, 0.08]) translate([0, 0, 140]) wheel();
    color("goldenrod") translate([40, 0, 40]) enc_gear_placed();
}

if (part == "assembly") rotate([90, 0, 0]) assembly();
else if (part == "exploded") rotate([90, 0, 0]) exploded();
else if (part == "wheel") wheel_local();
else if (part == "housing") housing();
else if (part == "encoder_gear") encoder_gear();
else if (part == "placard") placard();
else if (part == "panel_test_plate") panel_test_plate();
else if (part == "panel_cutout") panel_cutout();

echo(str("Trim wheel: M8 x ", ceil((x_wall_p + wall_t) - (x_wall_n - wall_t) + 10), " bolt + nut, 2x 608 bearings"));
echo(str("Trim wheel: EC11 encoder - cut its shaft to ", floor(x_wall_p + wall_t - x_wheel - 0.5), " mm from the mounting face"));
echo(str("Trim wheel: panel slot ", slot_w, " x ", ceil(slot_len), " mm, screws at +/-", hole_x, ", +/-", hole_y));
