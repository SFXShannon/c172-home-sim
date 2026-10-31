// Bench test plate for the THROTTLE, PROP and MIXTURE push-pull controls.
// Holds all three in a row (real 172 order, left to right: throttle, prop,
// mixture) with the same holes and countersinks as the real panel, so you can
// build and wire them up before the dashboard exists.
//
// It bolts to 8020-style aluminium extrusion through four 8 mm holes: two
// along the top edge and two down the right edge. The strips those holes sit
// in are kept clear of the control housings, so the extrusion can run along
// the back of the top and right edges.
//
// Render one part:  openscad -D 'part="plate"' -o plate.stl push_pull_test_plate.scad

include <../../common/sim_common.scad>
use <../throttle/throttle.scad>
use <../prop/prop.scad>
use <../mixture/mixture.scad>

/* [What to show] */
part = "assembly"; // [assembly, plate]

/* [Extrusion mount] */
// Extrusion width (20 = 20-series / 2020, 25.4 = 1" 10-series, 40 = 4040)
rail_w = 40;
// Bolt holes (8.4 = clearance for an M8 or 5/16" bolt; set 8 for exact 8 mm)
bolt_hole_d = 8.4;
// Gap between a control's mounting flange and the extrusion
rail_gap = 3;

/* [Layout] */
// Centre-to-centre spacing of the controls (the dashboard uses 69)
pitch = 69;
// Engrave THROTTLE / PROP / MIXTURE under the knobs
labels = true;

/* [Hidden] */
flange_half = mount_flange_size / 2;   // 21
flange_bot  = 27;                       // housing flange runs this far below the rod
xs = [0, pitch, 2 * pitch];
names = ["THROTTLE", "PROP", "MIXTURE"];

x0 = -flange_half - 8;                               // left edge
y0 = -flange_bot - 16;                               // bottom edge (room for labels)
x1 = 2 * pitch + flange_half + rail_gap + rail_w;    // right edge
y1 = flange_half + rail_gap + rail_w;                // top edge
W = x1 - x0; H = y1 - y0;

// bolt holes sit on the centre line of each extrusion strip
top_y = y1 - rail_w / 2;
right_x = x1 - rail_w / 2;
holes = [[x0 + 0.2 * W, top_y], [x0 + 0.62 * W, top_y],
         [right_x, y0 + 0.25 * H], [right_x, y0 + 0.62 * H]];

// Layout numbers above are as seen from the pilot's seat (+x = pilot's right).
// The model's x runs the other way (pilot at -z, +y up), like the dashboard's ax().
// Front face at z = 0, plate extends to +z (prints front face down).
module plate() mirror([1, 0, 0]) {
    difference() {
        linear_extrude(panel_thickness) difference() {
            translate([x0, y0]) rounded_rect_corner([W, H], 4);
            for (x = xs) translate([x, 0]) throttle_panel_cutout();
            for (h = holes) translate(h) circle(d = bolt_hole_d);
        }
        for (x = xs) translate([x, 0, 0]) throttle_panel_countersinks();
        if (labels) for (i = [0 : 2]) translate([xs[i], -flange_bot - 7, -0.01])
            linear_extrude(0.61) text(names[i], size = 5, halign = "center", valign = "center",
                font = "Liberation Sans:style=Bold");
    }
}

module rounded_rect_corner(size, r) {
    translate([r, r]) offset(r) square([size[0] - 2 * r, size[1] - 2 * r]);
}

// Same coordinates as the controls: panel back at z = 0, pilot at -z, +y up.
module assembly() {
    color([0.30, 0.31, 0.33]) translate([0, 0, -panel_thickness]) plate();
    translate([-xs[0], 0, 0]) throttle_mounted(0.2);
    translate([-xs[1], 0, 0]) prop_mounted(0.5);
    translate([-xs[2], 0, 0]) mixture_mounted(0);
    // extrusion behind the top and right edges (just for the picture)
    color([0.78, 0.8, 0.83, 0.8]) mirror([1, 0, 0]) {
        translate([x0, y1 - rail_w, 0]) cube([W, rail_w, rail_w]);
        translate([x1 - rail_w, y0, 0]) cube([rail_w, H - rail_w, rail_w]);
    }
}

if (part == "plate") plate();
else rotate([90, 0, 0]) assembly();

echo(str("test plate: ", round(W), " x ", round(H), " mm, ", panel_thickness, " mm thick"));
echo(str("test plate: 8 mm holes at ", [for (h = holes) [round(h[0] - x0), round(h[1] - y0)]], " from the bottom-left corner (front view)"));
