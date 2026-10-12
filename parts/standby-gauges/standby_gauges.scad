// Standby instruments for the 172S G1000 panel: airspeed, attitude, altimeter -
// working mechanical gauges, driven from the sim by MobiFlight.
//
//   AIRSPEED   a printed needle on an X27.168 gauge stepper (the kind in car
//              dashboards: 315 deg sweep with a built-in stop it zeroes against).
//   ALTIMETER  100-ft and 1000-ft hands on one 28BYJ-48 stepper: the 100-ft hand
//              turns with the motor, a printed 10:1 gear train (like a clock's
//              hour hand) turns the 1000-ft hand. A hall sensor + magnet finds
//              zero at start-up. The knob is an EC11 encoder for the baro setting.
//   ATTITUDE   two SG90 micro servos: one rolls a frame (+/-90 deg), the other,
//              inside a horizon drum on that frame, pitches the drum.
//
// Each instrument: a front case (square bezel + glass, through an 80 mm panel
// hole) and a rear housing behind the panel that carries the mechanism. Four
// long M3 screws through the bezel corners, the panel and the housing flange
// clamp it all together. The faces are paper (faces/*.svg) glued on printed parts.
//
// Modelled face-up: bezel front at z = 0, the panel face at z = -bezel_t, behind
// the panel is more negative z, x right, y up (as seen from the seat).

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, assembly_all, case, case_altimeter, glass_cutout, asi_housing, asi_face_plate, asi_needle, alt_housing, alt_front_plate, alt_back_plate, alt_arbor_gear, alt_hour_wheel, alt_lay_gear, alt_motor_pinion, alt_hand_100, alt_hand_1000, att_housing, att_ring, att_roll_frame, att_drum, panel_cutout, altimeter_cutout]
// Instrument for the single assembly view
face = "airspeed"; // [airspeed, attitude, altimeter]
// Readings for the assembly views (the animation overrides them)
show_kt = 95;
show_ft = 1150;
show_pitch = 5;
show_roll = 15;

/* [Hardware] */
// X27.168 shaft diameter (needle hub hole)
x27_shaft_d = 1.0;
// X27.168 shaft length above its case (the needle sits on top of it)
x27_shaft_h = 6.7;
// Altimeter arbor and lay shaft: 3 mm steel or brass rod
rod_d = 3;

/* [Hidden] */
hole_d = 80;          // panel hole (3-1/8" instrument)
bezel = 84;           // square bezel
bezel_t = 3;
win_d = 74;           // viewing window
cup_od = 79;
cup_id = 76;
screw = 36;           // bezel corner screws (+/-36, +/-36)
z_panel_back = -bezel_t - panel_thickness;
glass_z = -bezel_t - 1;                    // glass back face (1 mm sheet in a seat behind the window)
face_z = -10.5;                            // front of the paper faces (ASI, ALT)
plate_t = 2;
h_od = 86;                                 // rear housing: fits between neighbours 88 mm apart
h_id = 80;
flange_t = 3;
enc_corner = [-screw, -screw];             // altimeter baro knob replaces this screw

// ------------------------------------------------------------------ front case
// Bezel on the panel face + a short cup that fills the panel hole. Prints face down.
module case(kind = "airspeed") {
    alt = kind == "altimeter";
    difference() {
        union() {
            translate([0, 0, -bezel_t]) linear_extrude(bezel_t) rounded_rect([bezel, bezel], 8);
            translate([0, 0, z_panel_back + 0.3]) cylinder(d = cup_od, h = -z_panel_back - 0.3 - bezel_t + 0.01);
        }
        translate([0, 0, -bezel_t - 1]) cylinder(d = win_d, h = bezel_t + 2);           // window
        translate([0, 0, -1.2]) cylinder(d1 = win_d, d2 = win_d + 3, h = 1.21);          // chamfer
        translate([0, 0, glass_z]) cylinder(d = 76.5, h = 1.01);                         // glass seat
        translate([0, 0, z_panel_back - 1]) cylinder(d = cup_id, h = -z_panel_back - bezel_t + 1 + 0.01);
        for (x = [-screw, screw], y = [-screw, screw]) if (!(alt && [x, y] == enc_corner)) translate([x, y, -bezel_t - 1]) {
            cylinder(d = m3_clear_d, h = bezel_t + 2);
            translate([0, 0, bezel_t + 1 - 1.6]) cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.4, h = 1.61);
        }
        if (alt) translate([enc_corner[0], enc_corner[1], -bezel_t - 1]) cylinder(d = 7.4, h = bezel_t + 2);   // EC11 bushing
    }
}
// cutting guide for the 1 mm clear sheet (print on paper, or use as a 2D file)
module glass_template() difference() { circle(d = 76.3); circle(d = 1); }

// ------------------------------------------------------------------ rear housing (shared)
// Tube behind the panel with a square flange that the bezel screws clamp to the panel.
// shelf_z: where the mechanism plate is screwed on (3 x M3 from behind).
function shelf_pts() = [for (a = [90, 210, 330]) [37 * cos(a), 37 * sin(a)]];
module housing(depth, shelf_z, kind = "airspeed", back_hole = [12, 8]) {
    alt = kind == "altimeter";
    difference() {
        union() {
            translate([0, 0, z_panel_back - flange_t]) linear_extrude(flange_t) rounded_rect([h_od, h_od], 6);
            translate([0, 0, z_panel_back - depth]) cylinder(d = h_od, h = depth);
            // three bosses the mechanism plate screws to
            if (shelf_z > -900) for (p = shelf_pts()) translate([p[0], p[1], shelf_z - 6]) cylinder(d = 8, h = 6);
            translate([0, 0, z_panel_back - depth]) cylinder(d = h_od, h = 3);           // back wall
        }
        translate([0, 0, z_panel_back - depth + 3]) cylinder(d = h_id, h = depth);
        if (shelf_z > -900) for (p = shelf_pts()) translate([p[0], p[1], shelf_z - 7]) cylinder(d = m3_pilot_d, h = 8);
        // clamp screws through the flange (nuts behind)
        for (x = [-screw, screw], y = [-screw, screw]) if (!(alt && [x, y] == enc_corner))
            translate([x, y, z_panel_back - flange_t - 1]) cylinder(d = m3_clear_d, h = flange_t + 2);
        if (alt) translate([enc_corner[0] - 9, enc_corner[1] - 9, z_panel_back - flange_t - 1]) cube([18, 18, flange_t + 2]);  // encoder body
        // wires out the back
        translate([0, 0, z_panel_back - depth - 1]) linear_extrude(5) rounded_rect(back_hole, 2);
    }
}

// ------------------------------------------------------------------ AIRSPEED
asi_stop = -157.5;                  // needle against the X27's stop (below 40 kt)
asi_ang = function(kt) kt <= 40 ? asi_stop + (kt / 40) * 7.5 : -150 + (min(kt, 200) - 40) / 160 * 300;
asi_plate_z = face_z;               // paper face on the front of this plate
asi_motor_z = face_z - plate_t;     // X27 case front, glued to the back of the plate
module asi_face_plate() difference() {
    union() {
        translate([0, 0, asi_plate_z - plate_t]) cylinder(d = 75.5, h = plate_t);
        // ears that screw to the housing bosses
        for (p = shelf_pts()) hull() { translate([p[0], p[1], asi_plate_z - plate_t]) cylinder(d = 8, h = plate_t); translate([p[0] * 0.8, p[1] * 0.8, asi_plate_z - plate_t]) cylinder(d = 8, h = plate_t); }
    }
    translate([0, 0, asi_plate_z - plate_t - 1]) cylinder(d = 3, h = plate_t + 2);      // X27 shaft
    for (p = shelf_pts()) translate([p[0], p[1], asi_plate_z - plate_t - 1]) cylinder(d = m3_clear_d, h = plate_t + 2);
}
module x27_dummy() color([0.15, 0.15, 0.16]) translate([-8, -9.5, asi_motor_z - 10]) cube([30, 19, 10]);
// needle: printed flat in white, pressed onto the X27 shaft
module asi_needle() {
    difference() {
        union() {
            cylinder(d = 4.5, h = 3);
            linear_extrude(0.9) hull() { translate([0, 31]) circle(d = 0.9); circle(d = 3.2); translate([0, -8]) circle(d = 2.4); }
        }
        translate([0, 0, -0.5]) cylinder(d = x27_shaft_d - 0.05, h = 4, $fn = 24);
    }
}
module asi_mounted(kt) {
    color([0.08, 0.08, 0.08]) cutaway() housing(28, asi_plate_z - plate_t);
    color([0.2, 0.2, 0.2]) asi_face_plate();
    x27_dummy();
    color("silver") translate([0, 0, asi_motor_z]) cylinder(d = 1, h = x27_shaft_h);
    color("white") translate([0, 0, asi_motor_z + x27_shaft_h - 3]) rotate(-asi_ang(kt)) asi_needle();
}

// ------------------------------------------------------------------ ALTIMETER
// Gear train, m = module: motor pinion 20T -> centre wheel 20T (m1, 1:1, 100-ft hand);
// arbor pinion 12T -> lay wheel 40T, lay pinion 13T -> hour wheel 39T (m0.8): 10:1 to the 1000-ft hand.
alt_a_motor = 20;            // motor shaft from the centre (+x)
alt_a_lay = 20.8;            // lay shaft from the centre (-x)
alt_fp_z = face_z;           // front plate: paper face on its front
alt_fp_t = 4.5;
z_l1 = alt_fp_z - alt_fp_t - 0.5;   // layer 1: hour wheel + lay pinion (m0.8)
z_l2 = z_l1 - 3;                    // layer 2: lay wheel + arbor pinion (m0.8)
z_l3 = z_l2 - 3;                    // layer 3: centre wheel + motor pinion (m1)
gw = 2.5;                           // gear width
alt_bp_z = z_l3 - gw - 0.5;         // back plate front face
alt_bp_t = 3;
pillars = [[0, 34], [0, -34], [34, 0]];
module alt_front_plate() difference() {
    union() {
        translate([0, 0, alt_fp_z - alt_fp_t]) cylinder(d = 75.5, h = alt_fp_t);
        for (p = shelf_pts()) hull() { translate([p[0], p[1], alt_fp_z - alt_fp_t]) cylinder(d = 8, h = 2); translate([p[0] * 0.8, p[1] * 0.8, alt_fp_z - alt_fp_t]) cylinder(d = 8, h = 2); }
    }
    translate([0, 0, alt_fp_z - alt_fp_t - 1]) cylinder(d = 6.5, h = alt_fp_t + 2);              // hour-wheel tube
    translate([-alt_a_lay, 0, alt_fp_z - alt_fp_t - 1]) cylinder(d = rod_d - 0.1, h = 3);       // lay shaft, blind
    for (p = pillars) translate([p[0], p[1], alt_fp_z - alt_fp_t - 1]) cylinder(d = m3_pilot_d, h = 3);
    for (p = shelf_pts()) translate([p[0], p[1], alt_fp_z - alt_fp_t - 1]) cylinder(d = m3_clear_d, h = alt_fp_t + 2);
}
// back plate with the 28BYJ-48 on its back; pillars to the front plate
module alt_back_plate() difference() {
    union() {
        translate([0, 0, alt_bp_z - alt_bp_t]) cylinder(d = 76, h = alt_bp_t);
        for (p = pillars) translate([p[0], p[1], alt_bp_z - 0.01]) cylinder(d = 6, h = alt_fp_z - alt_fp_t - alt_bp_z + 0.01);
    }
    translate([0, 0, alt_bp_z - 2]) cylinder(d = rod_d - 0.1, h = 3);                          // arbor, blind
    translate([-alt_a_lay, 0, alt_bp_z - 2]) cylinder(d = rod_d - 0.1, h = 3);                  // lay shaft, blind
    for (p = pillars) translate([p[0], p[1], alt_bp_z - alt_bp_t - 1]) cylinder(d = m3_clear_d, h = 40);
    // 28BYJ-48: shaft boss through the plate, M4 screws in its ears (35 mm apart)
    translate([alt_a_motor, 0, alt_bp_z - alt_bp_t - 1]) cylinder(d = 9.6, h = alt_bp_t + 2);
    for (s = [-1, 1]) translate([alt_a_motor - 8, s * 17.5, alt_bp_z - alt_bp_t - 1]) cylinder(d = 4.3, h = alt_bp_t + 2);
    // hall sensor (A3144) pocket under the centre wheel's magnet, and its wire slot
    translate([-2, 4, alt_bp_z - 1.6]) cube([4, 3.2, 2]);
    translate([-1.5, 7, alt_bp_z - alt_bp_t - 1]) cube([3, 2, alt_bp_t + 2]);
}
module byj_dummy() color([0.75, 0.76, 0.78]) translate([alt_a_motor - 8, 0, alt_bp_z - alt_bp_t - 19]) {
    cylinder(d = 28, h = 19);
    translate([0, 0, 18.99]) linear_extrude(0.8) hull() for (s = [-1, 1]) translate([0, s * 17.5]) circle(d = 7);
}
module alt_arbor_gear() difference() {      // centre wheel (100-ft) + arbor pinion, pressed on the 3 mm arbor
    union() {
        translate([0, 0, z_l3 - gw]) spur_gear(1, 20, gw);
        translate([0, 0, z_l2 - gw]) spur_gear(0.8, 12, gw + 0.6);
    }
    translate([0, 0, z_l3 - gw - 1]) cylinder(d = rod_d - 0.15, h = 10);
    translate([0, 5.5, z_l3 - gw - 0.01]) cylinder(d = 3.1, h = 2);                             // 3 x 2 mm magnet
}
module alt_hour_wheel() difference() {      // 39T + tube to the 1000-ft hand
    union() {
        translate([0, 0, z_l1 - gw]) spur_gear(0.8, 39, gw);
        translate([0, 0, z_l1 - gw]) cylinder(d = 6, h = face_z + 0.5 - (z_l1 - gw));
    }
    translate([0, 0, z_l1 - gw - 1]) cylinder(d = rod_d + 0.3, h = 30);
}
module alt_lay_gear() difference() {        // 40T + 13T, turns on the lay shaft
    union() {
        translate([-alt_a_lay, 0, z_l2 - gw]) spur_gear(0.8, 40, gw);
        translate([-alt_a_lay, 0, z_l1 - gw - 0.01]) spur_gear(0.8, 13, gw + 0.01);
    }
    translate([-alt_a_lay, 0, z_l2 - gw - 1]) cylinder(d = rod_d + 0.3, h = 10);
}
module alt_motor_pinion() difference() {    // 20T on the 28BYJ-48 shaft (5 mm with two flats, 3 mm across)
    translate([alt_a_motor, 0, z_l3 - gw]) spur_gear(1, 20, gw);
    translate([alt_a_motor, 0, z_l3 - gw - 1]) linear_extrude(gw + 2) intersection() { circle(d = 5.1); square([3.15, 6], center = true); }
}
// hands, printed flat in white
module alt_hand_100() difference() {
    union() {
        cylinder(d = 5, h = 2.4);
        linear_extrude(0.9) hull() { translate([0, 30]) circle(d = 1); circle(d = 3); translate([0, -7]) circle(d = 2.5); }
    }
    translate([0, 0, -0.5]) cylinder(d = rod_d - 0.1, h = 4);
}
module alt_hand_1000() difference() {
    union() {
        cylinder(d = 8, h = 1.6);
        linear_extrude(1.0) hull() { translate([0, 19]) circle(d = 2.2); circle(d = 5); }
    }
    translate([0, 0, -0.5]) cylinder(d = 6.1, h = 3);
}
module alt_mounted(ft) {
    a100 = -ft / 1000 * 360; a1000 = -ft / 10000 * 360;
    color([0.08, 0.08, 0.08]) cutaway() housing(48, alt_fp_z - alt_fp_t, "altimeter", [16, 10]);
    color([0.2, 0.2, 0.2]) alt_front_plate();
    color([0.35, 0.35, 0.37]) alt_back_plate();
    byj_dummy();
    color("silver") translate([0, 0, alt_bp_z - 2]) cylinder(d = rod_d, h = face_z + 4.6 - (alt_bp_z - 2));       // arbor
    color("silver") translate([-alt_a_lay, 0, alt_bp_z - 2]) cylinder(d = rod_d, h = alt_fp_z - alt_fp_t + 1 - alt_bp_z + 2);
    color("goldenrod") rotate(a100) alt_arbor_gear();
    color("orange") rotate(a1000) alt_hour_wheel();
    color("gold") translate([-alt_a_lay, 0]) rotate(-a100 * 12 / 40) translate([alt_a_lay, 0]) alt_lay_gear();
    color("goldenrod") translate([alt_a_motor, 0]) rotate(-a100) translate([-alt_a_motor, 0]) alt_motor_pinion();
    color("white") translate([0, 0, face_z + 0.5]) rotate(a1000) alt_hand_1000();
    color("white") translate([0, 0, face_z + 2.3]) rotate(a100) alt_hand_100();
    // baro knob on its encoder
    color([0.1, 0.1, 0.1]) translate([enc_corner[0], enc_corner[1], 0]) { cylinder(d = 12, h = 9); }
    color([0.2, 0.2, 0.2]) translate([enc_corner[0] - 6, enc_corner[1] - 6, -bezel_t - 7]) cube([12, 12, 7]);
}

// ------------------------------------------------------------------ ATTITUDE
// Fixed: glass, then a ring with the bank scale (paper) and the orange aircraft symbol.
// Moving: the roll frame (front disc with sky/ground + bank pointer, one side arm,
// a back plate on the roll servo's horn) and the horizon drum on the pitch servo.
att_ring_z = glass_z - 0.1;          // fixed ring front
att_disc_z = -6.6;                   // roll disc front
att_disc_t = 1.6;
drum_r = 28; drum_l = 50; drum_wall = 1.6;
drum_z = att_disc_z - att_disc_t - 0.7 - drum_r;    // drum axis
arm_x = -drum_l / 2 - 4.5;           // left arm (inner face at -drum_l/2 - 1.5)
att_bp_z = drum_z - drum_r - 2.5;    // frame back plate front
// SG90: case 22.5 x 12.2 x 22.7 (+ 4 mm spline), tabs 32.2 long at 15.9-18.4 from the base, shaft 5.9 off-centre
sg = [22.5, 12.2, 22.7]; sg_tab = [32.2, 2.5, 15.9]; sg_off = 5.9;
// pitch servo: shaft on the drum axis pointing +x, horn face against the drum's end wall
p_base_x = drum_l / 2 - drum_wall - 28.5;
roll_base_z = att_bp_z - att_disc_t - 26;     // roll servo base (shaft forward)
module sg90(tabs = true) {      // shaft along +z at the origin, base at z = 0... body along x
    translate([-sg[0] / 2 - sg_off, -sg[1] / 2, 0]) cube(sg);
    if (tabs) translate([-sg_tab[0] / 2 - sg_off, -sg[1] / 2, sg_tab[2]]) cube([sg_tab[0], sg[1], sg_tab[1]]);
    translate([0, 0, sg[2]]) cylinder(d = 4.8, h = 4);
}
module att_ring() {   // print in orange, glue the paper bank scale on the ring
    z0 = att_ring_z - 1.2;
    difference() { translate([0, 0, z0]) cylinder(d = 75.6, h = 1.2); translate([0, 0, z0 - 1]) cylinder(d = 66, h = 3); }
    // stem up from the bottom and the aircraft symbol
    translate([0, 0, z0]) linear_extrude(1.2) {
        translate([-1.2, -34]) square([2.4, 34]);
        for (s = [-1, 1]) hull() { translate([s * 3, -1.8]) circle(d = 2.2); translate([s * 7, 0]) circle(d = 1.8); }
        for (s = [-1, 1]) hull() { translate([s * 7, 0]) circle(d = 1.8); translate([s * 20, 0]) circle(d = 1.8); }
        circle(d = 2.6);
    }
}
module att_roll_frame() {
    zf = att_disc_z - att_disc_t;
    difference() {
        union() {
            translate([0, 0, zf]) cylinder(d = 64, h = att_disc_t);                                     // front disc
            translate([arm_x - 1.5, -10, att_bp_z - att_disc_t]) cube([3, 20, zf - att_bp_z + att_disc_t + 0.01]);   // side arm
            hull() {                                                                                   // back plate
                translate([0, 0, att_bp_z - att_disc_t]) cylinder(d = 26, h = att_disc_t);
                translate([arm_x - 1.5, -10, att_bp_z - att_disc_t]) cube([3, 20, att_disc_t]);
            }
            translate([-3, -drum_r - 4.5, att_bp_z - att_disc_t]) cube([6, 3, zf - att_bp_z + att_disc_t + 0.01]);   // lower brace
            // pitch servo bracket: a beam in from the arm and a plate round the servo under its tabs
            translate([arm_x, -4, drum_z - 12.5]) cube([p_base_x + sg_tab[2] - arm_x, 8, 6]);
            translate([p_base_x + sg_tab[2] - 3, -sg[1] / 2 - 2, drum_z + sg_off - sg_tab[0] / 2 - 1]) cube([3, sg[1] + 4, sg_tab[0] + 2]);
        }
        translate([0, 0, zf - 1]) cylinder(d = 46, h = att_disc_t + 2);                                  // view of the drum
        // servo body through the bracket plate, tab screws
        translate([p_base_x - 1, -sg[1] / 2 - 0.3, drum_z + sg_off - sg[0] / 2 - 0.3]) cube([sg_tab[2] + 2, sg[1] + 0.6, sg[0] + 0.6]);
        for (d = [-sg_tab[0] / 2 + 2.3, sg_tab[0] / 2 - 2.3]) translate([p_base_x + sg_tab[2] - 4, 0, drum_z + sg_off + d]) rotate([0, 90, 0]) cylinder(d = 1.8, h = 6);
        // roll servo horn: round horn recess + screw
        translate([0, 0, att_bp_z - att_disc_t - 0.01]) cylinder(d = 20.5, h = 0.8);
        translate([0, 0, att_bp_z - att_disc_t - 1]) cylinder(d = 2.5, h = 4);
        // cable slot along the arm
        translate([arm_x - 2, -2, att_bp_z]) cube([4, 4, 10]);
    }
}
module att_drum() {   // open at the left, the right wall screws to the pitch servo's round horn
    difference() {
        rotate([0, 90, 0]) translate([0, 0, -drum_l / 2]) difference() {
            cylinder(r = drum_r, h = drum_l, $fn = 96);
            translate([0, 0, -1]) cylinder(r = drum_r - drum_wall, h = drum_l - drum_wall + 1, $fn = 96);
        }
        translate([drum_l / 2 - drum_wall - 1, 0, 0]) rotate([0, 90, 0]) cylinder(d = 2.5, h = 4);       // horn screw
        translate([drum_l / 2 - drum_wall - 0.6, 0, 0]) rotate([0, 90, 0]) cylinder(d = 20.5, h = 0.61);  // horn recess
    }
}
att_depth = z_panel_back - roll_base_z - sg_tab[2] + 3;    // back wall carries the roll servo's tabs
module att_housing() housing(att_depth, -999, "attitude", [0.1, 0.1]);
// the roll servo sits through a hole in the housing's back wall, tabs on the wall
module att_housing_full() difference() {
    att_housing();
    translate([-sg[0] / 2 - sg_off - 0.3, -sg[1] / 2 - 0.3, roll_base_z - 1]) cube([sg[0] + 0.6, sg[1] + 0.6, 30]);
    for (d = [-sg_tab[0] / 2 + 2.3, sg_tab[0] / 2 - 2.3]) translate([-sg_off + d, 0, roll_base_z]) cylinder(d = 1.8, h = 30);
    translate([-sg_off - sg[0] / 2 - 6, -3, roll_base_z]) cube([5, 6, 30]);       // cables
}
module att_mounted(pitch, roll) {
    color([0.08, 0.08, 0.08]) cutaway() att_housing_full();
    color([1, 0.55, 0.05]) att_ring();
    color([0.1, 0.1, 0.12]) translate([0, 0, roll_base_z]) sg90();                        // roll servo
    rotate(roll) {
        color([0.3, 0.3, 0.33]) att_roll_frame();
        // paper on the roll disc: sky / ground halves and the bank pointer
        translate([0, 0, att_disc_z]) {
            color([0.25, 0.5, 0.9]) render() intersection() { difference() { cylinder(d = 64, h = 0.15); translate([0, 0, -1]) cylinder(d = 46, h = 3); } translate([-40, 0, -1]) cube([80, 40, 3]); }
            color([0.55, 0.36, 0.17]) render() intersection() { difference() { cylinder(d = 64, h = 0.15); translate([0, 0, -1]) cylinder(d = 46, h = 3); } translate([-40, -40, -1]) cube([80, 40, 3]); }
            color("white") linear_extrude(0.25) polygon([[0, 31.5], [-2.2, 27.5], [2.2, 27.5]]);
        }
        color([0.1, 0.1, 0.12]) translate([p_base_x, 0, drum_z]) rotate([0, 90, 0]) sg90();   // pitch servo
        translate([0, 0, drum_z]) rotate([2 * pitch, 0, 0]) translate([0, 0, -drum_z]) translate([0, 0, drum_z]) {
            color([0.55, 0.36, 0.17]) render() intersection() { att_drum(); translate([-30, -40, -40]) cube([60, 40, 80]); }
            color([0.25, 0.5, 0.9]) render() intersection() { att_drum(); translate([-30, 0, -40]) cube([60, 40, 80]); }
            color("white") render() intersection() { att_drum(); translate([-30, -0.4, 0]) cube([60, 0.8, 40]); }
        }
    }
}

// ------------------------------------------------------------------ panel cut-out
module panel_cutout(kind = "airspeed") {
    circle(d = hole_d);
    for (x = [-screw, screw], y = [-screw, screw]) if (!(kind == "altimeter" && [x, y] == enc_corner)) translate([x, y]) circle(d = m3_clear_d);
    if (kind == "altimeter") translate(enc_corner) square(14, center = true);      // baro encoder body
}

// ------------------------------------------------------------------ views
// in the animations (ghost = true) the housings are cut open on the right so the mechanism shows
module cutaway() if (ghost) difference() { children(); translate([0, -60, -200]) cube([60, 120, 190]); } else children();
// paper faces as flat colour, for renders
module face_dummy(kind) {
    if (kind == "airspeed" || kind == "altimeter") translate([0, 0, face_z]) {
        color([0.06, 0.06, 0.06]) cylinder(d = 75, h = 0.2);
        color("white") for (a = [0 : (kind == "altimeter" ? 36 : 30) : 359]) rotate(a) translate([31, -0.4, 0.2]) cube([5, 0.8, 0.1]);
        if (kind == "airspeed") {
            color([0.1, 0.7, 0.2]) translate([0, 0, 0.25]) rotate(90 - asi_ang(129)) rotate_extrude(angle = asi_ang(129) - asi_ang(48)) translate([32.5, 0]) square([2, 0.1]);
            color([1, 0.85, 0]) translate([0, 0, 0.25]) rotate(90 - asi_ang(163)) rotate_extrude(angle = asi_ang(163) - asi_ang(129)) translate([32.5, 0]) square([2, 0.1]);
        }
    } else {
        translate([0, 0, att_ring_z]) {
            color([0.06, 0.06, 0.06]) difference() { cylinder(d = 75.6, h = 0.12); translate([0, 0, -1]) cylinder(d = 66, h = 3); }
            color("white") for (a = [-60, -30, -20, -10, 0, 10, 20, 30, 60]) rotate(a) translate([-0.4, 33.2, 0.1]) cube([0.8, a % 30 == 0 ? 4 : 2.5, 0.05]);
        }
    }
}
function a_kt() = anim < 0 ? show_kt : lookup(anim, [[0, 0], [0.1, 0], [0.4, 120], [0.55, 120], [0.7, 65], [0.9, 0], [1, 0]]);
function a_ft() = anim < 0 ? show_ft : lookup(anim, [[0, 0], [0.1, 0], [0.6, 3500], [0.75, 3500], [1, 0]]);
function a_pitch() = anim < 0 ? show_pitch : lookup(anim, [[0, 0], [0.1, 10], [0.3, 10], [0.45, 0], [0.75, -8], [0.9, 0], [1, 0]]);
function a_roll() = anim < 0 ? show_roll : lookup(anim, [[0, 0], [0.15, 0], [0.3, 30], [0.5, 30], [0.65, -45], [0.85, 0], [1, 0]]);
module instrument_mounted(kind = "airspeed") {
    color([0.08, 0.08, 0.08]) case(kind);
    face_dummy(kind);
    if (kind == "airspeed") asi_mounted(a_kt());
    else if (kind == "altimeter") alt_mounted(a_ft());
    else att_mounted(a_pitch(), a_roll());
}
module gauge_cutout_2d(kind = "airspeed") panel_cutout(kind);
function gauge_bezel_t() = bezel_t;

// ------------------------------------------------------------------ output (print orientations)
module flat(z) translate([0, 0, -z]) children();
if (part == "assembly") instrument_mounted(face);
else if (part == "assembly_all") for (i = [0 : 2]) translate([(i - 1) * 88, 0, 0]) instrument_mounted(["airspeed", "attitude", "altimeter"][i]);
else if (part == "case") rotate([180, 0, 0]) case();
else if (part == "case_altimeter") rotate([180, 0, 0]) case("altimeter");
else if (part == "glass_cutout") glass_template();
else if (part == "asi_housing") rotate([180, 0, 0]) translate([0, 0, -z_panel_back]) housing(28, asi_plate_z - plate_t);
else if (part == "asi_face_plate") flat(asi_plate_z - plate_t) asi_face_plate();
else if (part == "asi_needle") asi_needle();
else if (part == "alt_housing") rotate([180, 0, 0]) translate([0, 0, -z_panel_back]) housing(48, alt_fp_z - alt_fp_t, "altimeter", [16, 10]);
else if (part == "alt_front_plate") rotate([180, 0, 0]) flat(alt_fp_z) alt_front_plate();
else if (part == "alt_back_plate") flat(alt_bp_z - alt_bp_t) alt_back_plate();
else if (part == "alt_arbor_gear") flat(z_l3 - gw) alt_arbor_gear();
else if (part == "alt_hour_wheel") flat(z_l1 - gw) alt_hour_wheel();
else if (part == "alt_lay_gear") flat(z_l2 - gw) translate([alt_a_lay, 0, 0]) alt_lay_gear();
else if (part == "alt_motor_pinion") flat(z_l3 - gw) translate([-alt_a_motor, 0, 0]) alt_motor_pinion();
else if (part == "alt_hand_100") alt_hand_100();
else if (part == "alt_hand_1000") alt_hand_1000();
else if (part == "att_housing") rotate([180, 0, 0]) translate([0, 0, -z_panel_back]) att_housing_full();
else if (part == "att_ring") flat(att_ring_z - 1.2) att_ring();
else if (part == "att_roll_frame") rotate([180, 0, 0]) flat(att_disc_z) att_roll_frame();
else if (part == "att_drum") rotate([0, -90, 0]) translate([-drum_l / 2, 0, 0]) att_drum();
else if (part == "panel_cutout") panel_cutout("airspeed");
else if (part == "altimeter_cutout") panel_cutout("altimeter");

echo(str("Altimeter: 100-ft hand 1:1 with the 28BYJ-48 (one motor turn = 1000 ft), 1000-ft hand 10:1. Attitude: drum turns 2 deg per deg of pitch."));
