// Cessna 172-style PARKING BRAKE for a home sim panel
//
// Looks like the real one: a black L-shaped lever on a 3/8" (10 mm) shaft that
// comes out of the lower panel. To SET: pull the handle aft and rotate it 90 deg
// so the grip points down. To RELEASE: rotate it back up and let the spring pull
// it home. A microswitch on the back tells the sim which way it is.
//
// Inside it is kept simple: a printed tube with an L-shaped slot, a spring, and a
// lug on the shaft that drops into a notch when you twist it.
//
// PANEL MOUNTING (same for every control in this repo): 4 x M3 countersunk screws
// go in from the front of the panel, through the housing flange, into M3 nuts
// that sit in hex pockets on the back of the flange. Template in panel-template/.
//
// Render one part:  openscad -D 'part="housing"' -o housing.stl parking_brake.scad

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, exploded, section, housing, shaft, handle, escutcheon, rear_cap, panel_test_plate, panel_cutout]
// Assembly view only: show the brake released or set
brake_state = "set"; // [released, set]

/* [Mechanism] */
// How far the handle pulls out (mm)
travel = 25;
// Which way the grip points when the brake is OFF (pilot's view). It rotates down to set.
stowed_side = "right"; // [right, left]
// Depth of the detent notch the lug drops into when set (mm)
notch_depth = 3;

/* [Handle] */
// Grip length from the shaft centre (real handle is about 3.75")
grip_len = 95;
// Grip width where it meets the shaft / at the tip
grip_root_w = 22;
grip_tip_w = 13;
// Grip thickness
grip_t = 13;
// How far the tip sweeps back toward the pilot
grip_rake = 12;
// Gap between the escutcheon and the back of the handle when pushed in
handle_gap = 3;

/* [Hidden] */
twist        = 90;
twist_dir    = stowed_side == "right" ? 1 : -1;
shaft_d      = 10;
nose_d       = 8;         // shaft steps down to this inside the handle
collar_d     = 18;
collar_h     = 8;
tail_protrude = 5;        // tail sticks out of the rear cap this much when IN
housing_od   = 28;
chamber_d    = collar_d + 1;
flange_t     = mount_flange_t;
spring_space = 40;        // floor-to-collar when handle is in
chamber_len  = spring_space + collar_h;
z_top        = flange_t + chamber_len;   // rear face of housing
cap_t        = 4;
ear_r        = 18;        // rear cap screw radius
ear_w        = 9;
ear_h        = 4;
panel_hole_d = 16;
esc_d        = 24;        // escutcheon (small trim ring on the panel face)
esc_t        = 2.5;
socket_depth = 12;
flat_depth   = 1;         // D-flat that keys the handle to the shaft
rod_d        = 3.4;       // M3 threaded rod through the shaft
lug_w        = 4;
lug_h        = 4;
lug_r_in     = collar_d / 2 - 1;
lug_r_out    = housing_od / 2 - 1;
z_lug        = z_top - collar_h / 2;
z_handle_back = -(panel_thickness + esc_t + handle_gap);
z_nose       = z_handle_back - socket_depth + 0.5;
z_tail_top   = z_top + cap_t + tail_protrude;
handle_nut_v = socket_depth + 3.5;   // nut position, measured from the handle back face

// Microswitch (KW11 / SS-5GL style, 20 x 10 x 6.4 mm, M2 holes 9.5 mm apart)
sw_len = 20; sw_t = 6.4; sw_hole_pitch = 9.5;
sw_x = 2;
sw_plate_y = shaft_d / 2 + 1;
sw_plate_t = 3;
sw_body_bottom = z_tail_top + 1.5;
sw_slot_lo = sw_body_bottom + 1;
sw_slot_hi = sw_body_bottom + 9;
sw_plate_top = sw_slot_hi + 3;

// ------------------------------------------------------------------ lug & slot

module lug_profile(g = 0, rout = lug_r_out) {
    if (rout > lug_r_out + g)
        polygon([[lug_r_in, lug_h/2 + g], [rout, lug_h/2 + g], [rout, -lug_h/2 - g],
                 [lug_r_out + g, -lug_h/2 - g],
                 [lug_r_in, -lug_h/2 - g - (lug_r_out + g - lug_r_in)]]);
    else
        polygon([[lug_r_in, lug_h/2 + g], [lug_r_out + g, lug_h/2 + g],
                 [lug_r_out + g, -lug_h/2 - g],
                 [lug_r_in, -lug_h/2 - g - (lug_r_out + g - lug_r_in)]]);
}

module lug(g = 0, rout = lug_r_out) {
    rotate([90, 0, 0]) linear_extrude(lug_w + 2 * g, center = true) lug_profile(g, rout);
}

module lug_at(a, dz, g = 0, rout = lug_r_out) {
    translate([0, 0, z_lug + dz]) rotate([0, 0, a]) lug(g, rout);
}

// Bayonet (L) slot: axial run, 90 deg turn at full travel, detent notch.
module slot_cutter() {
    g = clearance + 0.15;
    rc = housing_od / 2 + 1;
    a1 = twist * twist_dir;
    n = 12;
    hull() { lug_at(0, 15, g, rc); lug_at(0, -travel, g, rc); }
    for (i = [0 : n - 1]) hull() {
        lug_at(a1 * i / n, -travel, g, rc);
        lug_at(a1 * (i + 1) / n, -travel, g, rc);
    }
    hull() { lug_at(a1, -travel, g, rc); lug_at(a1, -travel + notch_depth, g, rc); }
}

// ------------------------------------------------------------------ housing

module ear_block(z0, h, gusset) {
    for (a = [90, 270]) rotate([0, 0, a]) hull() {
        translate([housing_od/2 - 2, -ear_w/2, z0]) cube([ear_r + ear_w/2 - housing_od/2 + 2, ear_w, h]);
        if (gusset)
            translate([housing_od/2 - 2, -ear_w/2, z0 - (ear_r + ear_w/2 - housing_od/2)])
                cube([0.1, ear_w, 0.1]);
    }
}

module housing() {
    difference() {
        union() {
            mount_flange();
            cylinder(d = housing_od, h = z_top);
            ear_block(z_top - ear_h, ear_h, true);
        }
        translate([0, 0, flange_t]) cylinder(d = chamber_d, h = chamber_len + 1);
        translate([0, 0, -1]) cylinder(d = shaft_d + 2 * clearance + 0.3, h = flange_t + 2);
        translate([0, 0, -0.01]) cylinder(d1 = shaft_d + 2, d2 = shaft_d, h = 1);
        slot_cutter();
        mount_flange_holes();
        for (a = [90, 270]) rotate([0, 0, a]) translate([ear_r, 0, z_top - 12])
            cylinder(d = m3_tap_d(), h = 13);
        // "UP" mark so you mount it the right way round
        translate([0, mount_flange_size/2 - 4, flange_t - 0.6]) linear_extrude(1)
            text("UP", size = 3.5, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
    }
}

// ------------------------------------------------------------------ shaft
// Modelled in the "handle in" position. Prints nose-down with no supports.

module shaft() {
    cone_h = (collar_d - shaft_d) / 2;
    difference() {
        union() {
            translate([0, 0, z_handle_back]) cylinder(d = shaft_d, h = z_top - z_handle_back);
            translate([0, 0, z_nose]) cylinder(d = nose_d, h = z_handle_back - z_nose + 0.01);
            translate([0, 0, z_top - collar_h]) cylinder(d = collar_d, h = collar_h);
            translate([0, 0, z_top - collar_h - cone_h]) cylinder(d1 = shaft_d, d2 = collar_d, h = cone_h + 0.01);
            translate([0, 0, z_top - 0.01]) cylinder(d = shaft_d, h = z_tail_top - z_top - 1);
            translate([0, 0, z_tail_top - 1]) cylinder(d1 = shaft_d, d2 = shaft_d - 2, h = 1);
            lug_at(0, 0);
        }
        // D-flat (on +Y) that keys the handle
        translate([-nose_d, nose_d/2 - flat_depth, z_nose - 1]) cube([2 * nose_d, nose_d, z_handle_back - z_nose + 1]);
        translate([0, 0, z_nose - 1]) cylinder(d = rod_d, h = z_tail_top - z_nose + 2);
        translate([0, 0, z_tail_top - m3_nut_t - 0.6]) rotate([0, 0, 30]) m3_nut_pocket(5);
    }
}

// ------------------------------------------------------------------ rear cap

module rear_cap() {
    difference() {
        union() {
            translate([0, 0, z_top]) cylinder(d = housing_od, h = cap_t);
            ear_block(z_top, cap_t, false);
            translate([sw_x - sw_len/2 - 2, sw_plate_y, z_top])
                cube([sw_len + 4, sw_plate_t, sw_plate_top - z_top]);
            for (x = [sw_x - sw_len/2 - 2, sw_x + sw_len/2 - 0.5]) hull() {
                translate([x, sw_plate_y, z_top]) cube([2.5, sw_plate_t + 7, cap_t]);
                translate([x, sw_plate_y, z_top]) cube([2.5, sw_plate_t, sw_plate_top - z_top - 4]);
            }
        }
        translate([0, 0, z_top - 1]) cylinder(d = shaft_d + 2 * clearance + 0.4, h = cap_t + 2);
        translate([0, 0, z_top - 0.01]) cylinder(d1 = shaft_d + 2.5, d2 = shaft_d + 0.6, h = 1.2);
        for (a = [90, 270]) rotate([0, 0, a]) translate([ear_r, 0, z_top - 1])
            cylinder(d = m3_clear_d, h = cap_t + 2);
        for (dx = [-sw_hole_pitch/2, sw_hole_pitch/2]) hull()
            for (z = [sw_slot_lo, sw_slot_hi])
                translate([sw_x + dx, sw_plate_y - 1, z]) rotate([-90, 0, 0])
                    cylinder(d = m2_clear_d, h = sw_plate_t + 2);
    }
}

// ------------------------------------------------------------------ escutcheon
// Small domed trim ring where the shaft leaves the panel. Its spigot is a snug
// fit in the panel hole; add a drop of glue.

module escutcheon() {
    zf = -(panel_thickness + esc_t);
    difference() {
        union() {
            translate([0, 0, zf]) hull() {
                translate([0, 0, esc_t - 0.01]) cylinder(d = esc_d, h = 0.01);
                cylinder(d = esc_d - 4, h = esc_t);
            }
            translate([0, 0, -panel_thickness - 0.01])
                cylinder(d = panel_hole_d - 2 * clearance, h = panel_thickness - 1);
        }
        translate([0, 0, zf - 1]) cylinder(d = shaft_d + 1.2, h = esc_t + panel_thickness + 2);
    }
}

// ------------------------------------------------------------------ handle
// Built in its own frame: u along the grip (+x), v from the back face toward the
// pilot (+z), thickness along y. mounted_handle() puts it on the shaft.

function lerp(a, b, t) = a + (b - a) * t;
grip_n = 10;
function grip_pt(i) = let(t = i / grip_n, u = lerp(8, grip_len - grip_tip_w/2, t))
    [u, grip_root_w/2 + grip_rake * pow(t, 1.4)];
function grip_w(i) = lerp(grip_root_w, grip_tip_w, i / grip_n);

// Convex 2D pieces of the side profile (u, v)
module handle_piece(i) {
    if (i < 0) hull() {   // hub around the shaft socket
        translate([-grip_root_w/2, 0]) square([grip_root_w, 1]);
        translate([0, grip_root_w/2]) circle(d = grip_root_w);
    } else hull() {
        translate(grip_pt(i)) circle(d = grip_w(i));
        translate(grip_pt(i + 1)) circle(d = grip_w(i + 1));
    }
}

module handle_raw() {
    c = 2;   // edge round-over
    for (i = [-1 : grip_n - 1]) hull() {
        rotate([90, 0, 0]) linear_extrude(grip_t - 2 * c, center = true) handle_piece(i);
        rotate([90, 0, 0]) linear_extrude(grip_t, center = true) offset(-c) handle_piece(i);
    }
}

module handle_local() {
    difference() {
        handle_raw();
        // D socket for the shaft nose (flat on +y)
        translate([0, 0, -0.01]) linear_extrude(socket_depth) difference() {
            circle(d = nose_d + 2 * clearance);
            translate([-nose_d, nose_d/2 - flat_depth + clearance]) square([2 * nose_d, nose_d]);
        }
        translate([0, 0, -0.01]) cylinder(d1 = nose_d + 1.2, d2 = nose_d, h = 0.6);
        cylinder(d = rod_d, h = handle_nut_v + 4);
        // captive nut, slides in from the -y face
        translate([0, 0, handle_nut_v - (m3_nut_t + 0.4) / 2]) hull() {
            rotate([0, 0, 30]) m3_nut_pocket(m3_nut_t + 0.4);
            translate([0, -grip_t, 0]) rotate([0, 0, 30]) m3_nut_pocket(m3_nut_t + 0.4);
        }
    }
}

// In assembly coordinates, brake released: grip horizontal toward stowed_side.
module mounted_handle() {
    translate([0, 0, z_handle_back]) rotate([0, 180, 0])
        mirror([stowed_side == "right" ? 0 : 1, 0, 0]) handle_local();
}

// ------------------------------------------------------------------ panel bits

module panel_cutout() {
    circle(d = panel_hole_d);
    mount_panel_holes();
    for (r = [0, 90]) rotate(r) square([60, 0.3], center = true);
}

// A small piece of printed "panel" with the holes in it, for test fitting.
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

module microswitch_dummy() {
    color("steelblue") translate([sw_x - sw_len/2, sw_plate_y - sw_t, sw_body_bottom]) cube([sw_len, sw_t, 10]);
}

module panel_slab() {
    color([0.30, 0.31, 0.33]) difference() {
        translate([0, 0, -panel_thickness]) linear_extrude(panel_thickness) difference() {
            translate([-80, -60]) square([160, 120]);
            circle(d = panel_hole_d);
            mount_panel_holes();
        }
        translate([0, 0, -panel_thickness]) mount_panel_countersinks();
    }
}

module sec() {
    if (part == "section") difference() { children(); translate([-150, 0, -150]) cube([300, 300, 400]); }
    else children();
}

module assembly(slab = true, set = brake_state == "set") {
    dz = set ? -travel + notch_depth : 0;
    a  = set ? twist * twist_dir : 0;
    if (slab) sec() panel_slab();
    color([0.1, 0.1, 0.1]) sec() escutcheon();
    color("darkorange") sec() housing();
    color("goldenrod") sec() rear_cap();
    sec() mount_hardware_dummy(panel_thickness);
    microswitch_dummy();
    color("silver") sec() translate([0, 0, dz]) rotate([0, 0, a]) shaft();
    color([0.08, 0.08, 0.08]) sec() translate([0, 0, dz]) rotate([0, 0, a]) mounted_handle();
}

module exploded() {
    panel_slab();
    color([0.1, 0.1, 0.1]) translate([0, 0, -30]) escutcheon();
    translate([0, 0, -60]) mount_hardware_dummy(panel_thickness);
    color("darkorange") translate([0, 0, 20]) housing();
    color("silver") translate([0, 0, 120]) shaft();
    color("goldenrod") translate([0, 0, 195]) rear_cap();
    color([0.08, 0.08, 0.08]) translate([0, 0, -70]) mounted_handle();
}

// For the panel layout files (panel/*.scad), which `use` this file.
module parking_brake_mounted(set = false) assembly(slab = false, set = set);
module parking_brake_panel_cutout() { circle(d = panel_hole_d); mount_panel_holes(); }
module parking_brake_panel_countersinks() mount_panel_countersinks();

// ------------------------------------------------------------------ output

// Views are turned so the panel stands upright with the pilot looking at it (+y up).
if (part == "assembly" || part == "section") rotate([90, 0, 0]) assembly();
else if (part == "exploded") rotate([90, 0, 0]) exploded();
else if (part == "housing") housing();
else if (part == "shaft") translate([0, 0, -z_nose]) shaft();
else if (part == "handle") translate([0, 0, grip_t/2]) rotate([90, 0, 0]) handle_local();
else if (part == "escutcheon") translate([0, 0, panel_thickness + esc_t]) escutcheon();
else if (part == "rear_cap") translate([0, 0, -z_top]) rear_cap();
else if (part == "panel_test_plate") panel_test_plate();
else if (part == "panel_cutout") panel_cutout();

echo(str("Panel screws: 4x M3 x ", mount_screw_len(panel_thickness), " countersunk + 4x M3 nuts"));
echo(str("Threaded rod: M3 x ~", ceil(z_tail_top - (z_handle_back - handle_nut_v) - 1), " mm"));
echo(str("Spring: OD <= ", chamber_d - 2, " mm, ID >= ", shaft_d + 1,
         " mm, free length ~", spring_space + 4, " mm, must compress to < ", spring_space - travel - 2, " mm"));
