// Simple U-shaped cradle that goes under the 128 mm slide pot.
// 20 mm wide, 4 mm thick bottom, sides stand 2 mm up from the bottom.
// Render:  openscad -o pot_cradle.stl pot_cradle.scad

/* [Cradle] */
// Outside width (mm)
width = 20;
// Bottom thickness (mm)
base_t = 4;
// How far the sides stand up above the bottom (mm)
side_h = 2;
// Length (mm). 128 = same as the pot body
length = 128;
// Pot body width + clearance (mm). Fielect 128 mm pot is 15.7 wide
pot_w = 15.7;
clearance = 0.3;

inner = pot_w + 2 * clearance;
wall = (width - inner) / 2;
assert(wall > 0.8, "Width too small for the pot");

// Lies on its bottom, length along y
difference() {
    translate([-width / 2, 0, 0]) cube([width, length, base_t + side_h]);
    translate([-inner / 2, -1, base_t]) cube([inner, length + 2, side_h + 1]);
}

echo(str("pot cradle: ", width, " x ", length, " mm, ", base_t + side_h, " mm tall; inside ", inner, " mm, side walls ", wall, " mm"));
