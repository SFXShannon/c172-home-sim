// C172 home-sim PANEL: printable panel pieces with all the control cutouts.
//
// Three pieces, laid out like the 172's lower panel and centre pedestal:
//   lower    - lower instrument panel strip: parking brake, throttle, (prop), mixture
//   pedestal - pedestal face below it: elevator trim wheel
//   floor    - pedestal floor plate: fuel selector
//
// The lower panel is wider than most print beds, so it is split into tiles that
// butt together and are joined by a splice strip glued/screwed on the back.
// Print tiles FRONT FACE DOWN for a smooth finish.
//
// Positions are approximate 172S proportions - move things in the layout
// section below to suit your cockpit (and your Moza AY210 yoke).
//
// Render:  openscad -D 'part="lower_tile_1"' -o lower_tile_1.stl c172_panel.scad

include <../common/sim_common.scad>
use <../parts/parking-brake/parking_brake.scad>
use <../parts/throttle/throttle.scad>
use <../parts/mixture/mixture.scad>
use <../parts/prop/prop.scad>
use <../parts/trim-wheel/trim_wheel.scad>
use <../parts/fuel-selector/fuel_selector.scad>

/* [What to show] */
part = "preview"; // [preview, preview_rear, lower_tile_1, lower_tile_2, lower_tile_3, splice, pedestal, floor, lower_2d, pedestal_2d, floor_2d]

/* [Layout - lower panel] (mm, x = to the pilot's right of panel centre, y = up from panel bottom) */
lower_w = 330;
lower_h = 120;
// Constant-speed prop (172RG / 182 style)? Adds the blue prop knob between throttle and mixture
has_prop = false;
brake_pos    = [-140, 45];
throttle_pos = [0, 70];
prop_pos     = [55, 70];
mixture_pos  = has_prop ? [110, 70] : [60, 70];
// Engrave THROTTLE / MIXTURE / ... under the controls
labels = true;
// Optional opening for a yoke shaft: [x, y, width, height] or [] for none
yoke_hole = [];

/* [Layout - pedestal] */
pedestal_x = 30;          // pedestal centre line (x, same axis as above)
pedestal_w = 130;
pedestal_h = 170;
floor_d    = 150;         // floor plate depth (toward the pilot)

/* [Printing] */
// Largest piece your printer can do (mm)
bed = 250;
// Where to split the lower panel into tiles (x positions)
lower_splits = [-75];

/* [Hidden] */
t = panel_thickness;
frame_hole_d = 4.5;       // #8 / M4 screws into your frame

function ax(p) = [-p[0], p[1]];   // layout (pilot-right = +x) -> model coords (pilot-right = -x)

// ------------------------------------------------------------------ lower panel

module lower_outline() { translate([-lower_w/2, 0]) square([lower_w, lower_h]); }

module frame_holes(w, h, y0 = 0) {
    for (x = [-w/2 + 8, 0, w/2 - 8], y = [y0 + 8, y0 + h - 8]) translate([x, y]) circle(d = frame_hole_d);
}

module lower_label(p, txt) {
    translate(ax(p) + [0, -30]) mirror([1, 0]) text(txt, size = 4, halign = "center", valign = "center",
                                                     font = "Liberation Sans:style=Bold");
}

// The whole lower panel in model coords: front face at z = -t, back at z = 0.
module lower_panel() {
    difference() {
        translate([0, 0, -t]) linear_extrude(t) difference() {
            lower_outline();
            translate(ax(brake_pos)) parking_brake_panel_cutout();
            translate(ax(throttle_pos)) throttle_panel_cutout();
            if (has_prop) translate(ax(prop_pos)) prop_panel_cutout();
            translate(ax(mixture_pos)) mixture_panel_cutout();
            frame_holes(lower_w, lower_h);
            if (len(yoke_hole) == 4) translate(ax(yoke_hole)) rounded_rect([yoke_hole[2], yoke_hole[3]], 6);
        }
        // splice-strip screw holes either side of each seam (blind, from the back)
        for (s = lower_splits, dx = [-10, 10], y = [25, lower_h - 25]) translate([-(s + dx), y, -t + 2]) cylinder(d = m3_pilot_d, h = t);
        for (p = has_prop ? [brake_pos, throttle_pos, prop_pos, mixture_pos] : [brake_pos, throttle_pos, mixture_pos])
            translate([ax(p)[0], ax(p)[1], -t]) mount_panel_countersinks();
        if (labels) translate([0, 0, -t - 0.01]) linear_extrude(0.61) {
            lower_label(brake_pos, "PARK BRAKE");
            lower_label(throttle_pos, "THROTTLE");
            if (has_prop) lower_label(prop_pos, "PROP");
            lower_label(mixture_pos, "MIXTURE");
        }
    }
}

// Tile i covers layout x from edge[i] to edge[i+1].
tile_edges = concat([-lower_w/2], lower_splits, [lower_w/2]);
module lower_tile(i) {
    x0 = tile_edges[i]; x1 = tile_edges[i + 1];
    translate([0, 0, t]) intersection() {
        lower_panel();
        translate([-x1, -1, -t - 1]) cube([x1 - x0, lower_h + 2, t + 2]);
    }
}

// Splice strip for the back of each seam: glue + 4x M3 x 10 screws.
module splice() {
    difference() {
        linear_extrude(4) translate([-15, 15]) square([30, lower_h - 30]);
        for (dx = [-10, 10], y = [25, lower_h - 25]) translate([dx, y, -1]) cylinder(d = m3_clear_d, h = 6);
    }
}

// ------------------------------------------------------------------ pedestal face + floor

module pedestal_panel() {
    difference() {
        translate([0, 0, -t]) linear_extrude(t) difference() {
            translate([-pedestal_w/2, -pedestal_h]) square([pedestal_w, pedestal_h]);
            translate([0, -pedestal_h/2]) trim_wheel_panel_cutout();
            frame_holes(pedestal_w, pedestal_h, -pedestal_h);
        }
        translate([0, -pedestal_h/2, -t]) trim_wheel_panel_countersinks();
    }
}

module floor_panel() {   // fuel-selector coords (front = cabin side at -z, +y forward)
    difference() {
        translate([0, 0, -t]) linear_extrude(t) difference() {
            translate([-pedestal_w/2 - 10, -floor_d / 2 - 10]) square([pedestal_w + 20, floor_d]);
            fuel_selector_panel_cutout();
            for (x = [-1, 1], y = [-1, 1]) translate([x * (pedestal_w/2), y * (floor_d/2 - 18) - 10]) circle(d = frame_hole_d);
        }
        translate([0, 0, -t]) fuel_selector_panel_countersinks();
    }
}

// ------------------------------------------------------------------ preview

module cockpit(rear = false) {
    // lower panel + its controls
    color([0.30, 0.31, 0.33]) lower_panel();
    translate(ax(brake_pos)) parking_brake_mounted(false);
    translate(ax(throttle_pos)) throttle_mounted(0.2);
    if (has_prop) translate(ax(prop_pos)) prop_mounted(0.3);
    translate(ax(mixture_pos)) mixture_mounted(0);
    // pedestal face with trim wheel
    translate([-pedestal_x, 0, 0]) {
        color([0.27, 0.28, 0.30]) pedestal_panel();
        translate([0, -pedestal_h/2, 0]) trim_wheel_mounted();
        // floor plate with the fuel selector, sticking out toward the pilot
        translate([0, -pedestal_h, -floor_d/2 - t]) rotate([90, 0, 0]) {
            color([0.27, 0.28, 0.30]) floor_panel();
            fuel_selector_mounted();
        }
    }
}

// ------------------------------------------------------------------ output

n_tiles = len(tile_edges) - 1;
for (i = [0 : n_tiles - 1]) {
    w = tile_edges[i + 1] - tile_edges[i];
    if (w > bed) echo(str("WARNING: lower panel tile ", i + 1, " is ", w, " mm wide - more than bed = ", bed, ". Add a split in lower_splits."));
}

if (part == "preview") rotate([90, 0, 0]) cockpit();
else if (part == "preview_rear") rotate([90, 0, 0]) cockpit(true);
else if (part == "lower_tile_1" && n_tiles >= 1) lower_tile(0);
else if (part == "lower_tile_2" && n_tiles >= 2) lower_tile(1);
else if (part == "lower_tile_3" && n_tiles >= 3) lower_tile(2);
else if (part == "splice") splice();
else if (part == "pedestal") translate([0, 0, t]) pedestal_panel();
else if (part == "floor") translate([0, 0, t]) floor_panel();
else if (part == "lower_2d") mirror([1, 0]) projection(cut = true) translate([0, 0, t / 2]) lower_panel();   // front view
else if (part == "pedestal_2d") mirror([1, 0]) projection(cut = true) translate([0, 0, t / 2]) pedestal_panel();   // front view
else if (part == "floor_2d") mirror([1, 0]) projection(cut = true) translate([0, 0, t / 2]) floor_panel();   // front view
