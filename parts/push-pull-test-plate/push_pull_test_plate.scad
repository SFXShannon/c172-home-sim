// Bench test panel for the C172 home sim. Holds, with the same holes and
// countersinks as the real panel:
//   - THROTTLE, PROP and MIXTURE in a row (real 172 order, left to right)
//   - the ELEVATOR TRIM WHEEL under the throttle
//   - the PARKING BRAKE under the prop (handle stows pointing right)
//   - a 12.5 mm hole for a FUEL selector switch
//   - the IGNITION KEY (panel-extras key, lock face and bezel) on an EC11
//     rotary encoder, with OFF R L BOTH START engraved round it; a pocket in
//     the back thins the plate to 2 mm there so the encoder's short bushing
//     reaches through
//   - 4 countersunk holes for the Pro Micro box (part "pro_micro_box"), which
//     screws on behind the plate
// so you can build, wire and test everything before the dashboard exists.
//
// The plate stays flat (no bosses) so it prints fast. It bolts to 8020-style
// extrusion through four 8 mm holes: two along the top edge and two down the
// right edge. Everything behind the plate is kept clear of those strips.
//
// All layout numbers are as seen from the pilot's seat (+x = pilot's right,
// +y = up), with the throttle at [0, 0].
//
// Render one part:  openscad -D 'part="plate"' -o plate.stl push_pull_test_plate.scad

include <../../common/sim_common.scad>
use <../throttle/throttle.scad>
use <../prop/prop.scad>
use <../mixture/mixture.scad>
use <../parking-brake/parking_brake.scad>
use <../trim-wheel/trim_wheel.scad>
use <../panel-extras/panel_extras.scad>

/* [What to show] */
part = "assembly"; // [assembly, plate, pro_micro_box, pro_micro_box_view]

/* [Extrusion mount] */
// Extrusion width (20 = 2020, 25.4 = 1" 10-series, 40 = 4040)
rail_w = 40;
// Bolt holes (8.4 = clearance for an M8 or 5/16" bolt; set 8 for exact 8 mm)
bolt_hole_d = 8.4;
// Gap between anything behind the plate and the extrusion
rail_gap = 3;

/* [Layout] */
// Centre-to-centre spacing of the push-pull controls (the dashboard uses 69)
pitch = 69;
// Fuel selector hole (mm)
fuel_hole_d = 12.5;
// Stand-in fuel selector for the clearance checks: knob diameter / height in
// front, switch body diameter / depth behind (allow for a big knob)
fuel_knob = [40, 25];
fuel_body = [26, 25];
// Engrave labels on the front
labels = true;

/* [Ignition key encoder] */
// EC11 bushing hole (M7 thread)
enc_hole_d = 7.2;
// Pocket in the back for the encoder body (EC11 is about 12 x 12.4 mm)
enc_pocket = 13.6;
// Plate left in front of the encoder (its bushing is only about 5 mm long)
enc_skin = 2;

/* [Pro Micro box] */
// Inside of the box (a Type-C Pro Micro is about 35 x 18 mm; the rest is room for wires)
box_in = [52, 30, 20];
box_wall = 2;
// Pro Micro board: length, width, thickness (measure yours)
pm_size = [35, 18.3, 1.6];

/* [Hidden] */
flange_half = mount_flange_size / 2;   // 21

// positions (pilot's view)
throttle_p = [0, 0];
prop_p     = [pitch, 0];
mixture_p  = [2 * pitch, 0];
trim_p     = [0, -95];
brake_p    = [pitch, -62];
fuel_p     = [146, -153];   // outside the parking brake handle's swing (stowed -> set)
box_p      = [95, -145];
ign_p      = [-56, 2];      // ignition key, left of the throttle

box_out = [box_in[0] + 2 * box_wall, box_in[1] + 2 * box_wall, box_in[2] + box_wall];
box_screws = [for (x = [-1, 1], y = [-1, 1]) [x * (box_out[0] / 2 - 4), y * (box_out[1] / 2 - 4)]];
box_screw_len = [for (l = [12, 14, 16, 18, 20]) if (l >= panel_thickness + 8) l][0];

// plate outline
x0 = -84;                                             // room for the key labels and the trim placard on the left
y0 = -176;
x1 = mixture_p[0] + flange_half + rail_gap + rail_w;  // right edge
y1 = flange_half + rail_gap + rail_w;                 // top edge
W = x1 - x0; H = y1 - y0;

// bolt holes on the centre line of each extrusion strip
top_y = y1 - rail_w / 2;
right_x = x1 - rail_w / 2;
holes = [[x0 + 0.2 * W, top_y], [x0 + 0.62 * W, top_y],
         [right_x, y0 + 0.3 * H], [right_x, y0 + 0.62 * H]];

module label(p, t, dy) if (labels) translate([p[0], p[1] + dy, -0.01])
    linear_extrude(0.61) text(t, size = 5, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");

module m3_csk() translate([0, 0, -0.01]) cylinder(d1 = m3_head_d + 0.4, d2 = m3_clear_d, h = (m3_head_d + 0.4 - m3_clear_d) / 2);

// The model's x runs opposite to the pilot's right (pilot at -z, +y up), like
// the dashboard's ax(), so the plate is drawn in the pilot's view and mirrored.
// Front face at z = 0, plate extends to +z (prints front face down).
module plate() mirror([1, 0, 0]) {
    difference() {
        linear_extrude(panel_thickness) difference() {
            translate([x0, y0]) offset(4) offset(-4) square([W, H]);
            for (p = [throttle_p, prop_p, mixture_p]) translate(p) throttle_panel_cutout();
            translate(brake_p) parking_brake_panel_cutout();
            translate(trim_p) trim_wheel_panel_cutout();
            translate(fuel_p) circle(d = fuel_hole_d);
            translate(ign_p) circle(d = enc_hole_d);
            for (s = box_screws) translate(box_p + s) circle(d = m3_clear_d);
            for (h = holes) translate(h) circle(d = bolt_hole_d);
        }
        for (p = [throttle_p, prop_p, mixture_p]) translate(p) throttle_panel_countersinks();
        translate(brake_p) parking_brake_panel_countersinks();
        translate(trim_p) trim_wheel_panel_countersinks();
        for (s = box_screws) translate(box_p + s) m3_csk();
        // encoder pocket in the back
        translate([ign_p[0] - enc_pocket / 2, ign_p[1] - enc_pocket / 2, enc_skin]) cube([enc_pocket, enc_pocket, panel_thickness]);
        if (labels) translate([ign_p[0], ign_p[1], -0.01]) linear_extrude(0.61) ignition_labels_2d();
        // (the plate is mirrored, so plain text reads correctly from the front)
        label(throttle_p, "THROTTLE", -36); label(prop_p, "PROP", -36); label(mixture_p, "MIXTURE", -36);
        label(brake_p, "PARKING BRAKE", -29);
        label(fuel_p, "FUEL", 26);
        label(trim_p, "TRIM", -64);
        label(box_p, "PRO MICRO", 0);
        label(ign_p, "IGNITION", -22);
    }
}

// ------------------------------------------------------------------ Pro Micro box
// A cup that screws on behind the plate (the plate is its lid) with 4 x M3
// countersunk screws from the front into the corner posts. The board drops
// onto two ledges with its USB-C socket in the opening in the end wall. Two
// small lips hold the corners at the USB end (slide that end in under them),
// and a snap clip at the far end (where the board has no pins) clicks over it. Wires leave through big cut-outs in the rim on both long sides
// and the far end. Built floor down (as printed), open rim at the top.
pm_stand = 7;              // board sits this far off the floor (gives the clip room to flex)
usb_open = [10, 5.6];      // USB-C opening: width, height (the socket is about 9 x 3.3)
usb_z    = 0.4;            // centre of the opening relative to the top of the board
clip_t   = 1.0;            // snap clip thickness / width
clip_w   = 7;
usb_lip  = 1.0;            // corner lips at the USB end: how far they reach over the board
usb_lip_len = 2.5;         // and how far along it
wire_cut = [[30, 9], [16, 9]];   // rim cut-outs: long sides [width, depth], far end [width, depth]

module pro_micro_box() {
    z_bot  = box_wall + pm_stand;            // underside of the board
    z_top  = z_bot + pm_size[2];             // top of the board
    x_usb  = -box_in[0] / 2;                 // USB end of the board (against the end wall)
    x_far  = x_usb + pm_size[0];             // far end of the board
    difference() {
        union() {
            difference() {
                translate([-box_out[0] / 2, -box_out[1] / 2, 0]) cube(box_out);
                translate([-box_in[0] / 2, -box_in[1] / 2, box_wall]) cube([box_in[0], box_in[1], box_in[2] + 1]);
            }
            // corner posts
            for (s = box_screws) translate([s[0] - 4, s[1] - 4, 0]) cube([8, 8, box_out[2]]);
            // ledges under the board's long edges, with low side rails
            for (s = [-1, 1]) translate([x_usb - 0.01, s > 0 ? pm_size[1] / 2 - 1.5 : -pm_size[1] / 2 - 1.5, box_wall - 0.01])
                cube([pm_size[0] + 0.5, 3, pm_stand + pm_size[2] + 1]);
        }
        // pocket the board drops into (0.25 mm play), open above
        translate([x_usb - 1, -pm_size[1] / 2 - 0.25, z_bot]) cube([pm_size[0] + 1.15, pm_size[1] + 0.5, 20]);
        // ledges are only 1.25 mm wide under each edge; open the middle under the board for its pins
        translate([x_usb - 1, -pm_size[1] / 2 + 1.25, box_wall]) cube([pm_size[0] + 1.15, pm_size[1] - 2.5, 20]);
        // USB-C opening in the end wall
        translate([-box_out[0] / 2 - 1, -usb_open[0] / 2, z_top + usb_z - usb_open[1] / 2]) cube([box_wall + 2, usb_open[0], usb_open[1]]);
        // wire cut-outs in the rim: both long sides and the far end
        for (s = [-1, 1]) translate([-wire_cut[0][0] / 2, s > 0 ? box_in[1] / 2 - 1 : -box_out[1] / 2 - 1, box_out[2] - wire_cut[0][1]])
            cube([wire_cut[0][0], box_wall + 2, wire_cut[0][1] + 1]);
        translate([box_in[0] / 2 - 1, -wire_cut[1][0] / 2, box_out[2] - wire_cut[1][1]]) cube([box_wall + 2, wire_cut[1][0], wire_cut[1][1] + 1]);
        // pilot holes in the posts
        for (s = box_screws) translate([s[0], s[1], box_out[2] - 12]) cylinder(d = m3_pilot_d, h = 12.1);
    }
    // fixed lips over the two corners at the USB end: slide that end in under them first
    for (s = [-1, 1]) translate([x_usb - 0.01, s > 0 ? pm_size[1] / 2 - usb_lip : -pm_size[1] / 2 - 1.75, z_top + 0.3])
        cube([usb_lip_len, usb_lip + 1.75, 1.25]);
    // snap clip: a springy post at the far end with a hook over the board (added after the cuts)
    translate([x_far + 0.15, -clip_w / 2, box_wall - 0.01]) cube([clip_t, clip_w, z_top + 1.8 - box_wall]);
    translate([0, clip_w / 2, 0]) rotate([90, 0, 0]) linear_extrude(clip_w)
        polygon([[x_far + 0.16, z_top + 0.15], [x_far - 0.8, z_top + 0.15], [x_far - 0.8, z_top + 0.55], [x_far + 0.16, z_top + 1.8]]);
}

// the board, for the pictures and checks (USB-C socket on top at the end)
module pro_micro_dummy() {
    z_bot = box_wall + pm_stand;
    color([0.1, 0.3, 0.6]) translate([-box_in[0] / 2, -pm_size[1] / 2, z_bot]) cube(pm_size);
    color("silver") translate([-box_in[0] / 2 - 1.2, -4.5, z_bot + pm_size[2] + usb_z - 1.65]) cube([7.5, 9, 3.3]);
}

// ------------------------------------------------------------------ views
function m(p) = [-p[0], p[1], 0];   // pilot's view -> model

// rim against the back of the plate, USB end toward the pilot's left
module box_placed() translate(m(box_p)) mirror([1, 0, 0]) translate([0, 0, box_out[2]]) mirror([0, 0, 1]) pro_micro_box();

module mounted_controls(brake_set = false) {
    translate(m(throttle_p)) throttle_mounted(0.2);
    translate(m(prop_p)) prop_mounted(0.5);
    translate(m(mixture_p)) mixture_mounted(0);
    translate(m(brake_p)) parking_brake_mounted(set = brake_set);
    translate(m(trim_p)) trim_wheel_mounted();
}

module fuel_dummy() translate(m(fuel_p)) {
    color([0.15, 0.15, 0.15]) translate([0, 0, -panel_thickness - fuel_knob[1]]) cylinder(d = fuel_knob[0], h = fuel_knob[1]);
    color("dimgray") cylinder(d = fuel_body[0], h = fuel_body[1]);
}

// key, lock and bezel in front; EC11 encoder sitting in its pocket behind
module ignition_placed() translate(m(ign_p)) {
    translate([0, 0, -panel_thickness]) rotate([0, 180, 0]) ignition_mounted();
    color("dimgray") translate([-6.2, -6, -panel_thickness + enc_skin]) cube([12.4, 12, 6.5]);
    color("silver") for (x = [-2.5, 0, 2.5]) translate([x, -7.5, -panel_thickness + enc_skin + 3]) cube([0.6, 0.6, 9]);
}

module rails() mirror([1, 0, 0]) {
    translate([x0, y1 - rail_w, 0]) cube([W, rail_w, rail_w]);
    translate([x1 - rail_w, y0, 0]) cube([rail_w, H - rail_w, rail_w]);
}

module assembly() {
    color([0.30, 0.31, 0.33]) translate([0, 0, -panel_thickness]) plate();
    mounted_controls();
    color("steelblue") box_placed();
    fuel_dummy();
    ignition_placed();
    color([0.78, 0.8, 0.83, 0.8]) rails();   // extrusion, just for the picture
}

if (part == "plate") plate();
else if (part == "pro_micro_box") pro_micro_box();
else if (part == "pro_micro_box_view") { pro_micro_box(); pro_micro_dummy(); }
else if (part == "assembly") rotate([90, 0, 0]) assembly();

echo(str("test panel: ", round(W), " x ", round(H), " mm, ", panel_thickness, " mm thick"));
echo(str("test panel: 8 mm holes at ", [for (h = holes) [round(h[0] - x0), round(h[1] - y0)]], " from the bottom-left corner (front view)"));
echo(str("fuel hole is ", round(norm(fuel_p - brake_p)), " mm from the brake; handle swing + knob radius = ", 95 + fuel_knob[0] / 2, " mm"));
echo(str("ignition: EC11 encoder; cut its shaft to ", 9 + enc_skin, " mm from the mounting face (ends 9 mm in front of the panel)"));
echo(str("Pro Micro box: ", box_out, " mm outside; 4x M3 x ", box_screw_len, " countersunk screws from the front"));
