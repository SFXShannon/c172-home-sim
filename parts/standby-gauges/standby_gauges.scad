// Standby instruments for the 172S G1000 panel: airspeed, attitude, altimeter.
//
// Each one is a printed 3-1/8" instrument case: a square black bezel on the
// panel face and a cup behind it that holds a printed face (faces/*.svg - print
// them at 100% on photo paper, cut out, glue onto the face disc). A clear disc
// cut from a plastic sheet can sit in front as the glass.
// They're static (the screens show the real data); swap the face for a 2.1"
// round LCD later if you like.
//
// The panel just needs an 80 mm hole and 4 screw holes per instrument; the
// bezel bridges a tile seam, so seams can pass through the instruments.
// Modelled face-up, face at z = 0.

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, case, face_disc, panel_cutout]
// Which face to show in the assembly render
face = "airspeed"; // [airspeed, attitude, altimeter]

/* [Hidden] */
hole_d = 80;          // panel hole (3-1/8" instrument)
bezel = 84;           // square bezel
bezel_t = 3;
win_d = 74;           // viewing window
cup_d = hole_d - 1;
cup_depth = 24;
face_depth = 8;       // face sits this far behind the bezel front
screw = 36;           // screws at the bezel corners (+/-36, +/-36)

module case() {
    difference() {
        union() {
            translate([0, 0, -bezel_t]) linear_extrude(bezel_t) rounded_rect([bezel, bezel], 8);
            translate([0, 0, -cup_depth]) cylinder(d = cup_d, h = cup_depth - bezel_t + 0.01);
        }
        // window + chamfer
        translate([0, 0, -bezel_t - 1]) cylinder(d = win_d, h = bezel_t + 2);
        translate([0, 0, -1.2]) cylinder(d1 = win_d, d2 = win_d + 3, h = 1.21);
        // cavity for glass + face disc
        translate([0, 0, -cup_depth + 2]) cylinder(d = cup_d - 3, h = cup_depth - bezel_t - 2 + 0.01);
        // glass seat right behind the window
        translate([0, 0, -bezel_t - 1]) cylinder(d = 76.5, h = 1.01);
        // screws
        for (x = [-screw, screw], y = [-screw, screw]) translate([x, y, -bezel_t - 1]) {
            cylinder(d = m3_clear_d, h = bezel_t + 2);
            translate([0, 0, bezel_t + 1 - 1.6]) cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.4, h = 1.61);
        }
        // light / wire hole in the back
        translate([0, 0, -cup_depth - 1]) cylinder(d = 10, h = 4);
    }
}

// Backing disc: glue the paper face on it, slide it in, it rests on three ribs.
module face_disc() {
    difference() {
        cylinder(d = cup_d - 3.6, h = 2);
        translate([0, 0, -1]) cylinder(d = 3, h = 4);
    }
}
module spacer_ring() {   // holds the face at face_depth
    difference() {
        cylinder(d = cup_d - 3.6, h = face_depth - bezel_t - 1);
        translate([0, 0, -1]) cylinder(d = cup_d - 9, h = 20);
    }
}

module panel_cutout() {
    circle(d = hole_d);
    for (x = [-screw, screw], y = [-screw, screw]) translate([x, y]) circle(d = m3_pilot_d);
}

module face_dummy(kind) {   // flat coloured stand-in for renders
    translate([0, 0, -face_depth]) {
        color([0.06, 0.06, 0.06]) cylinder(d = 76, h = 0.2);
        if (kind == "attitude") {
            color([0.25, 0.5, 0.9]) translate([0, 0, 0.2]) intersection() { cylinder(d = 70, h = 0.1); translate([-40, 0, 0]) cube([80, 40, 1]); }
            color([0.5, 0.32, 0.15]) translate([0, 0, 0.2]) intersection() { cylinder(d = 70, h = 0.1); translate([-40, -40, 0]) cube([80, 40, 1]); }
            color("white") translate([-30, -0.4, 0.31]) cube([60, 0.8, 0.1]);
            color([1, 0.6, 0]) translate([-14, -1, 0.42]) cube([28, 2, 0.1]);
        } else {
            color("white") for (a = [0 : 30 : 359]) rotate([0, 0, a]) translate([30, -0.5, 0.2]) cube([5, 1, 0.1]);
            if (kind == "airspeed") {
                color([0.1, 0.7, 0.2]) translate([0, 0, 0.25]) rotate_extrude(angle = 140) translate([31, 0]) square([2.5, 0.1]);
                color([1, 0.85, 0]) translate([0, 0, 0.25]) rotate([0, 0, 140]) rotate_extrude(angle = 40) translate([31, 0]) square([2.5, 0.1]);
            }
            color("white") translate([-0.8, 0, 0.35]) cube([1.6, 26, 0.2]);
        }
    }
}

module gauge_cutout_2d() panel_cutout();
function gauge_bezel_t() = bezel_t;

module instrument_mounted(kind = "airspeed") {
    color([0.08, 0.08, 0.08]) case();
    face_dummy(kind);
}

if (part == "assembly") instrument_mounted(face);
else if (part == "case") rotate([180, 0, 0]) case();
else if (part == "face_disc") { face_disc(); translate([85, 0, 0]) spacer_ring(); }
else if (part == "panel_cutout") panel_cutout();
