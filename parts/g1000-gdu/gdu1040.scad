// Garmin G1000 GDU 1040 bezel (PFD / MFD) for the C172S home sim - WORKING keys and knobs.
//
// Real size 300 x 196 mm (11.8 x 7.7 in) with the real layout:
//   12 softkeys, NAV/COM flip keys, 12 autopilot keys (GFC 700), 6 FMS keys,
//   NAV VOL, NAV (dual), HDG, ALT (dual), COM VOL, COM (dual), CRS/BARO (dual),
//   RANGE and FMS (dual) knobs.
// Build two of these: one PFD, one MFD (the real ones are identical).
//
// Inside (kept simple):
//   - printed front plate (two halves if your bed is under 300 mm)
//   - printed key caps that press 6x6 mm tactile switches
//   - a printed switch plate holding the switches, screwed to posts on the front plate
//   - EC11 encoders (single) and EC11 dual-shaft encoders, nut on the face, knob over it
//   - a 10.4" 4:3 1024x768 LCD (same size and resolution as the real GDU 1040)
//     held in two printed cradle halves screwed to the BACK of the panel, so the
//     bezel can come off without touching the screen
//
// Modelled face-up (as seen from the seat): x right, y up, face at z = 0.
// Render one part:  openscad -D 'part="front_left"' -o front_left.stl gdu1040.scad

include <../../common/sim_common.scad>
include <../../common/avionics_lib.scad>

/* [What to show] */
part = "assembly"; // [assembly, exploded, front, front_left, front_right, switch_plate_left, switch_plate_right, lcd_cradle_left, lcd_cradle_right, caps_sheet, knobs_sheet, panel_cutout]

/* [Options] */
// "PFD" or "MFD" - only changes the label used in renders
unit = "PFD"; // [PFD, MFD]
// Autopilot keys (GFC 700). The 172S in MSFS 2024 has them.
ap_keys = true;

/* [Screen] */
// Outline of your 10.4" LCD module (the active area is 211 x 158)
lcd_w = 243;
lcd_h = 184.5;
lcd_t = 7;
// How far the screen sits behind the switch plate (clears switch legs and solder)
lcd_gap = 4.6;

/* [Hidden] */
W = 300; H = 196;
win = [212, 157];
win_c = [0, 3.7];
split_x = 3.5;            // front plate seam (between softkeys 6 and 7)
sp_split_x = -40;         // switch plate seam (offset so it bridges the front seam)
sp_size = [277, 186];
sp_win = [216, 161];
opening = [[-139, -94], [139, 97]];   // panel cut-out, relative to the bezel centre
screw_pos = [[-144, 88], [144, 88], [-144, -88], [144, -88]];
cap_h = 7.5;

// ---- layout (front view, mm from the bezel centre) -------------------------
// keys: [x, y, w, h, label, flip-arrow]
softkeys = [for (i = [0 : 11]) [-88.9 + i * 16.8, -86, 12.5, cap_h, "", false]];
side_keys = concat(
    [[-122.2, 70.2, 10.5, cap_h, "", true],       // NAV flip
     [ 120.0, 70.2, 10.5, cap_h, "", true]],      // COM flip
    ap_keys ? [for (r = [0 : 5], c = [0 : 1])
        [c == 0 ? -131.5 : -118, -12 * r, 10.5, cap_h,
         ["AP", "FD", "HDG", "ALT", "NAV", "VNV", "APR", "BC", "VS", "UP", "FLC", "DN"][r * 2 + c], false]] : [],
    [for (r = [0 : 2], c = [0 : 1])
        [c == 0 ? 119 : 132, [-39, -51, -62][r], 10.5, cap_h,
         ["D>", "MENU", "FPL", "PROC", "CLR", "ENT"][r * 2 + c], false]]);
keys = concat(softkeys, side_keys);

// knobs: [x, y, type, label, label_dy]   type: "vol" | "single" | "dual"
knobs = [
    [-130.5,  83.5, "vol",    "VOL",       -7.5],
    [-130.5,  51.0, "dual",   "NAV",       11.5],
    [-130.5,  16.6, "single", "HDG",       12.0],
    [-130.5, -78.6, "dual",   "ALT",      -12.5],
    [ 128.8,  83.5, "vol",    "VOL",       -7.5],
    [ 128.8,  51.0, "dual",   "COM",       11.5],
    [ 128.8,  17.8, "dual",   "CRS/BARO",  11.5],
    [ 128.8, -15.4, "single", "RANGE",     11.0],
    [ 128.8, -77.8, "dual",   "FMS",      -12.5]];

// front-plate posts the switch plate screws to (placed in the gaps between keys and knobs)
posts = [[-60, 88], [-20, 88], [60, 88], [-105, -89], [105, -89],
         [-114, 34], [114, 34], [-114, -70], [114, -71]];
// panel-back screw holes for the LCD cradle
cradle_screws = [for (sx = [-1, 1], sy = [-1, 1]) [sx * 146, win_c[1] + sy * (lcd_h / 2 - 8)]];

// ------------------------------------------------------------------ front plate
module front_plate() {
    difference() {
        union() {
            translate([0, 0, -face_t]) linear_extrude(face_t) rounded_rect([W, H], 6);
            for (p = posts) translate(p) face_post();
        }
        translate([win_c[0], win_c[1], -face_t - 1]) linear_extrude(face_t + 2) rounded_rect(win, 2);
        // slight bevel round the screen window
        translate([win_c[0], win_c[1], -1.2]) linear_extrude(1.3, scale = [(win[0] + 3) / win[0], (win[1] + 3) / win[1]])
            rounded_rect(win, 2);
        for (k = keys) translate([k[0], k[1]]) key_hole(k[2], k[3]);
        for (k = knobs) translate([k[0], k[1]]) enc_hole(k[2] == "dual");
        for (s = screw_pos) translate([s[0], s[1], -face_t - 1]) {
            cylinder(d = m3_clear_d, h = face_t + 2);
            translate([0, 0, face_t + 1 - 1.6]) cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.4, h = 1.61);
        }
        face_labels();
    }
}
module face_labels() {
    translate([0, 90.5]) face_label("GARMIN", 4.2);
    for (k = knobs) translate([k[0], k[1] + k[4]]) face_label(k[3], k[3] == "CRS/BARO" ? 2.3 : 2.6);
}

module front_half(side) {   // side = -1 left, +1 right
    intersection() {
        front_plate();
        translate([side < 0 ? -W : split_x, -H, -50]) cube([side < 0 ? W + split_x : W, 2 * H, 100]);
    }
}

// ------------------------------------------------------------------ switch plate
module switch_plate() {
    difference() {
        translate([0, 0, -sw_z - sw_t]) linear_extrude(sw_t) difference() {
            translate([0, (opening[0][1] + opening[1][1]) / 2 - 1.5]) rounded_rect([sp_size[0], sp_size[1]], 4);
            translate(win_c) rounded_rect(sp_win, 3);
        }
        for (k = keys) translate([k[0], k[1]]) tact_pocket();
        for (k = knobs) translate([k[0], k[1]]) enc_clear();
        for (p = posts) translate([p[0], p[1], -sw_z - sw_t - 1]) cylinder(d = m3_clear_d, h = sw_t + 2);
        // wire exits between the key columns
        for (y = [30, -20, -70]) for (s = [-1, 1]) translate([s * 112, y, -sw_z - sw_t - 1]) cylinder(d = 4, h = sw_t + 2);
    }
}

module switch_half(side) {
    intersection() {
        switch_plate();
        translate([side < 0 ? -W : sp_split_x, -H, -50]) cube([side < 0 ? W + sp_split_x : W, 2 * H, 100]);
    }
}

// ------------------------------------------------------------------ LCD cradle
// Two C-shaped halves screwed to the back of the panel (outside the opening).
// They hold the LCD by its edges: a front lip sets its depth, a back lip holds it in.
z_panel_back = -face_t - panel_thickness;
z_lcd_front  = -sw_z - sw_t - lcd_gap;
z_lcd_back   = z_lcd_front - lcd_t;
module lcd_cradle(side) {
    yc = win_c[1];
    hh = lcd_h / 2;
    x_in = lcd_w / 2;                // LCD edge
    difference() {
        union() {
            // mounting flange on the panel back, outside the opening
            translate([side < 0 ? -152 : 140, yc - hh - 4, z_panel_back - 3]) cube([12, lcd_h + 8, 3]);
            // wall down to the LCD back
            translate([side < 0 ? -144 : 140, yc - hh - 4, z_lcd_back - 2]) cube([4, lcd_h + 8, z_panel_back - (z_lcd_back - 2)]);
            // side wall around the LCD edge
            translate([side < 0 ? -144 : x_in + 0.3, yc - hh - 4, z_lcd_back - 2]) cube([144 - x_in - 0.3, lcd_h + 8, lcd_t + 2 + 1.2]);
            // top/bottom stops (60 mm in from the corner)
            for (sy = [-1, 1]) translate([side < 0 ? -144 : x_in - 60, sy < 0 ? yc - hh - 4 : yc + hh + 0.3, z_lcd_back - 2])
                cube([144 - x_in + 60, 3.7, lcd_t + 2 + 1.2]);
        }
        // the LCD
        translate([-x_in - 0.3, yc - hh - 0.3, z_lcd_back]) cube([lcd_w + 0.6, lcd_h + 0.6, lcd_t + 0.01]);
        // open the front over the LCD except a 4 mm lip at its edge
        translate([-x_in + 4, yc - hh + 4, z_lcd_front - 0.01]) cube([lcd_w - 8, lcd_h - 8, 10]);
        // open the back except a 6 mm lip
        translate([-x_in + 6, yc - hh + 6, z_lcd_back - 3]) cube([lcd_w - 12, lcd_h - 12, 4]);
        // screws into the panel back
        for (c = cradle_screws) if (sign(c[0]) == side) translate([c[0], c[1], z_lcd_back - 5]) {
            cylinder(d = m3_clear_d, h = 50);
            cylinder(d = 6.5, h = (z_panel_back - 3) - (z_lcd_back - 5) - 0.01);   // screwdriver access
        }
        // cable exit for the LCD driver board (bottom)
        translate([-30, yc - hh - 5, z_lcd_back - 3]) cube([60, 6, 20]);
    }
}

// ------------------------------------------------------------------ caps + knobs
module cap_for(k) { key_cap(k[2], k[3], k[4], len(k[4]) > 3 ? 1.7 : 2.2, k[5]); }

module caps_sheet() {
    n = len(keys);
    cols = 8;
    for (i = [0 : n - 1]) translate([(i % cols) * 18, floor(i / cols) * 14, 0]) cap_for(keys[i]);
}

module knob_for(k) {
    if (k[2] == "vol") knob_single(10, 8, 18);
    else if (k[2] == "single") knob_single(16, 12, 24);
    else { knob_dual_outer(19, 7); }
}
module knobs_sheet() {
    for (i = [0 : len(knobs) - 1]) {
        k = knobs[i];
        translate([(i % 5) * 26, floor(i / 5) * 26, 0]) knob_for(k);
        if (k[2] == "dual") translate([(i % 5) * 26 + 130, floor(i / 5) * 26, 0]) knob_dual_inner(12, 13);
    }
}

// knobs in place (face-up assembly): front of the knob up, 2.5 mm nut under it
module knobs_placed() {
    for (k = knobs) translate([k[0], k[1], 2.5]) {
        if (k[2] == "dual") {
            color([0.1, 0.1, 0.1]) translate([0, 0, 7]) mirror([0, 0, 1]) knob_dual_outer(19, 7);
            color([0.16, 0.16, 0.16]) translate([0, 0, 7 + 9]) mirror([0, 0, 1]) knob_dual_inner(12, 13);
        } else if (k[2] == "vol") color([0.1, 0.1, 0.1]) translate([0, 0, 8]) mirror([0, 0, 1]) knob_single(10, 8, 18);
        else color([0.1, 0.1, 0.1]) translate([0, 0, 12]) mirror([0, 0, 1]) knob_single(16, 12, 24);
    }
}

// ------------------------------------------------------------------ panel cut-out (front view)
module panel_cutout() {
    translate(opening[0]) square(opening[1] - opening[0]);
    for (s = screw_pos) translate(s) circle(d = m3_clear_d);
}
// For the dashboard: blind pilot holes for the cradle screws, drilled from the panel back
module gdu_cradle_holes_2d() for (c = cradle_screws) translate(c) circle(d = m3_pilot_d);

// ------------------------------------------------------------------ views
module screen_dummy() {
    color([0.05, 0.07, 0.1]) translate([-lcd_w / 2, win_c[1] - lcd_h / 2, z_lcd_front - lcd_t]) cube([lcd_w, lcd_h, lcd_t]);
    // a hint of a PFD on the screen
    color([0.25, 0.5, 0.9]) translate([win_c[0] - win[0] / 2, win_c[1], z_lcd_front + 0.01]) cube([win[0], win[1] / 2, 0.1]);
    color([0.55, 0.35, 0.15]) translate([win_c[0] - win[0] / 2, win_c[1] - win[1] / 2, z_lcd_front + 0.01]) cube([win[0], win[1] / 2, 0.1]);
}

module assembly(show_screen = true) {
    color([0.17, 0.18, 0.19]) front_plate();
    paint_fill() face_labels();
    color([0.25, 0.25, 0.26]) for (k = keys) translate([k[0], k[1]]) cap_in_place() cap_for(k);
    color([0.93, 0.93, 0.9]) for (k = keys) translate([k[0], k[1], cap_out - 0.2]) scale([1, 1, 0.3])
        cap_label_geom(k[2], k[4], len(k[4]) > 3 ? 1.7 : 2.2, k[5]);
    knobs_placed();
    color("darkorange", ghost_a()) switch_plate();
    if (show_screen) { color("goldenrod", ghost_a()) { lcd_cradle(-1); lcd_cradle(1); } screen_dummy(); }
}

module exploded() {
    color([0.17, 0.18, 0.19]) front_plate();
    color([0.62, 0.62, 0.6]) for (k = keys) translate([k[0], k[1], 12]) cap_in_place() cap_for(k);
    translate([0, 0, 30]) knobs_placed();
    color("darkorange") translate([0, 0, -30]) switch_plate();
    color("goldenrod") translate([0, 0, -60]) { lcd_cradle(-1); lcd_cradle(1); }
    translate([0, 0, -60]) screen_dummy();
}

// For the dashboard file, which `use`s this one.
module gdu_mounted(screen = true) assembly(screen);
module gdu_cutout_2d() panel_cutout();
function gdu_face_t() = face_t;

// ------------------------------------------------------------------ output
if (part == "assembly") assembly();
else if (part == "exploded") exploded();
else if (part == "front") rotate([180, 0, 0]) front_plate();                  // face down
else if (part == "front_left") rotate([180, 0, 0]) front_half(-1);
else if (part == "front_right") rotate([180, 0, 0]) front_half(1);
else if (part == "switch_plate_left") translate([0, 0, sw_z + sw_t]) switch_half(-1);
else if (part == "switch_plate_right") translate([0, 0, sw_z + sw_t]) switch_half(1);
else if (part == "lcd_cradle_left") translate([0, 0, -z_lcd_back + 2]) lcd_cradle(-1);
else if (part == "lcd_cradle_right") translate([0, 0, -z_lcd_back + 2]) lcd_cradle(1);
else if (part == "caps_sheet") caps_sheet();
else if (part == "knobs_sheet") knobs_sheet();
else if (part == "panel_cutout") panel_cutout();

echo(str("GDU 1040: ", len(keys), " keys (6x6x5 mm tactile switches), ",
         len([for (k = knobs) if (k[2] == "dual") 1]), " dual-shaft EC11 + ",
         len([for (k = knobs) if (k[2] != "dual") 1]), " single EC11 encoders"));
echo(str("GDU 1040: panel opening ", opening[1][0] - opening[0][0], " x ", opening[1][1] - opening[0][1],
         " mm, 4x M3 countersunk screws at +/-144, +/-88"));
