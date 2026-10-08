// Cessna 172S G1000 switch panels (left side of the instrument panel).
//
//   upper (C-post): STBY BATT (3-position toggle) + test light,
//                   MASTER  ALT | BAT  (two red rockers side by side),
//                   AVIONICS BUS 1 | BUS 2 (two grey rockers)
//   lower:          DIMMING  SW/CB PANELS, STBY IND, PEDESTAL, AVIONICS (4 knobs on pots)
//                   LIGHTS   BEACON LAND TAXI NAV STROBE (toggles)
//                            FUEL PUMP, PITOT HEAT, CABIN PWR 12V (toggles)
//
// Off-the-shelf switches snap or screw into printed plates; the plates screw
// over openings in the dashboard panel (4 x M3 countersunk each).
// Plates are modelled face-up (as seen from the seat), face at z = 0.

include <../../common/sim_common.scad>

/* [What to show] */
part = "assembly"; // [assembly, upper_plate, lower_plate, dimmer_knob, upper_cutout, lower_cutout]

/* [Switch sizes] */
// Rocker switch cut-out (KCD1-style mini rocker, mounted upright: width x height)
rocker_hole = [15, 21];
// Mini toggle switch bushing hole (MTS-102 etc: 6 mm thread)
toggle_hole_d = 6.4;
// Potentiometer bushing hole (16 mm pot, M7 bushing)
pot_hole_d = 7.4;
// LED hole (5 mm LED in a holder)
led_hole_d = 8;

/* [Hidden] */
plate_t = 3;
f = "Liberation Sans:style=Bold";
U = [117, 125];      // upper plate size
L = [170, 90];       // lower plate size
lip = 6;             // plate overlaps the panel opening by this much

// ---- upper plate layout (mm from the plate centre, front view)
stby_toggle = [-25, 36];
stby_led = [12, 36];
master = [[-38, -26], [-22, -26]];     // ALT, BAT
avionics = [[22, -26], [38, -26]];     // BUS 1, BUS 2

// ---- lower plate layout
dimmers = [[-66, 20], [-38, 20], [-66, -22], [-38, -22]];
dim_names = ["SW/CB PANELS", "STBY IND", "PEDESTAL", "AVIONICS"];
lights = [for (i = [0 : 4]) [-4 + i * 18, 18]];
light_names = ["BEACON", "LAND", "TAXI", "NAV", "STROBE"];
misc = [for (i = [0 : 2]) [-4 + i * 18, -22]];
misc_names = ["FUEL PUMP", "PITOT HEAT", "CABIN PWR"];

function corner_screws(sz) = [for (sx = [-1, 1], sy = [-1, 1]) [sx * (sz[0] / 2 - 5), sy * (sz[1] / 2 - 5)]];

module label(txt, size = 2.8) {
    translate([0, 0, -0.6]) linear_extrude(1) text(txt, size = size, font = f, halign = "center", valign = "center");
}
module box_outline(p0, p1, title) {   // engraved rectangle with a title gap, like the real panel
    translate([0, 0, -0.5]) linear_extrude(1) difference() {
        translate(p0) square(p1 - p0);
        translate(p0 + [0.7, 0.7]) square(p1 - p0 - [1.4, 1.4]);
        translate([(p0[0] + p1[0]) / 2 - len(title) * 1.25, p1[1] - 2]) square([len(title) * 2.5, 4]);
    }
    translate([(p0[0] + p1[0]) / 2, p1[1]]) label(title, 2.6);
}

module plate_blank(sz) {
    difference() {
        translate([0, 0, -plate_t]) linear_extrude(plate_t) rounded_rect(sz, 4);
        for (s = corner_screws(sz)) translate([s[0], s[1], -plate_t - 1]) {
            cylinder(d = m3_clear_d, h = plate_t + 2);
            translate([0, 0, plate_t + 1 - 1.6]) cylinder(d1 = m3_clear_d, d2 = m3_head_d + 0.4, h = 1.61);
        }
    }
}

module upper_labels() {
    translate([-1, 54]) label("C-POST", 3);
    box_outline([-46, 20], [30, 48], "STBY BATT");
    translate(stby_toggle + [0, 9]) label("ON", 2.4);
    translate(stby_toggle + [-12, 0]) label("OFF", 2.4);
    translate(stby_toggle + [0, -9]) label("TEST", 2.4);
    translate(stby_led + [0, -7.5]) label("TEST", 2.2);
    translate([-30, -2]) label("MASTER", 2.6);
    translate([-30, -6.5]) label("ALT  BAT", 2.4);
    translate([30, -2]) label("AVIONICS", 2.6);
    translate([30, -6.5]) label("BUS 1  BUS 2", 2.2);
    for (x = [-50, 10]) translate([x, -26]) label("ON", 2.2);
}

module upper_plate() {
    difference() {
        plate_blank(U);
        upper_labels();
        translate([stby_toggle[0], stby_toggle[1], -plate_t - 1]) cylinder(d = toggle_hole_d, h = plate_t + 2);
        translate([stby_led[0], stby_led[1], -plate_t - 1]) cylinder(d = led_hole_d, h = plate_t + 2);
        for (p = concat(master, avionics)) translate([p[0], p[1], -plate_t - 1])
            linear_extrude(plate_t + 2) square(rocker_hole, center = true);
        // thinner round the rockers so their clips grip (they're made for ~2 mm panels)
        for (p = concat(master, avionics)) translate([p[0], p[1], -plate_t - 0.01])
            linear_extrude(1) square(rocker_hole + [4, 4], center = true);
    }
}

module lower_labels() {
    for (i = [0 : 3]) translate(dimmers[i] + [0, 13]) label(dim_names[i], 2.1);
    box_outline([-80, -38], [-24, 39], "DIMMING");
    for (i = [0 : 4]) { translate(lights[i] + [0, 10]) label(light_names[i], 2.1); translate(lights[i] + [0, -9]) label("OFF", 2.0); }
    for (i = [0 : 2]) { translate(misc[i] + [0, 10]) label(misc_names[i], 1.9); translate(misc[i] + [0, -9]) label("OFF", 2.0); }
    box_outline([-16, 4], [80, 39], "LIGHTS");
}

module lower_plate() {
    difference() {
        plate_blank(L);
        lower_labels();
        for (i = [0 : 3]) translate([dimmers[i][0], dimmers[i][1], -plate_t - 1]) cylinder(d = pot_hole_d, h = plate_t + 2);
        for (p = concat(lights, misc)) translate([p[0], p[1], -plate_t - 1]) cylinder(d = toggle_hole_d, h = plate_t + 2);
    }
}

// Round knob with a white index line, for the 6 mm D-shaft pots. Printed face-down.
module dimmer_knob() {
    difference() {
        union() {
            ribbed_cylinder(7, 10, n = 24, depth = 0.5);
            translate([0, 0, 8]) cylinder(d = 17, h = 2);    // skirt against the panel
        }
        translate([0, 0, 2]) linear_extrude(12) difference() {
            circle(d = 6.15);
            translate([-5, 1.6]) square([10, 5]);
        }
        translate([-0.6, 1.5, -0.01]) cube([1.2, 5, 0.6]);  // index line (paint it white)
    }
}

// Panel openings (front view, relative to plate centre)
module upper_cutout() { square(U - 2 * [lip, lip], center = true); for (s = corner_screws(U)) translate(s) circle(d = m3_pilot_d); }
module lower_cutout() { square(L - 2 * [lip, lip], center = true); for (s = corner_screws(L)) translate(s) circle(d = m3_pilot_d); }
function upper_size() = U;
function switch_plate_t() = plate_t;
function lower_size() = L;

// ---- demo animation (README GIF): when each switch goes ON; everything goes OFF again at sp_off
sp_on_master = [0.10, 0.04];             // ALT, BAT
sp_on_stby = 0.17;
sp_on_avionics = [0.25, 0.30];
sp_on_lights = [0.38, 0.43, 0.48, 0.53, 0.58];
sp_on_misc = [0.63, 0.68, 2];            // FUEL PUMP, PITOT HEAT, (CABIN PWR stays off)
sp_dim_turn = [[0.70, 0.75], [0.75, 0.80], [0.80, 0.85], [0.85, 0.90]];
sp_off = 0.93;
function sw_on(t_on) = anim >= 0 && anim >= t_on && anim < sp_off;
function dim_angle(i) = anim < 0 ? 0 : -1200 * (min(max(anim < sp_off ? anim : 0, sp_dim_turn[i][0]), sp_dim_turn[i][1]) - sp_dim_turn[i][0]);

// rocker: top half pressed in = ON
module rocker(on, col) color(col) translate([0, 0, 2.2]) rotate([on ? -9 : 9, 0, 0]) translate([-7.3, -10.3, -1.8]) cube([14.6, 20.6, 4]);
// bat-handle toggle: down = OFF, up = ON
module toggle(on) {
    color("silver") { cylinder(d = 9, h = 2); rotate([on ? -14 : 14, 0, 0]) cylinder(d = 2.5, h = 11); }
}
module switch_dummies_upper() {
    for (i = [0 : 1]) translate(master[i]) rocker(sw_on(sp_on_master[i]), [0.75, 0.1, 0.1]);
    for (i = [0 : 1]) translate(avionics[i]) rocker(sw_on(sp_on_avionics[i]), [0.85, 0.85, 0.82]);
    translate(stby_toggle) toggle(sw_on(sp_on_stby));
    color([0.8, 0.1, 0.1]) translate(stby_toggle) rotate([sw_on(sp_on_stby) ? -14 : 14, 0, 0]) translate([0, 0, 10]) sphere(d = 4);
    color(sw_on(sp_on_stby) ? [0.3, 1, 0.4] : [0.2, 0.45, 0.25]) translate(stby_led) cylinder(d = 5, h = 3);
}
module switch_dummies_lower() {
    for (i = [0 : 3]) translate(dimmers[i]) {
        rotate(dim_angle(i)) {
            color([0.1, 0.1, 0.1]) translate([0, 0, 10]) mirror([0, 0, 1]) dimmer_knob();
            color("white") translate([-0.6, 1.5, 9.95]) cube([1.2, 5, 0.2]);   // painted index line
        }
        if (anim_in(sp_dim_turn[i][0], sp_dim_turn[i][1])) turn_arrow(8.5, 1, 10.5);
    }
    for (i = [0 : 4]) translate(lights[i]) toggle(sw_on(sp_on_lights[i]));
    for (i = [0 : 2]) translate(misc[i]) toggle(sw_on(sp_on_misc[i]));
}

module upper_mounted() { color([0.42, 0.44, 0.46]) upper_plate(); paint_fill() upper_labels(); switch_dummies_upper(); }
module lower_mounted() { color([0.42, 0.44, 0.46]) lower_plate(); paint_fill() lower_labels(); switch_dummies_lower(); }

if (part == "assembly") { translate([-80, 0]) upper_mounted(); translate([70, 0]) lower_mounted(); }
else if (part == "upper_plate") rotate([180, 0, 0]) upper_plate();
else if (part == "lower_plate") rotate([180, 0, 0]) lower_plate();
else if (part == "dimmer_knob") dimmer_knob();
else if (part == "upper_cutout") upper_cutout();
else if (part == "lower_cutout") lower_cutout();
