// Cessna 172S G1000 DASHBOARD for the home sim - shortened to about 32" (810 mm).
//
// Everything from the left switch panel to just past the MFD, at real scale:
//   upper (grey):  C-post switch panel, PFD, GMA 1347 audio panel, MFD,
//                  dimming/lights panel, yoke shaft opening (Moza AY210),
//                  standby airspeed / attitude / altimeter
//   lower (black): ignition key, circuit breakers (look only), parking brake,
//                  ALT STATIC AIR, throttle, mixture, flap lever, cabin heat/air
//   pedestal:      elevator trim wheel, fuel shutoff, floor with fuel selector
//   glareshield over the top
//
// The panel is printed as tiles that butt together (grey upper tiles, black
// lower tiles). The modules (bezels, switch plates, instruments) overlap the
// seams and tie the tiles together; splice strips on the back do the rest.
// Print tiles FRONT FACE DOWN.
//
// Layout numbers below: x = mm to the pilot's RIGHT of the pilot's centre line
// (the PFD and yoke), y = mm up from the bottom edge of the panel.
//
// Render:  openscad -D 'part="tile_U1"' -o tile_U1.stl g1000_dashboard.scad

include <../common/sim_common.scad>
use <../parts/parking-brake/parking_brake.scad>
use <../parts/throttle/throttle.scad>
use <../parts/mixture/mixture.scad>
use <../parts/trim-wheel/trim_wheel.scad>
use <../parts/fuel-selector/fuel_selector.scad>
use <../parts/g1000-gdu/gdu1040.scad>
use <../parts/g1000-gma/gma1347.scad>
use <../parts/switch-panel/switch_panel.scad>
use <../parts/standby-gauges/standby_gauges.scad>
use <../parts/panel-extras/panel_extras.scad>
use <../parts/flap-lever/flap_lever.scad>

/* [What to show] */
part = "preview"; // [preview, preview_rear, layout_map, tile_L1, tile_L2, tile_L3, tile_L4, tile_M1, tile_M2, tile_M3, tile_M4, tile_U1, tile_U2, tile_U3, tile_U4, splice, splice_small, glareshield_1, glareshield_2, glareshield_3, glareshield_4, pedestal_face, pedestal_floor, panel_2d, cnc_lower_1, cnc_lower_2, cnc_upper_1, cnc_upper_2, cnc_pedestal_face, cnc_pedestal_floor, cnc_splice, cnc_splice_small, keepout_2d, outline_2d, seam_info]

/* [Panel size] */
x_left = -280;
x_right = 530;
// Panel top edge is an arch: highest at the aircraft centre line (between PFD and MFD)
top_centre = 440;
top_side_drop = 20;
// Height of the black lower panel
lower_h = 112;
// Height where the grey upper panel is split into two rows of tiles
mid_split = 260;

/* [Upper panel] */
pfd_pos = [0, 308];
gma_pos = [175, 308];
mfd_pos = [350, 308];
cpost_pos = [-219, 337];
lights_pos = [-165, 161];
gauge_asi = [160, 160];
gauge_att = [248, 160];
gauge_alt = [336, 160];

/* [Yoke (Moza AY210)] */
yoke_pos = [0, 160];
// Distance from the panel back to the front of the AY210 base (keep things behind the panel shallower than this)
moza_front = 110;
// Height of the yoke shaft above the bottom of the AY210 base (measure yours)
moza_shaft_h = 150;

/* [Lower panel] */
ignition_pos = [-245, 55];
cb1_pos = [-175, 75];
cb2_pos = [-35, 75];
brake_pos = [-117, 25];
alt_static_pos = [98, 50];
throttle_pos = [197, 38];
mixture_pos = [266, 38];
flap_pos = [380, 60];
cabin_heat_pos = [433, 78];
cabin_air_pos = [433, 34];

/* [Pedestal] */
pedestal_x = 231;
pedestal_w = 130;
pedestal_h = 170;
floor_d = 150;

/* [Printing] */
// Print bed size (mm). 305 = QIDI Plus4. Each row is split into tiles no wider than this.
bed = 305;
// Tile seams (x positions) for each row: lower (black), middle and upper (grey).
// Splice plates on the back join the tiles: run scripts/place_splices.py after
// changing the seams or moving things, and it finds room for them (panel/splices.scad).
lower_splits = [15, 310];
mid_splits = [-58, 240];
upper_splits = [-10, 250];
// Glareshield joints (x). Offset from the upper seams so each glareshield piece screws
// into the tiles on both sides of a seam and ties the top edge together. [] = halfway along each upper tile.
glareshield_splits = [];

/* [CNC router] */
// Cutting the panel from 1/4" sheet on a CNC router instead of printing it:
// the lower (black) and upper (grey) panels are each cut in 2 pieces. Lower split at this x:
cnc_lower_split = 15;
// Upper split: [x below the jog, x above it, jog height y]. The default is a straight seam
// through the attitude gauge and the MFD: both bezels screw to both pieces and tie them.
cnc_upper_split = [248, 248, 207];
// Holes narrower than this are drilled instead of routed (mm)
cnc_drill_max = 6;
// Which layer to write for a cnc_* part: "cut" (outline + openings, routed through),
// "drill" (small through holes), "engrave" (labels, 0.6 mm deep), "countersink"
// (M3 head circles, front), "back" (blind pilot holes, mirrored for drilling from the back).
// scripts/make_cnc.py writes them all into one layered DXF / SVG per piece.
cnc_layer = "cut"; // [cut, drill, engrave, countersink, back]

/* [Hidden] */
t = panel_thickness;
// Splice plates, written by scripts/place_splices.py: [x, y, kind] for the printed tiles
// (splices) and the CNC pieces (cnc_splices). kind: "V" 34 x 70 across a vertical seam,
// "H" 70 x 34 across a horizontal joint, "v" / "h" small 2-screw plates for tight spots.
include <splices.scad>
function splice_size(k) = k == "V" ? [34, 70] : k == "H" ? [70, 34] : k == "v" ? [40, 22] : [22, 40];
function splice_holes(k) = k == "V" ? [[-10, -25], [10, -25], [-10, 25], [10, 25]]
                         : k == "H" ? [[-25, -10], [-25, 10], [25, -10], [25, 10]]
                         : k == "v" ? [[-12, 0], [12, 0]] : [[0, -12], [0, 12]];
module splice_pilots_2d(list) for (c = list, h = splice_holes(c[2])) translate([c[0], c[1]] + h) circle(d = m3_pilot_d);
splice_t = 4;   // printed splice thickness: M3 x 8 screws (4 mm into the panel's blind holes)
aircraft_cl = gma_pos[0];
function top_y(x) = top_centre - top_side_drop * pow((x - aircraft_cl) / (aircraft_cl - x_left), 2);
function ax(p) = [-p[0], p[1]];                 // layout -> model x (pilot's right = -x)
frame_hole_d = 4.5;

// ------------------------------------------------------------------ panel outline (front view)
module outline_2d() {
    n = 40;
    pts = concat([[x_left, 0], [x_right, 0]],
                 [for (i = [0 : n]) let(x = x_right - (x_right - x_left) * i / n) [x, top_y(x)]]);
    offset(r = 6) offset(delta = -6) polygon(pts);
}

// All cut-outs, front view
module holes_2d() {
    module at(p) translate(p) children();
    at(pfd_pos) gdu_cutout_2d();
    at(mfd_pos) gdu_cutout_2d();
    at(gma_pos) gma_cutout_2d();
    at(cpost_pos) upper_cutout();
    at(lights_pos) lower_cutout();
    for (g = [gauge_asi, gauge_att, gauge_alt]) at(g) gauge_cutout_2d();
    at(yoke_pos) { circle(d = 60); yoke_boot_screw_holes_2d(); }
    at(ignition_pos) circle(d = 10);
    for (p = [alt_static_pos, cabin_heat_pos, cabin_air_pos]) at(p) circle(d = 8.5);
    at(brake_pos) parking_brake_panel_cutout();
    at(throttle_pos) throttle_panel_cutout();
    at(mixture_pos) mixture_panel_cutout();
    at(flap_pos) flap_cutout_2d();
    // frame screws along the bottom and the sides
    for (x = concat([x_left + 10], [for (s = lower_splits) s - 15], [x_right - 10])) translate([x, 8]) circle(d = frame_hole_d);
    for (x = [x_left + 10, x_right - 10]) translate([x, mid_split - 20]) circle(d = frame_hole_d);
}

// Engraving on the panel face, front view (THROTTLE, MIXTURE, FLAP scale, key positions ...)
module engrave_2d() {
    f = "Liberation Sans:style=Bold";
    module lab(p, txt, dy = -27, s = 3.2) translate(p + [0, dy]) text(txt, size = s, font = f, halign = "center", valign = "center");
    lab(throttle_pos, "THROTTLE", -30);
    lab(mixture_pos, "MIXTURE", -30);
    lab(alt_static_pos, "ALT STATIC AIR", -16, 2.6);
    lab(cabin_heat_pos, "CABIN HT", 17, 2.6);
    lab(cabin_air_pos, "CABIN AIR", -17, 2.6);
    lab(brake_pos, "PARK BRAKE", -18, 2.6);
    translate(flap_pos) flap_scale_2d_();
    translate(ignition_pos) ignition_labels_2d();
}

// Back-side blind pilot holes (front view): G1000 screen cradles + splice strips
module back_pilots_2d() {
    for (p = [pfd_pos, mfd_pos]) translate(p) gdu_cradle_holes_2d();
    splice_pilots_2d(splices);
    for (i = [0 : len(GS_edges) - 2], x = gs_screws(i)) translate([x, top_y(x) - 18]) circle(d = m3_pilot_d);
}
// Countersinks (front view positions + kind)
cs_list = concat([for (p = [brake_pos, throttle_pos, mixture_pos]) [p, "std"]], [[flap_pos, "flap"]]);

// Whole panel (or one tile of it) in model coords: front face at z = -t, back at z = 0.
// Built from 2D layers (fast): engraved front skin, plain middle, back skin with blind holes.
// band = [y0, y1], xr = [x0, x1] limit it to a region (front-view coords).
module panel_body(band = [-1, 9999], xr = [-9999, 9999]) {
    module region() intersection() {
        outline_2d();
        translate([max(xr[0], x_left - 1), band[0]]) square([min(xr[1], x_right + 1) - max(xr[0], x_left - 1), band[1] - band[0]]);
    }
    e = 0.6;   // engraving depth
    difference() {
        mirror([1, 0, 0]) union() {
            translate([0, 0, -t]) linear_extrude(e + 0.01) difference() { region(); holes_2d(); engrave_2d(); }
            translate([0, 0, -t + e]) linear_extrude(2 - e + 0.01) difference() { region(); holes_2d(); }
            translate([0, 0, -t + 2]) linear_extrude(t - 2) difference() { region(); holes_2d(); back_pilots_2d(); }
        }
        // countersinks, only the ones inside this region
        for (c = cs_list) if (c[0][0] > xr[0] - 30 && c[0][0] < xr[1] + 30 && c[0][1] > band[0] - 60 && c[0][1] < band[1] + 60)
            translate([ax(c[0])[0], ax(c[0])[1], -t]) { if (c[1] == "std") mount_panel_countersinks(); else mirror([1, 0, 0]) flap_countersinks(); }
    }
}

// ------------------------------------------------------------------ tiles
L_edges = concat([x_left], lower_splits, [x_right]);
M_edges = concat([x_left], mid_splits, [x_right]);
U_edges = concat([x_left], upper_splits, [x_right]);
GS_edges = concat([x_left], len(glareshield_splits) > 0 ? glareshield_splits
                  : [for (i = [0 : len(U_edges) - 2]) (U_edges[i] + U_edges[i + 1]) / 2], [x_right]);
// glareshield tab screws: near each end, and either side of every upper seam it crosses
function gs_screws(i) = let(x0 = GS_edges[i], x1 = GS_edges[i + 1])
    concat([x0 + 20, x1 - 20], [for (u = upper_splits) if (u > x0 + 40 && u < x1 - 40) for (d = [-18, 18]) u + d]);
module tile(row, i) {
    e = row == "L" ? L_edges : row == "M" ? M_edges : U_edges;
    y0 = row == "L" ? 0 : row == "M" ? lower_h : mid_split;
    y1 = row == "L" ? lower_h : row == "M" ? mid_split : top_centre + 10;
    if (i >= 0 && i < len(e) - 1) translate([0, 0, t]) panel_body([y0, y1], [e[i], e[i + 1]]);
}
module splice(k = "V") {
    difference() {
        linear_extrude(splice_t) rounded_rect(splice_size(k), 3);
        for (h = splice_holes(k)) translate([h[0], h[1], -1]) cylinder(d = m3_clear_d, h = splice_t + 2);
    }
}

// ------------------------------------------------------------------ glareshield
// Padded-look shroud along the top edge. Each segment has a tab that screws
// to the back of the panel. Print upside down with supports (or cover a foam
// shape with vinyl like the real one).
gs_depth = 140;     // how far it reaches back over the screens
gs_lip = 32;        // overhang toward the pilot
module gs_slice(x) {
    y = top_y(x);
    translate([-x, y, 0]) rotate([0, 90, 0]) linear_extrude(0.5, center = true) hull() {
        translate([t + gs_lip - 14, 10]) circle(d = 22);          // rolled front edge (x here = -z)
        translate([-gs_depth, 26]) square([2, 2]);                // top surface toward the windscreen
        translate([-gs_depth, -2]) square([2, 2]);
        translate([0, -2]) square([2, 2]);
    }
}
module glareshield_segment(i) {
    e = GS_edges;
    x0 = e[i]; x1 = e[i + 1];
    n = max(2, ceil((x1 - x0) / 15));
    difference() {
        union() {
            for (k = [0 : n - 1]) hull() { gs_slice(x0 + (x1 - x0) * k / n); gs_slice(x0 + (x1 - x0) * (k + 1) / n); }
            // tab behind the panel
            for (k = [0 : n - 1]) hull() for (xx = [x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n])
                translate([-xx - 0.25, top_y(xx) - 30, 0]) cube([0.5, 30, 3]);
        }
        // hollow it out (3 mm walls)
        for (k = [0 : n - 1]) hull() for (xx = [x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n])
            translate([-xx, top_y(xx), 0]) rotate([0, 90, 0]) linear_extrude(0.6, center = true) offset(-3) hull() {
                translate([t + gs_lip - 14, 10]) circle(d = 22);
                translate([-gs_depth, 26]) square([2, 2]);
                translate([-gs_depth, -2]) square([2, 2]);
                translate([0, -2]) square([2, 2]);
            }
        // the panel itself passes under the front
        translate([-x1 - 1, 0, -t]) cube([x1 - x0 + 2, top_centre + 5, t]);
        for (xx = gs_screws(i)) translate([-xx, top_y(xx) - 18, -1]) cylinder(d = m3_clear_d, h = 6);
    }
}

// Print orientation: standing as it sits on the panel (top up), lowest point on the bed.
module gs_print(i) if (i < len(GS_edges) - 1) {
    e = GS_edges;
    ymin = min(top_y(e[i]), top_y(e[i + 1]), top_y(min(max(aircraft_cl, e[i]), e[i + 1]))) - 30;
    translate([0, 0, -ymin]) rotate([90, 0, 0]) glareshield_segment(i);
}

// ------------------------------------------------------------------ pedestal (below the panel)
module pedestal_face() {
    difference() {
        translate([-pedestal_w / 2, -pedestal_h, -t]) cube([pedestal_w, pedestal_h, t]);
        translate([0, -pedestal_h / 2, -t - 1]) linear_extrude(t + 2) mirror([1, 0]) trim_wheel_panel_cutout();
        translate([0, -pedestal_h / 2, -t]) trim_wheel_panel_countersinks();
        translate([0, -pedestal_h + 22, -t - 1]) cylinder(d = 8.5, h = t + 2);     // fuel shutoff
        translate([0, -pedestal_h + 10, -t - 0.01]) linear_extrude(0.61) mirror([1, 0])
            text("FUEL SHUTOFF", size = 3, font = "Liberation Sans:style=Bold", halign = "center", valign = "center");
    }
}
module pedestal_floor() {   // fuel-selector coordinates (cabin side = -z, +y forward)
    difference() {
        translate([-pedestal_w / 2 - 10, -floor_d / 2 - 10, -t]) cube([pedestal_w + 20, floor_d, t]);
        translate([0, 0, -t - 1]) linear_extrude(t + 2) fuel_selector_panel_cutout();
        translate([0, 0, -t]) fuel_selector_panel_countersinks();
    }
}

// ------------------------------------------------------------------ preview
module mod_front(p, face_thickness) {      // face-up module onto the panel face
    translate([ax(p)[0], ax(p)[1], -t - face_thickness]) rotate([0, 180, 0]) children();
}
module moza_dummy() {
    color([0.2, 0.2, 0.22], 0.5) translate([ax(yoke_pos)[0] - 243 / 2, yoke_pos[1] - moza_shaft_h, moza_front]) cube([243, 216, 403]);
    color("silver") translate([ax(yoke_pos)[0], yoke_pos[1], -120]) cylinder(d = 40, h = moza_front + 120);
}

module cockpit(rear = false) {
    // panel tiles, grey upper / black lower
    color([0.36, 0.37, 0.39]) panel_body([lower_h, 9999]);
    color([0.11, 0.11, 0.12]) panel_body([-1, lower_h]);
    // the yoke shaft coming through
    color([0.55, 0.56, 0.58]) translate([ax(yoke_pos)[0], yoke_pos[1], -160]) cylinder(d = 40, h = 160 + moza_front);
    color([0.93, 0.93, 0.9]) translate([0, 0, -t - 0.2]) linear_extrude(0.2) mirror([1, 0]) engrave_2d();
    // glareshield
    color([0.13, 0.13, 0.14]) for (i = [0 : len(GS_edges) - 2]) glareshield_segment(i);
    // splice plates on the back
    color([0.2, 0.55, 0.85]) for (c = splices) translate([ax(c)[0], c[1], 0])
        linear_extrude(splice_t) difference() {
            square(splice_size(c[2]), center = true);
            for (h = splice_holes(c[2])) translate([-h[0], h[1]]) circle(d = m3_clear_d);
        }
    // G1000
    mod_front(pfd_pos, gdu_face_t()) gdu_mounted(true);
    mod_front(mfd_pos, gdu_face_t()) gdu_mounted(true);
    mod_front(gma_pos, gma_face_t()) gma_mounted();
    // switch panels
    mod_front(cpost_pos, switch_plate_t()) upper_mounted();
    mod_front(lights_pos, switch_plate_t()) lower_mounted();
    // standby instruments
    mod_front(gauge_asi, gauge_bezel_t()) instrument_mounted("airspeed");
    mod_front(gauge_att, gauge_bezel_t()) instrument_mounted("attitude");
    mod_front(gauge_alt, gauge_bezel_t()) instrument_mounted("altimeter");
    // yoke boot, key, look-only knobs, breakers
    mod_front(yoke_pos, 0) color([0.08, 0.08, 0.08]) yoke_boot();
    mod_front(ignition_pos, 0) ignition_mounted();
    mod_front(alt_static_pos, 0) knob_mounted("alt");
    mod_front(cabin_heat_pos, 0) knob_mounted("heat");
    mod_front(cabin_air_pos, 0) knob_mounted("air");
    for (p = [cb1_pos, cb2_pos]) mod_front(p, 0) color([0.16, 0.16, 0.17]) cb_strip();
    // controls from parts/
    translate(ax(brake_pos)) parking_brake_mounted(false);
    translate(ax(throttle_pos)) throttle_mounted(0.1);
    translate(ax(mixture_pos)) mixture_mounted(0);
    translate(ax(flap_pos)) flap_mounted(0);
    // pedestal
    translate([-pedestal_x, 0, 0]) {
        color([0.11, 0.11, 0.12]) pedestal_face();
        translate([0, -pedestal_h / 2, 0]) trim_wheel_mounted();
        translate([0, -pedestal_h + 22, 0]) mod_front([0, 0], 0) knob_mounted("fuel");
        translate([0, -pedestal_h, -floor_d / 2 - t]) rotate([90, 0, 0]) {
            color([0.11, 0.11, 0.12]) pedestal_floor();
            fuel_selector_mounted();
        }
    }
    if (rear) moza_dummy();
}

// ------------------------------------------------------------------ layout map
module layout_map() {
    f = "Liberation Sans:style=Bold";
    color([0.36, 0.37, 0.39]) linear_extrude(1) difference() { outline_2d(); holes_2d(); }
    color([0.11, 0.11, 0.12]) translate([0, 0, 0.5]) linear_extrude(1) intersection() { difference() { outline_2d(); holes_2d(); } translate([x_left, 0]) square([x_right - x_left, lower_h]); }
    color("orange") translate([0, 0, 2]) linear_extrude(0.5) {
        for (s = lower_splits) translate([s - 0.6, 0]) square([1.2, lower_h]);
        for (s = mid_splits) translate([s - 0.6, lower_h]) square([1.2, mid_split - lower_h]);
        for (s = upper_splits) translate([s - 0.6, mid_split]) square([1.2, top_centre - mid_split]);
        for (c = splices) translate([c[0], c[1]]) difference() { square(splice_size(c[2]), center = true); square(splice_size(c[2]) - [2.4, 2.4], center = true); }
        translate([x_left, lower_h - 0.6]) square([x_right - x_left, 1.2]);
        translate([x_left, mid_split - 0.6]) square([x_right - x_left, 1.2]);
    }
    module tag(p, s) translate(p) text(s, size = 6, font = f, halign = "center", valign = "center");
    color("white") translate([0, 0, 2.5]) linear_extrude(0.5) {
        tag(pfd_pos, "PFD"); tag(mfd_pos, "MFD"); tag(gma_pos + [0, 105], "GMA");
        tag(cpost_pos, "C-POST"); tag(lights_pos + [0, -52], "DIMMING / LIGHTS");
        tag(yoke_pos, "YOKE"); tag(throttle_pos + [0, 30], "THR"); tag(mixture_pos + [0, 30], "MIX");
        tag(flap_pos + [0, 60], "FLAP"); tag(brake_pos + [0, 30], "PARK BRK");
    }
}

// ------------------------------------------------------------------ CNC (2D, front view, each piece at 0,0)
us = cnc_upper_split;
cnc_top = top_centre + 10;
// [name, piece outline polygon (cut with the panel outline), origin corner]
cnc_pieces = [
    ["lower_1", [[x_left - 1, -1], [cnc_lower_split, -1], [cnc_lower_split, lower_h], [x_left - 1, lower_h]], [x_left, 0]],
    ["lower_2", [[cnc_lower_split, -1], [x_right + 1, -1], [x_right + 1, lower_h], [cnc_lower_split, lower_h]], [cnc_lower_split, 0]],
    ["upper_1", [[x_left - 1, lower_h], [us[0], lower_h], [us[0], us[2]], [us[1], us[2]], [us[1], cnc_top], [x_left - 1, cnc_top]], [x_left, lower_h]],
    ["upper_2", [[us[0], lower_h], [x_right + 1, lower_h], [x_right + 1, cnc_top], [us[1], cnc_top], [us[1], us[2]], [us[0], us[2]]], [min(us[0], us[1]), lower_h]]];
module countersinks_2d() for (c = cs_list) translate(c[0]) {
    if (c[1] == "std") projection() mount_panel_countersinks();
    else projection() flap_countersinks();
}
module cnc_back_2d() {
    for (p = [pfd_pos, mfd_pos]) translate(p) gdu_cradle_holes_2d();
    splice_pilots_2d(cnc_splices);
    for (i = [0 : len(GS_edges) - 2], x = gs_screws(i)) translate([x, top_y(x) - 18]) circle(d = m3_pilot_d);
}
// split holes into routed openings and small drilled holes
module routed(r = cnc_drill_max / 2) offset(delta = r) offset(delta = -r) children();
module drilled() difference() { children(); offset(delta = 0.05) routed() children(); }
module cnc_piece(name, layer) {
    pc = [for (q = cnc_pieces) if (q[0] == name) q][0];
    o = pc[2];
    module region() intersection() { outline_2d(); polygon(pc[1]); }
    if (layer == "back") mirror([1, 0]) translate([-o[0], -o[1]]) intersection() { region(); cnc_back_2d(); }
    else translate([-o[0], -o[1]]) {
        if (layer == "cut") difference() { region(); routed() holes_2d(); }
        else if (layer == "drill") intersection() { region(); drilled() holes_2d(); }
        else if (layer == "engrave") intersection() { region(); engrave_2d(); }
        else if (layer == "countersink") intersection() { region(); countersinks_2d(); }
    }
}
module pedestal_face_holes() { translate([0, -pedestal_h / 2]) trim_wheel_panel_cutout(); translate([0, -pedestal_h + 22]) circle(d = 8.5); }
// pedestal face (front view) and floor (seen from above), each at 0,0
module cnc_pedestal_face(layer) translate([pedestal_w / 2, pedestal_h]) {
    if (layer == "cut") difference() { translate([-pedestal_w / 2, -pedestal_h]) square([pedestal_w, pedestal_h]); routed() pedestal_face_holes(); }
    else if (layer == "drill") drilled() pedestal_face_holes();
    else if (layer == "engrave") translate([0, -pedestal_h + 10])
        text("FUEL SHUTOFF", size = 3, font = "Liberation Sans:style=Bold", halign = "center", valign = "center");
    else if (layer == "countersink") translate([0, -pedestal_h / 2]) mirror([1, 0]) projection() trim_wheel_panel_countersinks();
}
// splice plate for the lower seam (same 1/4" sheet), glued and screwed across the back
module cnc_splice(layer, k = "V") translate(splice_size(k) / 2) {
    if (layer == "cut") square(splice_size(k), center = true);
    else if (layer == "drill") for (h = splice_holes(k)) translate(h) circle(d = m3_clear_d);
}
module cnc_pedestal_floor(layer) translate([pedestal_w / 2 + 10, floor_d / 2 + 10]) mirror([1, 0]) {
    if (layer == "cut") difference() { translate([-pedestal_w / 2 - 10, -floor_d / 2 - 10]) square([pedestal_w + 20, floor_d]); routed() fuel_selector_panel_cutout(); }
    else if (layer == "drill") drilled() fuel_selector_panel_cutout();
    else if (layer == "countersink") projection() fuel_selector_panel_countersinks();
}
for (pc = cnc_pieces) let(xs = [for (p = pc[1]) min(max(p[0], x_left), x_right)], ys = [for (p = pc[1]) min(max(p[1], 0), top_centre)])
    if (max(xs) - min(xs) > 790 || max(ys) - min(ys) > 390)
        echo(str("WARNING: CNC piece ", pc[0], " is bigger than an 800 x 400 router bed."));

// ------------------------------------------------------------------ keep-out (front view)
// Everything on the back of the panel a splice plate must stay clear of (scripts/place_splices.py)
module keepout_2d() {
    offset(r = 3) holes_2d();
    for (p = [pfd_pos, mfd_pos]) translate(p) square([310, 206], center = true);       // bezel screws, screen cradles
    translate(gma_pos) square([40, 202], center = true);
    for (p = [brake_pos, throttle_pos, mixture_pos]) translate(p) square(mount_flange_size + 6, center = true);
    translate(flap_pos + [0, 4]) square([50, 142], center = true);                       // flap housing + pot channels
    translate(ignition_pos) circle(d = 34);                                              // key switch
    for (p = [alt_static_pos, cabin_heat_pos, cabin_air_pos]) translate(p) circle(d = 26); // knob stems + clips
    // glareshield tabs along the top edge
    n = 40;
    polygon(concat([for (i = [0 : n]) let(x = x_left + (x_right - x_left) * i / n) [x, top_y(x) - 33]],
                   [[x_right + 5, top_centre + 20], [x_left - 5, top_centre + 20]]));
}

// ------------------------------------------------------------------ checks
deep_items = [["parking brake", brake_pos, 75], ["dimming/lights panel", lights_pos, 30], ["PFD", pfd_pos, 30]];
for (it = deep_items) {
    p = it[1];
    if (abs(p[0] - yoke_pos[0]) < 121.5 + 30 && p[1] > yoke_pos[1] - moza_shaft_h - 10 && it[2] > moza_front)
        echo(str("WARNING: the ", it[0], " sticks out ", it[2], " mm behind the panel - more than moza_front (", moza_front, " mm). Move the AY210 back."));
}
for (row = [["lower", L_edges], ["middle", M_edges], ["upper", U_edges]]) for (i = [0 : len(row[1]) - 2])
    if (row[1][i + 1] - row[1][i] > bed) echo(str("WARNING: ", row[0], " tile ", i + 1, " is ", row[1][i + 1] - row[1][i], " mm wide, more than your bed."));
for (i = [0 : len(GS_edges) - 2]) if (GS_edges[i + 1] - GS_edges[i] > bed)
    echo(str("WARNING: glareshield piece ", i + 1, " is ", GS_edges[i + 1] - GS_edges[i], " mm long, more than your bed - set glareshield_splits."));
if (top_centre - mid_split > bed) echo("WARNING: the top tile row is taller than your bed - raise mid_split.");

// ------------------------------------------------------------------ output
if (part == "preview") rotate([90, 0, 0]) cockpit();
else if (part == "preview_rear") rotate([90, 0, 0]) cockpit(true);
else if (part == "layout_map") layout_map();
else if (len(part) == 7 && part[0] == "t") tile(part[5], ord(part[6]) - ord("1"));
else if (part == "splice") splice("V");
else if (part == "splice_small") splice("v");
else if (part == "keepout_2d") keepout_2d();
else if (part == "outline_2d") outline_2d();
else if (part == "seam_info") echo(str("SEAMS=", [[x_left, x_right, lower_h, mid_split, top_centre], lower_splits, mid_splits, upper_splits,
    cnc_lower_split, cnc_upper_split]));
else if (part == "glareshield_1") gs_print(0);
else if (part == "glareshield_2") gs_print(1);
else if (part == "glareshield_3") gs_print(2);
else if (part == "glareshield_4") gs_print(3);
else if (part == "glareshield_5") gs_print(4);
else if (part == "pedestal_face") translate([0, 0, t]) pedestal_face();
else if (part == "pedestal_floor") translate([0, 0, t]) pedestal_floor();
else if (len(part) > 4 && part[0] == "c" && part[1] == "n" && part[2] == "c" && part != "cnc_pedestal_face" && part != "cnc_pedestal_floor" && part != "cnc_splice" && part != "cnc_splice_small")
    cnc_piece(str(part[4], part[5], part[6], part[7], part[8], part[9], part[10]), cnc_layer);
else if (part == "cnc_pedestal_face") cnc_pedestal_face(cnc_layer);
else if (part == "cnc_pedestal_floor") cnc_pedestal_floor(cnc_layer);
else if (part == "cnc_splice") cnc_splice(cnc_layer);
else if (part == "cnc_splice_small") cnc_splice(cnc_layer, "v");
else if (part == "panel_2d") difference() { outline_2d(); holes_2d(); }   // front view, for laser / CNC
