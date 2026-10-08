// Shared push-pull control (THROTTLE, PROP, MIXTURE) for the C172 home sim.
//
// Outside: the knob and panel hardware are shaped like the real aircraft parts.
// Inside (kept simple):
//   - an 8 mm smooth steel rod (the same rod 3D printers use) is the shaft
//   - it slides through a printed U-channel housing bolted behind the panel
//   - an O-ring in the front bushing gives the friction that holds it in place
//   - a printed carriage clamped to the rod drives a slide potentiometer
//     (60 mm travel, e.g. Bourns PTA6043 or any "60mm slide pot" module)
//
// Do not use this file directly: open parts/throttle, parts/mixture or parts/prop.
// Those files set `control` and `part` and then include this one.

include <sim_common.scad>

/* [Slide potentiometer] */
// Travel of your slide pot (mm)
pot_travel = 60;
// Pot body length / width / height (without the lever)
pot_len = 76;
pot_w = 9.5;
pot_h = 8;
// Lever height above the pot body
pot_lever_h = 15;

/* [Hidden] */
rod_d        = 8;
bore_d       = rod_d + 0.4;
travel       = pot_travel;
knob_gap     = 2;          // knob back to escutcheon when pushed fully in
socket_depth = 15;         // rod goes this far into the knob

// Panel hardware per control
esc_h        = control == "throttle" ? 8 : 6;   // escutcheon height off the panel
panel_hole_d = 14;

// Housing layout (assembly coords: panel back at z = 0, pilot at -z, +y up)
flange_t   = mount_flange_t;
bush_len   = 30;           // front bushing (with friction O-ring)
carr_len   = 14;
rear_len   = 12;
z_rear     = bush_len + travel + carr_len;   // front face of rear bushing block
z_end      = z_rear + rear_len;
wall_in    = 8.5;          // channel inner half-width
wall_t     = 3;
carr_half  = 8;
y_wall_top = 6;
y_lever_tip = -9;          // pot lever tip height when engaged in the carriage
y_carr_bot = -15;
y_carr_top = 12;
y_pot_top  = y_lever_tip - pot_lever_h;
y_floor_top = y_pot_top - pot_h;
floor_t    = 4;
y_floor_bot = y_floor_top - floor_t;
y_block_bot = -12;         // bushing blocks only come down this far (pot body passes under)
oring_z    = 15;           // O-ring groove position in the front bushing

z_knob_back = -(panel_thickness + esc_h + knob_gap);
rod_front   = z_knob_back - socket_depth + 1;
rod_back    = z_end + travel + 5;
rod_len     = rod_back - rod_front;
// carriage position: "in" = rod pushed fully in = carriage against rear block
z_carr_in   = z_rear - carr_len;

// ------------------------------------------------------------------ knobs
// All knobs are built facing -z (toward the pilot) with the back face at z = 0
// and printed face-down (see knob_print()).

module knob_socket() {
    translate([0, 0, -socket_depth]) cylinder(d = rod_d + 0.25, h = socket_depth + 0.01);
}

// THROTTLE: smooth round knob with a flat face and rounded edge. Print in
// black (white/cream on older 172s). Prints face-down.
module knob_throttle() {
    difference() {
        rotate_extrude($fn = 96) polygon([
            [0, 0], [7.5, 0], [8, -4], [12, -8], [17.5, -11], [19, -13],
            [19, -20], [18.5, -21.5], [17, -23.3], [15, -25.3], [13, -27], [0, -27]]);
        knob_socket();
    }
}

// MIXTURE: red, fine ribs round the edge, push-button in the middle (the real
// one is a vernier with a lock button; here the button is moulded in, paint it
// black or print it separately with a colour change).
module knob_mixture() {
    difference() {
        union() {
            knob_back();
            translate([0, 0, -21]) ribbed_cylinder(16, 12.01, n = 36, depth = 0.9);
            translate([0, 0, -22]) cylinder(r1 = 15, r2 = 16, h = 1.01);
            // lock button
            translate([0, 0, -25]) cylinder(d = 11, h = 3.01);
            translate([0, 0, -25.6]) cylinder(d1 = 9.8, d2 = 11, h = 0.61);
        }
        knob_socket();
        // groove round the button
        translate([0, 0, -22.6]) difference() { cylinder(d = 14, h = 1); cylinder(d = 11, h = 1); }
    }
}

// Tapered back of the mixture / prop knobs (45 deg so they print back-down).
module knob_back() {
    rotate_extrude($fn = 96) polygon([[0, 0], [7, 0], [14, -7], [16, -9.01], [0, -9.01]]);
}

// PROP (constant-speed 172s, 172RG, 182): blue, crenellated edge.
module knob_prop() {
    n = 10;
    difference() {
        union() {
            knob_back();
            translate([0, 0, -21]) cylinder(r = 16, h = 12.01);
            translate([0, 0, -22]) cylinder(r1 = 15, r2 = 16, h = 1.01);
        }
        knob_socket();
        for (i = [0 : n - 1]) rotate([0, 0, i * 360 / n + 180 / n])
            translate([16, 0, -16]) cube([7, 6.5, 14], center = true);
        // shallow dish in the face
        translate([0, 0, -22.5]) cylinder(r = 10, h = 1);
    }
}

module knob() {
    if (control == "throttle") knob_throttle();
    else if (control == "mixture") knob_mixture();
    else knob_prop();
}

knob_len = control == "throttle" ? 27 : (control == "mixture" ? 25.6 : 22);

// ------------------------------------------------------------------ panel hardware

// Throttle: knurled friction-lock nut. Mixture / prop: hex bushing nut + washer.
module escutcheon() {
    zf = -(panel_thickness + esc_h);
    difference() {
        union() {
            if (control == "throttle") {
                translate([0, 0, zf + 1]) ribbed_cylinder(12.5, esc_h - 2, n = 28, depth = 0.7);
                translate([0, 0, zf]) cylinder(r1 = 11.5, r2 = 12.5, h = 1.01);
                translate([0, 0, zf + esc_h - 1.01]) cylinder(r = 13, h = 1.01);
            } else {
                translate([0, 0, zf]) cylinder(d = 17 / cos(30), h = esc_h - 1.5, $fn = 6);
                translate([0, 0, zf + esc_h - 1.5]) cylinder(d = 22, h = 1.5);
            }
            translate([0, 0, -panel_thickness - 0.01]) cylinder(d = panel_hole_d - 2 * clearance, h = panel_thickness - 1);
        }
        translate([0, 0, zf - 1]) cylinder(d = rod_d + 1, h = esc_h + panel_thickness + 2);
        translate([0, 0, zf - 0.01]) cylinder(d1 = rod_d + 2.5, d2 = rod_d + 1, h = 0.8);
    }
}

// ------------------------------------------------------------------ housing (U-channel)

module housing() {
    flange_y0 = y_floor_bot;
    flange_y1 = mount_flange_size / 2;
    difference() {
        union() {
            // flange: square around the rod, stretched down to the floor so it prints flat
            translate([-mount_flange_size/2, flange_y0, 0])
                linear_extrude(flange_t) translate([mount_flange_size/2, (flange_y1 - flange_y0)/2])
                    rounded_rect([mount_flange_size, flange_y1 - flange_y0], 5);
            // floor
            translate([-(wall_in + wall_t), y_floor_bot, 0]) cube([2 * (wall_in + wall_t), floor_t, z_end]);
            // side walls
            for (s = [-1, 1]) translate([s > 0 ? wall_in : -wall_in - wall_t, y_floor_bot, 0])
                cube([wall_t, y_wall_top - y_floor_bot, z_end]);
            // front bushing block + round boss
            translate([-wall_in, y_block_bot, 0]) cube([2 * wall_in, y_wall_top - y_block_bot, bush_len]);
            cylinder(d = 18, h = bush_len);
            // rear bushing block
            translate([-wall_in, y_block_bot, z_rear]) cube([2 * wall_in, y_wall_top - y_block_bot, rear_len]);
            translate([0, 0, z_rear]) cylinder(d = 18, h = rear_len);
            // pot end stops
            for (z = [pot_z0() - 2.5, pot_z0() + pot_len + 0.5])
                translate([-pot_w/2 - 2, y_floor_top - 0.01, z]) cube([pot_w + 4, 2, 2]);
        }
        // rod bore
        translate([0, 0, -1]) cylinder(d = bore_d, h = z_end + 2);
        translate([0, 0, -0.01]) cylinder(d1 = bore_d + 2, d2 = bore_d, h = 1);
        // O-ring groove (8 mm ID x 2 mm O-ring) for friction
        translate([0, 0, oring_z - 1.2]) cylinder(d = rod_d + 3.2, h = 2.4);
        mount_flange_holes();
        // zip-tie slots to hold the pot down, plus a wire exit at the back
        for (z = [pot_z0() + 12, pot_z0() + pot_len - 16]) for (s = [-1, 1])
            translate([s * (pot_w/2 + 1.5) - 1, y_floor_bot - 1, z]) cube([2, floor_t + 2, 4]);
        translate([-4, y_floor_bot - 1, pot_z0() + pot_len - 6]) cube([8, floor_t + 2, 5]);
        // "UP" mark
        translate([0, mount_flange_size/2 - 4, flange_t - 0.6]) linear_extrude(1)
            text("UP", size = 3.5, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
}

// Pot body start (z) so its travel centre lines up with the carriage's.
function pot_z0() = bush_len + (travel + carr_len) / 2 - pot_len / 2;

// ------------------------------------------------------------------ carriage
// Clamped to the rod with an M3 set screw; the pot lever sits in the cross slot.

module carriage() {
    difference() {
        translate([-carr_half, y_carr_bot, 0]) cube([2 * carr_half, y_carr_top - y_carr_bot, carr_len]);
        translate([0, 0, -1]) cylinder(d = rod_d + 0.3, h = carr_len + 2);
        // set screw from the top + nut slid in from the side
        translate([0, 0, carr_len / 2]) rotate([-90, 0, 0]) cylinder(d = m3_clear_d, h = y_carr_top + 1);
        translate([0, rod_d/2 + 1.2 + (m3_nut_t + 0.4)/2, carr_len / 2]) rotate([90, 0, 0]) hull() {
            rotate([0, 0, 30]) m3_nut_pocket(m3_nut_t + 0.4);
            translate([carr_half + 2, 0, 0]) rotate([0, 0, 30]) m3_nut_pocket(m3_nut_t + 0.4);
        }
        // cross-shaped slot fits a flat pot lever either way round
        for (sz = [[5.4, 2.0], [2.0, 5.4]])
            translate([-sz[0]/2, y_carr_bot - 1, carr_len/2 - sz[1]/2]) cube([sz[0], y_lever_tip - y_carr_bot + 1 + 0.5, sz[1]]);
    }
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
            rounded_rect([80, 80], 4);
            circle(d = panel_hole_d);
            mount_panel_holes();
            for (x = [-1, 1], y = [-1, 1]) translate([x * 33, y * 33]) circle(d = m3_clear_d);
        }
        mount_panel_countersinks();
    }
}

// ------------------------------------------------------------------ views

knob_color = control == "throttle" ? [0.08, 0.08, 0.08] : (control == "mixture" ? [0.75, 0.05, 0.05] : [0.1, 0.25, 0.75]);

module panel_slab() {
    color([0.30, 0.31, 0.33]) difference() {
        translate([0, 0, -panel_thickness]) linear_extrude(panel_thickness) difference() {
            translate([-60, -60]) square([120, 120]);
            circle(d = panel_hole_d);
            mount_panel_holes();
        }
        translate([0, 0, -panel_thickness]) mount_panel_countersinks();
    }
}

module pot_dummy(pos) {   // pos 0 = in, 1 = out
    color("dimgray") translate([-pot_w/2, y_floor_top, pot_z0()]) cube([pot_w, pot_h, pot_len]);
    color("silver") translate([-2.5, y_pot_top, z_carr_in + carr_len/2 - 0.6 - pos * travel]) cube([5, pot_lever_h + 0.5, 1.2]);
}

module moving(pos) {
    dz = -pos * travel;
    translate([0, 0, dz]) {
        color("silver") translate([0, 0, rod_front]) cylinder(d = rod_d, h = rod_len);
        color(knob_color) translate([0, 0, z_knob_back]) knob();
        color("goldenrod") translate([0, 0, z_carr_in]) carriage();
    }
}

module assembly(pos = 0.4, slab = true) {
    if (slab) panel_slab();
    color([0.6, 0.6, 0.62]) escutcheon();
    color("darkorange") housing();
    mount_hardware_dummy(panel_thickness);
    pot_dummy(pos);
    moving(pos);
}

module exploded() {
    panel_slab();
    color([0.6, 0.6, 0.62]) translate([0, 0, -40]) escutcheon();
    translate([0, 0, -70]) mount_hardware_dummy(panel_thickness);
    color("darkorange") translate([0, 0, 30]) housing();
    color("goldenrod") translate([0, 40, 30 + z_carr_in]) carriage();
    color("silver") translate([0, 80, rod_front]) cylinder(d = rod_d, h = rod_len);
    color(knob_color) translate([0, 0, z_knob_back - 60]) knob();
}

module push_pull_panel_cutout() { circle(d = panel_hole_d); mount_panel_holes(); }

// ------------------------------------------------------------------ output
module push_pull_output() {
    if (part == "assembly") rotate([90, 0, 0]) assembly(0.4);
    else if (part == "assembly_in") rotate([90, 0, 0]) assembly(0);
    else if (part == "assembly_out") rotate([90, 0, 0]) assembly(1);
    else if (part == "exploded") rotate([90, 0, 0]) exploded();
    // throttle prints face-down, mixture/prop print back-down
    else if (part == "knob") { if (control == "throttle") translate([0, 0, knob_len]) knob(); else rotate([180, 0, 0]) knob(); }
    else if (part == "housing") translate([0, 0, -y_floor_bot]) rotate([90, 0, 0]) housing();
    else if (part == "carriage") translate([0, 0, 0]) carriage();
    else if (part == "escutcheon") translate([0, 0, panel_thickness + esc_h]) escutcheon();
    else if (part == "panel_test_plate") panel_test_plate();
    else if (part == "panel_cutout") panel_cutout();
}

echo(str(control, ": 8 mm smooth rod, cut to ", ceil(rod_len), " mm"));
echo(str(control, ": panel screws 4x M3 x ", mount_screw_len(panel_thickness), " countersunk + 4x M3 nuts"));
echo(str(control, ": panel hole ", panel_hole_d, " mm + standard 4-hole mount"));
