// Cessna 172-style PARKING BRAKE control for a home sim panel
// Pull the T-handle out, twist it 90 deg to lock. Twist back and the spring
// pulls it home. A microswitch on the rear cap reports the handle position.
//
// Render one part:  openscad -D 'part="housing"' -o housing.stl parking_brake.scad
// Parts: housing, shaft, handle, bezel, rear_cap, panel_cutout (2D), assembly, exploded

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, exploded, section, housing, shaft, handle, bezel, rear_cap, panel_cutout]
// Assembly view only: show the brake released or set
brake_state = "set"; // [released, set]

/* [Mechanism] */
// How far the handle pulls out (mm)
travel = 25;
// Twist to lock (degrees)
twist = 90;
// 1 = locks clockwise as seen by the pilot, -1 = counter-clockwise
twist_dir = 1;
// Depth of the detent notch the lug drops into when set (mm)
notch_depth = 3;

/* [Handle] */
handle_width = 46;
handle_height = 14;
handle_label = "PARK BRAKE";
// Gap between the bezel and the back of the handle when pushed in
handle_gap = 3;

/* [Panel trim] */
bezel_t = 3;
bezel_d = 44;

/* [Hidden] */
shaft_d      = 10;
collar_d     = 18;
collar_h     = 8;
tail_protrude = 5;        // tail sticks out of the rear cap this much when IN
housing_od   = 28;
chamber_d    = collar_d + 1;
flange_d     = 44;
flange_t     = 5;
screw_r      = 17;        // panel screw radius (bezel + flange)
spring_space = 40;        // floor-to-collar when handle is in
chamber_len  = spring_space + collar_h;
z_top        = flange_t + chamber_len;   // rear face of housing
cap_t        = 4;
ear_r        = 18;        // rear cap screw radius
ear_w        = 9;
ear_h        = 4;
panel_hole_d = 16;
socket_depth = 10;
flat_depth   = 1;         // D-flat that keys the handle to the shaft
rod_d        = 3.4;       // M3 threaded rod through the shaft
lug_w        = 4;
lug_h        = 4;
lug_r_in     = collar_d / 2 - 1;
lug_r_out    = housing_od / 2 - 1;
z_lug        = z_top - collar_h / 2;
z_handle_back = -(panel_thickness + bezel_t + handle_gap);
z_nose       = z_handle_back - socket_depth + 0.5;
z_tail_top   = z_top + cap_t + tail_protrude;
handle_boss_h = 5;
handle_depth = handle_boss_h + 12;
z_handle_nut = socket_depth + 3;     // in handle print coordinates

// Microswitch (KW11 / SS-5GL style, 20 x 10 x 6.4 mm, M2 holes 9.5 mm apart)
sw_len = 20; sw_t = 6.4; sw_hole_pitch = 9.5;
sw_x = 2;                        // switch centre offset along X
sw_plate_y = shaft_d / 2 + 1;    // plate clears the tail; switch face sits against it
sw_plate_t = 3;
sw_body_bottom = z_tail_top + 1.5;   // lever side of the switch body
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

// Lug placed at rotation a and axial offset dz from its "handle in" spot.
module lug_at(a, dz, g = 0, rout = lug_r_out) {
    translate([0, 0, z_lug + dz]) rotate([0, 0, a]) lug(g, rout);
}

// Bayonet (L) slot: axial run, 90 deg turn at full travel, detent notch.
// Pilot looks along +Z, so a clockwise twist for them is a +angle here.
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

module ear_block(hole_d, z0, h, gusset) {
    for (a = [90, 270]) rotate([0, 0, a]) difference() {
        hull() {
            translate([housing_od/2 - 2, -ear_w/2, z0]) cube([ear_r + ear_w/2 - housing_od/2 + 2, ear_w, h]);
            if (gusset)   // 45 deg support so it prints without supports
                translate([housing_od/2 - 2, -ear_w/2, z0 - (ear_r + ear_w/2 - housing_od/2)])
                    cube([0.1, ear_w, 0.1]);
        }
    }
}

module housing() {
    difference() {
        union() {
            cylinder(d = flange_d, h = flange_t);
            cylinder(d = housing_od, h = z_top);
            ear_block(m3_tap_d(), z_top - ear_h, ear_h, true);
        }
        // spring / collar chamber, open at the rear
        translate([0, 0, flange_t]) cylinder(d = chamber_d, h = chamber_len + 1);
        // front bearing bore
        translate([0, 0, -1]) cylinder(d = shaft_d + 2 * clearance + 0.3, h = flange_t + 2);
        translate([0, 0, -0.01]) cylinder(d1 = shaft_d + 2, d2 = shaft_d, h = 1);
        slot_cutter();
        // panel screws (from the front, through bezel + panel)
        for (x = [-screw_r, screw_r]) translate([x, 0, -1]) cylinder(d = m3_tap_d(), h = flange_t + 2);
        // rear cap screws
        for (a = [90, 270]) rotate([0, 0, a]) translate([ear_r, 0, z_top - 12])
            cylinder(d = m3_tap_d(), h = 13);
        // mark the 12 o'clock side for orientation
        translate([0, flange_d/2 - 3, flange_t - 0.6]) cylinder(d = 2, h = 1);
    }
}

// ------------------------------------------------------------------ shaft
// Modelled in "handle in" position. Prints nose-down with no supports.

module shaft() {
    cone_h = (collar_d - shaft_d) / 2;
    difference() {
        union() {
            translate([0, 0, z_nose]) cylinder(d = shaft_d, h = z_top - z_nose);
            translate([0, 0, z_top - collar_h]) cylinder(d = collar_d, h = collar_h);
            translate([0, 0, z_top - collar_h - cone_h]) cylinder(d1 = shaft_d, d2 = collar_d, h = cone_h + 0.01);
            // tail that presses the microswitch
            translate([0, 0, z_top - 0.01]) cylinder(d = shaft_d, h = z_tail_top - z_top - 1);
            translate([0, 0, z_tail_top - 1]) cylinder(d1 = shaft_d, d2 = shaft_d - 2, h = 1);
            lug_at(0, 0);
        }
        // D-flat that keys the handle
        translate([shaft_d/2 - flat_depth, -shaft_d, z_nose - 1])
            cube([shaft_d, 2 * shaft_d, z_handle_back - z_nose + 2]);
        // M3 rod through the middle, nut sunk into the tail
        translate([0, 0, z_nose - 1]) cylinder(d = rod_d, h = z_tail_top - z_nose + 2);
        translate([0, 0, z_tail_top - m3_nut_t - 0.6]) rotate([0, 0, 30]) m3_nut_pocket(5);
        // small chamfer on the nose so it starts into the handle easily
        translate([0, 0, z_nose - 0.01]) difference() {
            cylinder(d = shaft_d + 2, h = 0.8);
            cylinder(d1 = shaft_d - 1.6, d2 = shaft_d, h = 0.8);
        }
    }
}

// ------------------------------------------------------------------ rear cap

module rear_cap() {
    difference() {
        union() {
            translate([0, 0, z_top]) cylinder(d = housing_od, h = cap_t);
            ear_block(m3_clear_d, z_top, cap_t, false);
            // microswitch plate
            translate([sw_x - sw_len/2 - 2, sw_plate_y, z_top])
                cube([sw_len + 4, sw_plate_t, sw_plate_top - z_top]);
            // ribs
            for (x = [sw_x - sw_len/2 - 2, sw_x + sw_len/2 - 0.5]) hull() {
                translate([x, sw_plate_y, z_top]) cube([2.5, sw_plate_t + 7, cap_t]);
                translate([x, sw_plate_y, z_top]) cube([2.5, sw_plate_t, sw_plate_top - z_top - 4]);
            }
        }
        // tail passes through here
        translate([0, 0, z_top - 1]) cylinder(d = shaft_d + 2 * clearance + 0.4, h = cap_t + 2);
        translate([0, 0, z_top - 0.01]) cylinder(d1 = shaft_d + 2.5, d2 = shaft_d + 0.6, h = 1.2);
        // cap screws (pan or socket head M3)
        for (a = [90, 270]) rotate([0, 0, a]) translate([ear_r, 0, z_top - 1])
            cylinder(d = m3_clear_d, h = cap_t + 2);
        // vertical slots for the switch screws -> adjust the trip point
        for (dx = [-sw_hole_pitch/2, sw_hole_pitch/2]) hull()
            for (z = [sw_slot_lo, sw_slot_hi])
                translate([sw_x + dx, sw_plate_y - 1, z]) rotate([-90, 0, 0])
                    cylinder(d = m2_clear_d, h = sw_plate_t + 2);
    }
}

// ------------------------------------------------------------------ bezel (front trim ring)

module bezel() {
    zf = -(panel_thickness + bezel_t);
    difference() {
        union() {
            translate([0, 0, zf]) hull() {
                translate([0, 0, 1.2]) cylinder(d = bezel_d, h = bezel_t - 1.2);
                cylinder(d = bezel_d - 2.4, h = bezel_t);
            }
            // spigot centres the bezel in the panel hole
            translate([0, 0, -panel_thickness - 0.01])
                cylinder(d = panel_hole_d - 2 * clearance, h = panel_thickness - 0.8);
        }
        translate([0, 0, zf - 1]) cylinder(d = shaft_d + 2.5, h = bezel_t + panel_thickness + 2);
        for (x = [-screw_r, screw_r]) translate([x, 0, 0])
            mirror([0, 0, 1]) m3_countersunk(bezel_t + 1, top = panel_thickness + bezel_t);
    }
}

// ------------------------------------------------------------------ handle
// Print coordinates: back face (socket) on the bed, labelled face up.

module handle() {
    cb = 1.5;
    difference() {
        union() {
            cylinder(d = 18, h = handle_boss_h + 0.01);
            translate([0, 0, handle_boss_h]) hull() {
                linear_extrude(handle_depth - handle_boss_h - cb) rounded_rect([handle_width, handle_height], 5);
                linear_extrude(handle_depth - handle_boss_h) offset(-cb) rounded_rect([handle_width, handle_height], 5);
            }
        }
        // D-shaped socket (flat on -X here; flips to +X when mounted)
        translate([0, 0, -0.01]) linear_extrude(socket_depth) difference() {
            circle(d = shaft_d + 2 * clearance);
            translate([-shaft_d - (shaft_d/2 - flat_depth) + clearance, -shaft_d]) square([shaft_d, 2 * shaft_d]);
        }
        translate([0, 0, -0.01]) cylinder(d1 = shaft_d + 1.2, d2 = shaft_d, h = 0.6);
        // rod + captive nut, nut slides in from the underside
        cylinder(d = rod_d, h = z_handle_nut + 3);
        translate([0, 0, z_handle_nut - (m3_nut_t + 0.4) / 2]) hull() {
            rotate([0, 0, 30]) m3_nut_pocket(m3_nut_t + 0.4);
            translate([0, -handle_height, 0]) rotate([0, 0, 30]) m3_nut_pocket(m3_nut_t + 0.4);
        }
        // label
        if (len(handle_label) > 0)
            translate([0, 0, handle_depth - 0.6]) linear_extrude(1)
                text(handle_label, size = 3.6, font = "Liberation Sans:style=Bold",
                     halign = "center", valign = "center");
    }
}

// ------------------------------------------------------------------ panel cutout (2D)

module panel_cutout() {
    difference() {
        circle(d = bezel_d + 1);
        circle(d = bezel_d + 0.6);
    }
    circle(d = panel_hole_d);
    for (x = [-screw_r, screw_r]) translate([x, 0]) circle(d = m3_clear_d);
    // centre marks
    for (r = [0, 90]) rotate(r) square([bezel_d + 10, 0.3], center = true);
}

// ------------------------------------------------------------------ views

module mounted_handle() {
    translate([0, 0, z_handle_back]) rotate([0, 180, 0]) handle();
}

module moving_parts() {
    color("silver") shaft();
    color([0.12, 0.12, 0.12]) mounted_handle();
}

module microswitch_dummy() {
    color("steelblue") translate([sw_x - sw_len/2, sw_plate_y - sw_t, sw_body_bottom])
        cube([sw_len, sw_t, 10]);
    color("lightgray") translate([sw_x - sw_len/2 + 2, sw_plate_y - sw_t/2 - 0.5, sw_body_bottom - 1.4]) cube([sw_len - 1, 1, 0.4]);
}

module panel_slab() {
    color([0.35, 0.35, 0.38], 0.55) translate([0, 0, -panel_thickness]) linear_extrude(panel_thickness)
        difference() {
            translate([-60, -45]) square([120, 90]);
            circle(d = panel_hole_d);
            for (x = [-screw_r, screw_r]) translate([x, 0]) circle(d = m3_clear_d);
        }
}

// Cuts away the -Y half when part == "section" so you can see inside.
module sec() {
    if (part == "section") difference() { children(); translate([-100, -200, -100]) cube([200, 200, 300]); }
    else children();
}

module assembly() {
    set = brake_state == "set";
    sec() panel_slab();
    color([0.15, 0.15, 0.15]) sec() bezel();
    color("darkorange") sec() housing();
    color("goldenrod") sec() rear_cap();
    microswitch_dummy();
    dz = set ? -travel + notch_depth : 0;
    a  = set ? twist * twist_dir : 0;
    color("silver") sec() translate([0, 0, dz]) rotate([0, 0, a]) shaft();
    color([0.12, 0.12, 0.12]) sec() translate([0, 0, dz]) rotate([0, 0, a]) mounted_handle();
}

module exploded() {
    color([0.15, 0.15, 0.15]) translate([0, 0, -40]) bezel();
    panel_slab();
    color("darkorange") housing();
    color("silver") translate([0, 0, 100]) shaft();
    color("goldenrod") translate([0, 0, 175]) rear_cap();
    color([0.12, 0.12, 0.12]) translate([0, 0, -80]) mounted_handle();
}

// ------------------------------------------------------------------ print layouts

if (part == "assembly") assembly();
else if (part == "exploded") exploded();
else if (part == "section") assembly();
else if (part == "housing") housing();
else if (part == "shaft") translate([0, 0, -z_nose]) shaft();
else if (part == "handle") handle();
else if (part == "bezel") translate([0, 0, panel_thickness + bezel_t]) bezel();
else if (part == "rear_cap") translate([0, 0, -z_top]) rear_cap();
else if (part == "panel_cutout") panel_cutout();

// ------------------------------------------------------------------ build notes
panel_screw = [for (l = [10, 12, 14, 16, 20, 25]) if (l >= bezel_t + panel_thickness + 4) l][0];
echo(str("Panel screws: 2x M3 x ", panel_screw, " countersunk (flat head)"));
echo(str("Threaded rod: M3 x ~", ceil(z_tail_top - (z_handle_back - z_handle_nut) - 1), " mm"));
echo(str("Spring: OD <= ", chamber_d - 2, " mm, ID >= ", shaft_d + 1,
         " mm, free length ~", spring_space + 4, " mm, must compress to < ",
         spring_space - travel - 2, " mm"));
echo(str("Panel hole: ", panel_hole_d, " mm, screws ", m3_clear_d, " mm at +/-", screw_r, " mm"));
