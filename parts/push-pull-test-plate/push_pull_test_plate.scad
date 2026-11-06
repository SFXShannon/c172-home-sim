// Bench test panel for the C172 home sim. Holds, with the same holes and
// countersinks as the real panel:
//   - THROTTLE, PROP and MIXTURE in a row (real 172 order, left to right)
//   - the ELEVATOR TRIM WHEEL under the throttle
//   - the PARKING BRAKE under the prop (handle stows pointing right)
//   - a 12.5 mm hole for a FUEL selector switch
//   - the IGNITION KEY (panel-extras key, lock face and bezel) on a 1-pole
//     12-position rotary switch (RS26 type, stop washer set to 5 positions),
//     with OFF R L BOTH START engraved round it
//   - blind pilot holes (no holes through the front) for the power breakout
//     (part "power_breakout"): a printed screw-terminal strip for GND and +5V
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
part = "assembly"; // [assembly, plate, pro_micro_box, pro_micro_clamp, pro_micro_box_view, power_breakout]

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

/* [Ignition key switch] */
// Hole for the rotary switch's threaded bushing (M9 / 3/8"; the bezel covers the edge)
ign_hole_d = 10;

/* [Pro Micro box] */
// Inside of the box (a Type-C Pro Micro is about 35 x 18 mm; the rest is room for wires and pins pointing up)
box_in = [52, 30, 25];
box_wall = 2;
// Pro Micro board: length, width, thickness (measure yours)
pm_size = [35, 18.3, 1.6];

/* [Power breakout] */
// Rails along the strip, left to right as seen from behind: [name, terminals]
breakout_rails = [["GND", 9], ["+5V", 5]];
// Terminal spacing (M3 pan heads are about 5.5 mm across)
bk_pitch = 8;
// Bus wire that runs the length of each rail: a stripped piece of solid wire (20-22 AWG is about 0.8 / 0.65 mm)
bk_bus = 1.4;                    // square tunnel it slides through
// Hole each incoming wire goes into (Dupont jumper wire, 22-26 AWG hookup wire, or a crimped Dupont pin)
bk_wire_d = 2.2;
// Mounting: M3 pan-head screws from behind, through the tabs into blind pilot holes in the plate
breakout_screw_len = 6;          // M3 x 6
breakout_tab_t = 2.5;            // tab thickness under the screw head

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
breakout_p = [97, -105];    // power breakout (its screw row), between the parking brake and the Pro Micro box
ign_p      = [-56, 2];      // ignition key, left of the throttle

box_out = [box_in[0] + 2 * box_wall, box_in[1] + 2 * box_wall, box_in[2] + box_wall];
box_screws = [for (x = [-1, 1], y = [-1, 1]) [x * (box_out[0] / 2 - 4), y * (box_out[1] / 2 - 4)]];
// power breakout layout, in its own frame: x along the strip, the screw row at
// y = 0, the wire holes in the +y face, floor (against the plate) at z = 0
bk_front  = 5;                                    // screw row to the wire face
bk_back   = 8;                                    // screw row to the back edge (labels on top)
bk_end    = 2;                                    // past the last terminal at each end of the strip
bk_gap    = 4;                                    // solid gap between two rails
bk_floor  = 1.5;
bk_h      = 11;
bk_pocket = [3.6, 5.2];                           // clamp pocket under each screw: width (x), top (z)
bk_wire_z = bk_floor + bk_bus + bk_wire_d / 2 - 0.1;   // wire hole centre: its bottom sits on top of the bus
bk_tab    = [10, 9];                              // mounting tabs off the back edge at each end
bk_len    = [for (r = breakout_rails) r[1] * bk_pitch];
function bk_sum(v, n) = n <= 0 ? 0 : v[n - 1] + bk_sum(v, n - 1);
bk_L      = bk_sum(bk_len, len(bk_len)) + (len(bk_len) - 1) * bk_gap + 2 * bk_end;
function bk_rail_x(i) = -bk_L / 2 + bk_end + bk_sum(bk_len, i) + i * bk_gap;      // left end of rail i
function bk_term_x(i, k) = bk_rail_x(i) + (k + 0.5) * bk_pitch;                     // terminal k of rail i
bk_screws = [for (s = [-1, 1]) [s * (bk_L / 2 - bk_tab[0] / 2), -bk_back - bk_tab[1] / 2]];
bk_pilot_depth = breakout_screw_len - breakout_tab_t + 0.7;   // blind hole in the plate

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
            translate(ign_p) circle(d = ign_hole_d);
            for (s = box_screws) translate(box_p + s) circle(d = m3_clear_d);
            for (h = holes) translate(h) circle(d = bolt_hole_d);
        }
        for (p = [throttle_p, prop_p, mixture_p]) translate(p) throttle_panel_countersinks();
        translate(brake_p) parking_brake_panel_countersinks();
        translate(trim_p) trim_wheel_panel_countersinks();
        for (s = box_screws) translate(box_p + s) m3_csk();
        // blind pilot holes for the power breakout, from the back (nothing shows on the front)
        for (s = bk_screws) translate([breakout_p[0] - s[0], breakout_p[1] + s[1], panel_thickness - bk_pilot_depth])
            cylinder(d = m3_pilot_d, h = bk_pilot_depth + 0.01);
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
// small lips hold the corners at the USB end (slide that end in under them).
// At the far end a separate L-shaped clamp screws down onto a post with one
// M2 screw; its foot presses on the board between the two pin rows, right
// over a small ledge under the board's end, so the board is clamped, not bent.
// Wires leave through big cut-outs in the rim on both long sides and the far
// end. Built floor down (as printed), open rim at the top.
pm_stand = 7;              // board sits this far off the floor
usb_open = [10, 5.6];      // USB-C opening: width, height around the socket (the socket is about 9 x 3.3)
usb_open_up = 3;           // extra opening on the rim side, for the cable plug's moulding
usb_z    = 0.4;            // centre of the socket relative to the top of the board
// L clamp at the far end
clamp_w     = 6;           // width of the clamp arm and foot (fits between the pin rows)
clamp_t     = 2;           // arm thickness (it flexes a little, that's the clamping force)
clamp_foot  = [3.5, 3];      // foot: length along the board, height (clears parts on top of the board)
clamp_in    = 0.3;         // foot starts this far in from the board's far edge
clamp_pre   = 0.2;         // post is this much lower than the arm, so the screw preloads the foot
post_sz     = 6;           // the post the clamp screws to
post_gap    = 3;           // gap between the board's far end and the post
m2_pilot_d  = 1.7;         // M2 screw straight into plastic
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
        // USB-C opening in the end wall, with extra room on the rim side for the plug
        translate([-box_out[0] / 2 - 1, -usb_open[0] / 2, z_top + usb_z - usb_open[1] / 2]) cube([box_wall + 2, usb_open[0], usb_open[1] + usb_open_up]);
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
    // ledge across the board's far end, under the clamp foot (between the pin rows)
    translate([x_far - 2.5, -5.5, box_wall - 0.01]) cube([2.5, 11, z_bot - box_wall + 0.01]);
    // post for the clamp screw
    difference() {
        translate([x_far + post_gap, -post_sz / 2, box_wall - 0.01]) cube([post_sz, post_sz, clamp_post_top() - box_wall + 0.01]);
        translate([clamp_screw_x(), 0, clamp_post_top() - 9]) cylinder(d = m2_pilot_d, h = 9.1);
    }
}

function pm_z_top() = box_wall + pm_stand + pm_size[2];
function pm_x_far() = -box_in[0] / 2 + pm_size[0];
function clamp_screw_x() = pm_x_far() + post_gap + post_sz / 2;
function clamp_post_top() = pm_z_top() + clamp_foot[1] - clamp_pre;

// The L clamp, in box coordinates (as fitted). Arm over the post, foot down on the board.
// Two small skirts hug the post so it can't swing round the screw.
module pro_micro_clamp() {
    zt = pm_z_top();
    xf = pm_x_far();
    x0 = xf - clamp_in - clamp_foot[0];         // tip of the foot
    x1 = xf + post_gap + post_sz;               // far end of the arm
    sk = 1.2;                                   // skirt thickness
    difference() {
        union() {
            // arm
            translate([x0, -clamp_w / 2, zt + clamp_foot[1]]) cube([x1 - x0, clamp_w, clamp_t]);
            // foot
            translate([x0, -clamp_w / 2, zt]) cube([clamp_foot[0], clamp_w, clamp_foot[1] + 0.01]);
            // wider pad over the post, with skirts down its sides
            translate([xf + post_gap, -post_sz / 2 - 0.25 - sk, zt + clamp_foot[1]]) cube([post_sz, post_sz + 0.5 + 2 * sk, clamp_t]);
            for (s = [-1, 1]) translate([xf + post_gap, s > 0 ? post_sz / 2 + 0.25 : -post_sz / 2 - 0.25 - sk, zt + clamp_foot[1] - 2.5])
                cube([post_sz, sk, 2.51]);
        }
        translate([clamp_screw_x(), 0, zt]) cylinder(d = 2.4, h = clamp_foot[1] + clamp_t + 1);
    }
}

// the board, for the pictures and checks (USB-C socket on top at the end)
module pro_micro_dummy() {
    z_bot = box_wall + pm_stand;
    color([0.1, 0.3, 0.6]) translate([-box_in[0] / 2, -pm_size[1] / 2, z_bot]) cube(pm_size);
    color("silver") translate([-box_in[0] / 2 - 1.2, -4.5, z_bot + pm_size[2] + usb_z - 1.65]) cube([7.5, 9, 3.3]);
    color("dimgray") translate([0, 0, -clamp_pre]) pro_micro_clamp();   // as screwed down
}

// ------------------------------------------------------------------ power breakout
// A fully printed screw-terminal strip, so several controls can share GND and
// +5V. Each rail has a square tunnel along it for a bare BUS WIRE (a stripped
// piece of solid 20-22 AWG wire pushed in from the end). Every terminal is a
// wire hole in the front face that crosses over the bus inside a little pocket,
// with an M3 x 10 screw threaded straight into the plastic above it: tighten
// the screw and it pinches the incoming wire's bare end down onto the bus.
// The strip screws on behind the plate with 2 x M3 x 6 pan-head screws from
// behind through the tabs into blind pilot holes; nothing goes through to the
// front. Rail names are engraved on top along the back edge.
// Built floor down; the floor goes against the plate.
module power_breakout() {
    difference() {
        union() {
            translate([-bk_L / 2, -bk_back, 0]) cube([bk_L, bk_back + bk_front, bk_h]);
            for (s = [-1, 1]) translate([s > 0 ? bk_L / 2 - bk_tab[0] : -bk_L / 2, -bk_back - bk_tab[1], 0])
                cube([bk_tab[0], bk_tab[1] + 0.01, breakout_tab_t]);
        }
        for (i = [0 : len(breakout_rails) - 1]) {
            // bus tunnel, open at both ends of the rail (and out the strip's ends for the outer rails)
            x0 = i == 0 ? -bk_L / 2 - 1 : bk_rail_x(i) - 0.6;
            x1 = i == len(breakout_rails) - 1 ? bk_L / 2 + 1 : bk_rail_x(i) + bk_len[i] + 0.6;
            translate([x0, -bk_bus / 2, bk_floor]) cube([x1 - x0, bk_bus, bk_bus]);
            for (k = [0 : breakout_rails[i][1] - 1]) translate([bk_term_x(i, k), 0, 0]) {
                // clamp pocket where the wire crosses the bus
                translate([-bk_pocket[0] / 2, -bk_bus / 2 - 0.6, bk_floor]) cube([bk_pocket[0], bk_front, bk_pocket[1] - bk_floor]);
                // wire hole from the front face
                translate([0, -0.5, bk_wire_z]) rotate([-90, 0, 0]) cylinder(d = bk_wire_d, h = bk_front + 1, $fn = 24);
                // screw, threaded into the plastic above the pocket
                translate([0, 0, bk_pocket[1] - 0.01]) cylinder(d = m3_tap_d(), h = bk_h, $fn = 24);
                translate([0, 0, bk_h - 0.4]) cylinder(d1 = m3_tap_d(), d2 = m3_tap_d() + 0.8, h = 0.41, $fn = 24);
            }
            // rail name along the back edge, with a bar over its terminals
            translate([bk_rail_x(i) + bk_len[i] / 2, -bk_back + 2.6, bk_h - 0.6])
                linear_extrude(1) text(breakout_rails[i][0], size = 3.2, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
            for (e = [0, 1]) translate([e == 0 ? bk_rail_x(i) + 0.8 : bk_rail_x(i) + bk_len[i] / 2 + 7, -bk_back + 2.35, bk_h - 0.6])
                cube([bk_len[i] / 2 - 7.8, 0.5, 1]);
        }
        for (s = bk_screws) translate([s[0], s[1], -1]) cylinder(d = m3_clear_d, h = breakout_tab_t + 2);
    }
}

// ------------------------------------------------------------------ views
function m(p) = [-p[0], p[1], 0];   // pilot's view -> model

// rim against the back of the plate, USB end toward the pilot's left
module box_placed() translate(m(box_p)) mirror([1, 0, 0]) translate([0, 0, box_out[2]]) mirror([0, 0, 1]) pro_micro_box();

module breakout_placed() translate(m(breakout_p)) color("seagreen") power_breakout();

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

// key, lock and bezel in front; the rotary switch behind
module ignition_placed() translate(m(ign_p)) translate([0, 0, -panel_thickness]) rotate([0, 180, 0]) {
    ignition_mounted();
    ignition_switch_dummy(panel_thickness);
}

module rails() mirror([1, 0, 0]) {
    translate([x0, y1 - rail_w, 0]) cube([W, rail_w, rail_w]);
    translate([x1 - rail_w, y0, 0]) cube([rail_w, H - rail_w, rail_w]);
}

module assembly() {
    color([0.30, 0.31, 0.33]) translate([0, 0, -panel_thickness]) plate();
    mounted_controls();
    color("steelblue") box_placed();
    breakout_placed();
    fuel_dummy();
    ignition_placed();
    color([0.78, 0.8, 0.83, 0.8]) rails();   // extrusion, just for the picture
}

if (part == "plate") plate();
else if (part == "pro_micro_box") pro_micro_box();
else if (part == "pro_micro_clamp") translate([0, 0, pm_z_top() + clamp_foot[1] + clamp_t]) mirror([0, 0, 1]) pro_micro_clamp();
else if (part == "pro_micro_box_view") { pro_micro_box(); pro_micro_dummy(); }
else if (part == "power_breakout") power_breakout();
else if (part == "assembly") rotate([90, 0, 0]) assembly();

echo(str("test panel: ", round(W), " x ", round(H), " mm, ", panel_thickness, " mm thick"));
echo(str("test panel: 8 mm holes at ", [for (h = holes) [round(h[0] - x0), round(h[1] - y0)]], " from the bottom-left corner (front view)"));
echo(str("fuel hole is ", round(norm(fuel_p - brake_p)), " mm from the brake; handle swing + knob radius = ", 95 + fuel_knob[0] / 2, " mm"));
echo(str("ignition: rotary switch; cut its shaft to ", 14 + panel_thickness, " mm from the mounting face (ends 14 mm in front of the panel)"));
echo(str("Pro Micro box: ", box_out, " mm outside; 4x M3 x ", box_screw_len, " countersunk screws from the front"));
echo(str("power breakout: ", [round(bk_L), bk_back + bk_front + bk_tab[1], bk_h], " mm; terminals ", [for (r = breakout_rails) str(r[0], " x ", r[1])], "; mount 2x M3 x ", breakout_screw_len, " pan head from behind; pilot holes ", bk_pilot_depth, " mm deep, ", panel_thickness - bk_pilot_depth, " mm of plastic left at the front"));
