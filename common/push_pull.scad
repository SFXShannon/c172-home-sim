// Shared push-pull control (THROTTLE, PROP, MIXTURE) for the C172 home sim.
//
// Outside: the knob and panel hardware are shaped like the real aircraft parts.
// Inside (kept simple):
//   - a 5/16" (7.94 mm) smooth steel rod is the shaft (set rod_d = 8 for 8 mm rod)
//   - it slides through a printed channel housing bolted behind the panel
//   - an O-ring in the front bushing gives the friction that holds it in place
//   - the slide pot drops into a printed tray that slides into the housing
//     from the back (open bottom, pins and tabs hang free, no zip ties)
//   - a printed carriage clamped to the rod drives the pot's arm, using the
//     pot's full travel (default: Fielect 10K 128 mm fader, 100 mm travel)
//
// Do not use this file directly: open parts/throttle, parts/mixture or parts/prop.
// Those files set `control` and `part` and then include this one.

include <sim_common.scad>

/* [Slide potentiometer] */
// How far the knob moves, pushed in to pulled out (mm). Limited to the pot's travel minus 4 mm.
control_travel = 96;
// Your slide pot: travel, then body length / width / height (without the lever).
// Defaults: Fielect 128 mm fader (128 x 15.7 x 6.9 mm). Measure yours.
pot_travel = 100;
pot_len = 128;
pot_w = 15.7;
pot_h = 6.9;
// The pot's arm: how far it sticks up above the body, its length along the
// travel, and its thickness (Fielect 128 mm: 9 x 8 x 1)
pot_lever_h = 9;
pot_lever_len = 8;
pot_lever_t = 1;

/* [Rod] */
// Rod diameter (mm). 5/16" = 7.9375; use 8 for 8 mm printer rod
rod_d = 25.4 * 5 / 16;
// O-ring cross-section (mm). 1.78 = US size 011 (0.301" ID x 0.070"); 2 = metric 8 x 2
oring_cs = 1.78;

/* [Rod length] */
// false = short rod that stops in the carriage (the carriage slides on the housing walls
// and the tray); true = old long rod that also runs through the rear bushing
rod_through = false;

/* [Hidden] */
bore_d       = rod_d + 0.4;
travel       = min(control_travel, pot_travel - 4);
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
oring_z    = 15;           // O-ring groove position in the front bushing

// Vertical layout (y): rod centre at 0
y_slot_top  = -rod_d / 2 - 2;               // top of the arm slot in the carriage
y_lever_tip = y_slot_top - 0.5;             // pot arm tip
y_pot_top   = y_lever_tip - pot_lever_h;    // top of the pot body
y_pot_bot   = y_pot_top - pot_h;
y_carr_bot  = rod_through ? y_pot_top + 1.2 : y_pot_top - 1 + 0.25;   // short rod: skids sit on the tray walls
y_carr_mid  = y_pot_top + 1.2;              // carriage underside clears the pot body
y_carr_top  = 12;
carr_half   = rod_through ? 8 : (pot_w / 2 + 0.3 + 1.6 + 0.4) - 0.35;   // short rod: housing walls guide the carriage
y_block_bot = y_pot_top + 0.3;              // bushing blocks hold the pot down
y_wall_top  = 6;

// Tray (holds the pot; slides into the housing from the back)
tray_wall   = 1.6;
tray_rib_h  = 1.4;          // pot rests on ribs, tabs on the pot's lower edge hang beside them
tray_floor  = 1.6;
tray_in     = pot_w / 2 + 0.3;              // inner half-width
tray_out    = tray_in + tray_wall;
tray_end    = 2;            // end bars
pin_zone    = 12;           // open (no floor) this far in from each end of the pot, for the pins
y_tray_bot  = y_pot_bot - tray_rib_h - tray_floor;
y_tray_top  = y_pot_top - 1;

// Housing walls / ledges
wall_in     = tray_out + 0.4;               // inner half-width of the channel
wall_t      = 3;
ledge_w     = 2;            // ledges the tray slides on (outside the pot, so pins hang free)
ledge_t     = 2.5;
y_ledge_top = y_tray_bot - 0.3;
y_floor_bot = y_ledge_top - ledge_t;        // bottom of the housing

// Pot body start (z): its travel centre lines up with the carriage's travel centre
function pot_z0() = bush_len + (travel + carr_len) / 2 - pot_len / 2;
z_tray0     = pot_z0() - 0.3 - tray_end;
z_tray1     = pot_z0() + pot_len + 0.3 + tray_end;
z_floor_end = z_tray1 + 7;
// M3 keeper screw across the housing, just behind the tray's back end bar
keeper = [(y_pot_bot + 3 + y_tray_top) / 2, z_tray1 + 2.2];   // [y, z]

z_knob_back = -(panel_thickness + esc_h + knob_gap);
rod_front   = z_knob_back - socket_depth + 1;
rod_back    = rod_through ? z_end + travel + 5 : z_rear - 1;   // short rod ends 1 mm inside the carriage
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

// ------------------------------------------------------------------ housing (channel)

module housing() {
    flange_y0 = y_floor_bot;
    flange_y1 = mount_flange_size / 2;
    difference() {
        union() {
            // flange: square around the rod, stretched down to the floor so it prints flat
            translate([-mount_flange_size/2, flange_y0, 0])
                linear_extrude(flange_t) translate([mount_flange_size/2, (flange_y1 - flange_y0)/2])
                    rounded_rect([mount_flange_size, flange_y1 - flange_y0], 5);
            for (s = [-1, 1]) {
                // side walls
                translate([s > 0 ? wall_in : -wall_in - wall_t, y_floor_bot, 0]) cube([wall_t, y_wall_top - y_floor_bot, z_floor_end]);
                // ledges the tray slides on
                translate([s > 0 ? wall_in - ledge_w : -wall_in, y_floor_bot, 0]) cube([ledge_w + 0.01, ledge_t, z_floor_end]);
                // front stops for the tray
                translate([s > 0 ? wall_in - ledge_w : -wall_in, y_ledge_top - 0.01, z_tray0 - 3]) cube([ledge_w + 0.01, 3, 3]);
            }
            // front bushing block + round boss
            translate([-wall_in, y_block_bot, 0]) cube([2 * wall_in, y_wall_top - y_block_bot, bush_len]);
            cylinder(d = 18, h = bush_len);
            // rear bushing block
            translate([-wall_in, y_block_bot, z_rear]) cube([2 * wall_in, y_wall_top - y_block_bot, rear_len]);
            translate([0, 0, z_rear]) cylinder(d = 18, h = rear_len);
        }
        // rod bore (front bushing; also the rear one for the long rod)
        translate([0, 0, -1]) cylinder(d = bore_d, h = (rod_through ? z_end : bush_len) + 2);
        if (!rod_through) translate([0, 0, z_rear - 1]) cylinder(d = bore_d, h = 4);   // shallow pocket: clearance for the rod end
        translate([0, 0, -0.01]) cylinder(d1 = bore_d + 2, d2 = bore_d, h = 1);
        // O-ring groove for friction: about 15 % squeeze on the O-ring
        translate([0, 0, oring_z - 1.2]) cylinder(d = rod_d + 2 * 0.85 * oring_cs, h = oring_cs + 0.6);
        mount_flange_holes();
        // room to drop the lower nuts in from behind and get a spanner on them
        for (s = [-1, 1]) translate([s * mount_pitch / 2, -mount_pitch / 2, flange_t - m3_nut_t - 0.6])
            cylinder(d = m3_nut_af / cos(30) + 1, h = 14, $fn = 6);
        // slot in the rear block so the pot's arm passes through when the tray slides in
        translate([-pot_lever_t / 2 - 0.5, y_block_bot - 1, z_rear - 1]) cube([pot_lever_t + 1, y_lever_tip + 0.7 - y_block_bot + 1, rear_len + 2]);
        // keeper screw across both walls (head one side, nut pocket the other)
        translate([-wall_in - wall_t - 1, keeper[0], keeper[1]]) rotate([0, 90, 0]) cylinder(d = m3_clear_d, h = 2 * (wall_in + wall_t) + 2);
        translate([wall_in + wall_t - m3_nut_t - 0.4, keeper[0], keeper[1]]) rotate([0, 90, 0]) rotate([0, 0, 30]) m3_nut_pocket(m3_nut_t + 1);
        // "UP" mark
        translate([0, mount_flange_size/2 - 4, flange_t - 0.6]) linear_extrude(1)
            text("UP", size = 3.5, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
}

// ------------------------------------------------------------------ tray (holds the pot)
// The pot drops in from the top; the ends are open underneath so its pins hang
// free, and it rests on two ribs so the little tabs on its lower edge hang
// beside them. Built in assembly coords (tray sits in the housing).

module tray() {
    difference() {
        union() {
            // side walls
            for (s = [-1, 1]) translate([s > 0 ? tray_in : -tray_out, y_tray_bot, z_tray0]) cube([tray_wall, y_tray_top - y_tray_bot, z_tray1 - z_tray0]);
            // floor strips + ribs along each side; they stop short of both ends so
            // the pins (wherever they are across the end) hang into open space
            for (s = [-1, 1]) {
                translate([s > 0 ? pot_w / 2 - 3.5 : -tray_in, y_tray_bot, pot_z0() + pin_zone]) cube([3.5 + 0.3, tray_floor, pot_len - 2 * pin_zone]);
                translate([s > 0 ? pot_w / 2 - 3.5 : -pot_w / 2 + 1.5, y_tray_bot, pot_z0() + pin_zone]) cube([2, tray_floor + tray_rib_h, pot_len - 2 * pin_zone]);
            }
            for (z = [pot_z0() + 18, pot_z0() + pot_len / 2 - 1, pot_z0() + pot_len - 20])
                translate([-tray_in, y_tray_bot, z]) cube([2 * tray_in, tray_floor, 3]);
            // end bars across the upper half of the pot's ends (pins come out lower down)
            for (z = [z_tray0, z_tray1 - tray_end])
                translate([-tray_out, y_pot_bot + 3, z]) cube([2 * tray_out, y_tray_top - (y_pot_bot + 3), tray_end]);
        }
    }
}

// Part of the pot's travel the carriage uses (0 = pot's front end), for the firmware
pot_mid = pot_z0() + pot_len / 2;
lever_in = z_rear - carr_len / 2;
use_from = 0.5 + (lever_in - travel - pot_mid) / pot_travel;
use_to = 0.5 + (lever_in - pot_mid) / pot_travel;
if (use_from < 0 || use_to > 1) echo(str("WARNING: ", control, ": the carriage runs past the end of the pot's travel - use a longer pot or less control_travel"));

// ------------------------------------------------------------------ carriage
// Clamped to the rod with an M3 set screw; the pot's arm sits in the slot underneath.

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
        // short rod: skids ride on the tray walls; cut away the middle so they clear the pot
        if (!rod_through) translate([-tray_in, y_carr_bot - 1, -1]) cube([2 * tray_in, y_carr_mid - y_carr_bot + 1, carr_len + 2]);
        // slot for the pot's flat arm (long way along the travel), with a lead-in
        translate([-(pot_lever_t + 0.5) / 2, y_carr_bot - 1, carr_len / 2 - (pot_lever_len + 0.6) / 2])
            cube([pot_lever_t + 0.5, y_slot_top - y_carr_bot + 1, pot_lever_len + 0.6]);
        translate([0, y_carr_mid - 0.01, carr_len / 2]) rotate([-90, 0, 0]) linear_extrude(1.2, scale = [0.4, 0.85])
            square([pot_lever_t + 3, pot_lever_len + 2.6], center = true);
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
    color([0.30, 0.31, 0.33], ghost_a(0.55)) difference() {
        translate([0, 0, -panel_thickness]) linear_extrude(panel_thickness) difference() {
            translate([-60, -60]) square([120, 120]);
            circle(d = panel_hole_d);
            mount_panel_holes();
        }
        translate([0, 0, -panel_thickness]) mount_panel_countersinks();
    }
}

module pot_dummy(pos) {   // pos 0 = in, 1 = out
    color([0.12, 0.12, 0.12]) translate([-pot_w/2, y_pot_bot, pot_z0()]) cube([pot_w, pot_h, pot_len]);
    color("silver") translate([-pot_lever_t/2, y_pot_top - 0.01, z_carr_in + carr_len/2 - pot_lever_len/2 - pos * travel])
        cube([pot_lever_t, pot_lever_h, pot_lever_len]);
    // pins at both ends
    color("silver") for (z = [pot_z0() + 2, pot_z0() + pot_len - 2], x = [-3, 3]) translate([x, y_pot_bot - 3.5, z]) cube([0.6, 3.6, 0.6]);
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
    color("darkorange", ghost_a()) housing();
    color("seagreen", ghost_a()) tray();
    color("silver") translate([-wall_in - wall_t - 1.6, keeper[0], keeper[1]]) rotate([0, 90, 0]) cylinder(d = 3, h = 2 * (wall_in + wall_t) + 2);
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
    color("seagreen") translate([0, -40, 30]) tray();
    color("silver") translate([0, 80, rod_front]) cylinder(d = rod_d, h = rod_len);
    color(knob_color) translate([0, 0, z_knob_back - 60]) knob();
}

module push_pull_panel_cutout() { circle(d = panel_hole_d); mount_panel_holes(); }

// ------------------------------------------------------------------ output
module push_pull_output() {
    if (part == "assembly") rotate([90, 0, 0])
        assembly(anim >= 0 ? lookup(anim, [[0, 0], [0.08, 0], [0.42, 1], [0.58, 1], [0.92, 0], [1, 0]]) : 0.4);
    else if (part == "assembly_in") rotate([90, 0, 0]) assembly(0);
    else if (part == "assembly_out") rotate([90, 0, 0]) assembly(1);
    else if (part == "exploded") rotate([90, 0, 0]) exploded();
    // throttle prints face-down, mixture/prop print back-down
    else if (part == "knob") { if (control == "throttle") translate([0, 0, knob_len]) knob(); else rotate([180, 0, 0]) knob(); }
    else if (part == "housing") translate([0, 0, -y_floor_bot]) rotate([90, 0, 0]) housing();
    else if (part == "carriage") translate([0, 0, 0]) carriage();
    else if (part == "tray") translate([0, 0, -y_tray_bot]) rotate([90, 0, 0]) tray();
    else if (part == "escutcheon") translate([0, 0, panel_thickness + esc_h]) escutcheon();
    else if (part == "panel_test_plate") panel_test_plate();
    else if (part == "panel_cutout") panel_cutout();
}

echo(str(control, ": ", rod_d, " mm smooth rod, cut to ", ceil(rod_len), " mm (", round(rod_len / 25.4 * 8) / 8, " in)"));
echo(str(control, ": uses ", round(use_from * 100), "% to ", round(use_to * 100), "% of the pot's travel; reaches ", ceil(z_floor_end), " mm behind the panel"));
echo(str(control, ": tray keeper 1x M3 x ", [for (l = [25, 30, 35]) if (l >= 2 * (wall_in + wall_t)) l][0], " + nut across the back of the housing"));
echo(str(control, ": panel screws 4x M3 x ", mount_screw_len(panel_thickness), " countersunk + 4x M3 nuts"));
echo(str(control, ": panel hole ", panel_hole_d, " mm + standard 4-hole mount"));
