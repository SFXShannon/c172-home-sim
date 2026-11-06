include <push_pull_test_plate.scad>
// breakout plus room for the wires (25 mm past the wire side) and the levers swung open (25 mm up)
intersection() {
  union() { mounted_controls(); mounted_controls(true); box_placed(); fuel_dummy(); ignition_placed(); }
  translate(m(breakout_p)) translate([-bk_out[0]/2, bk_y0, 0.01]) cube([bk_out[0], bk_out[1] + 25, 25]);
}
