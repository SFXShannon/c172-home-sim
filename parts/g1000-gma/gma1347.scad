// Garmin GMA 1347 audio panel (between the PFD and MFD) - WORKING keys.
//
// Real size 34.3 x 195.6 mm (1.35 x 7.7 in). 21 audio keys in two columns,
// a volume knob (EC11 with push) and the red DISPLAY BACKUP button.
// Same construction as the G1000 bezels: printed face, T-shaped key caps,
// 6x6 mm tactile switches on a printed switch plate.
//
// Modelled face-up (as seen from the seat): x right, y up, face at z = 0.

include <../../common/sim_common.scad>
include <../../common/avionics_lib.scad>

/* [What to show] */
part = "assembly"; // [assembly, front, switch_plate, caps_sheet, knob, panel_cutout]

/* [Hidden] */
W = 34.3; H = 195.6;
rows = [77, 65.5, 54, 42.5, 31, 19.5, 8, -3.5, -15, -26.5, -38];
names = ["MIC1", "COM1", "MIC2", "COM2", "MIC3", "COM3", "1/2", "TEL", "PA", "SPKR", "MKR",
         "HI S", "DME", "NAV1", "ADF", "NAV2", "AUX", "MAN", "PLAY", "PILOT", "COPLT", ""];
keys = concat(
    [for (r = [0 : len(rows) - 1], c = [0 : 1]) [c == 0 ? -7.5 : 7.5, rows[r], 11, 7, names[r * 2 + c], false]],
    [[0, -78, 16, 7, "", false]]);            // DISPLAY BACKUP (print this cap in red)
knob = [0, -58];
opening = [[-15, -90], [15, 90]];
screws = [[0, 94], [0, -94]];
posts = [[0, 86.5], [0, -86.5]];

module front_plate() {
    difference() {
        union() {
            translate([0, 0, -face_t]) linear_extrude(face_t) rounded_rect([W, H], 3);
            for (p = posts) translate(p) face_post();
        }
        for (k = keys) translate([k[0], k[1]]) key_hole(k[2], k[3]);
        translate(knob) enc_hole(false);
        for (s = screws) translate([s[0], s[1], -face_t - 1]) {
            cylinder(d = m3_clear_d, h = face_t + 2);
            translate([0, 0, face_t + 1 - 1.6]) cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.4, h = 1.61);
        }
        face_labels();
    }
}
module face_labels() {
    translate([0, -47]) face_label("VOL", 2.2);
    translate([0, -69]) face_label("BACKUP", 2);
}

module switch_plate() {
    difference() {
        translate([0, 0, -sw_z - sw_t]) linear_extrude(sw_t) rounded_rect([28, 178], 2);
        for (k = keys) translate([k[0], k[1]]) tact_pocket();
        translate(knob) enc_clear();
        for (p = posts) translate([p[0], p[1], -sw_z - sw_t - 1]) cylinder(d = m3_clear_d, h = sw_t + 2);
    }
}

module cap_for(k) { key_cap(k[2], k[3], k[4], len(k[4]) > 3 ? 1.6 : 2.0, k[5]); }
module caps_sheet() for (i = [0 : len(keys) - 1]) translate([(i % 6) * 18, floor(i / 6) * 13, 0]) cap_for(keys[i]);

module panel_cutout() {
    translate(opening[0]) square(opening[1] - opening[0]);
    for (s = screws) translate(s) circle(d = m3_clear_d);
}

module assembly() {
    color([0.17, 0.18, 0.19]) front_plate();
    for (i = [0 : len(keys) - 1]) color(i == len(keys) - 1 ? [0.8, 0.1, 0.1] : [0.25, 0.25, 0.26])
        translate([keys[i][0], keys[i][1]]) cap_in_place() cap_for(keys[i]);
    color([0.1, 0.1, 0.1]) translate([knob[0], knob[1], 2.5 + 10]) mirror([0, 0, 1]) knob_single(13, 10, 20);
    paint_fill() face_labels();
    color([0.93, 0.93, 0.9]) for (k = keys) translate([k[0], k[1], cap_out - 0.2]) scale([1, 1, 0.3])
        cap_label_geom(k[2], k[4], len(k[4]) > 3 ? 1.6 : 2.0, k[5]);
    color("darkorange", ghost_a()) switch_plate();
}

module gma_mounted() assembly();
module gma_cutout_2d() panel_cutout();
function gma_face_t() = face_t;

if (part == "assembly") assembly();
else if (part == "front") rotate([180, 0, 0]) front_plate();
else if (part == "switch_plate") translate([0, 0, sw_z + sw_t]) switch_plate();
else if (part == "caps_sheet") caps_sheet();
else if (part == "knob") knob_single(13, 10, 20);
else if (part == "panel_cutout") panel_cutout();

echo(str("GMA 1347: ", len(keys), " keys + 1 EC11 (with push); panel opening 30 x 180 mm, 2x M3 screws at 0, +/-94"));
