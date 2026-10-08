// Cessna 172 THROTTLE control. The shared mechanism lives in common/push_pull.scad;
// this file just picks the knob and panel hardware.
// Render one part:  openscad -D 'part="knob"' -o knob.stl throttle.scad

control = "throttle";
/* [What to show] */
part = "assembly"; // [assembly, assembly_in, assembly_out, exploded, knob, housing, carriage, escutcheon, panel_test_plate, panel_cutout]

include <../../common/push_pull.scad>
push_pull_output();

// For the panel layout files (panel/*.scad), which `use` this file.
module throttle_mounted(pos = 0) assembly(pos, slab = false);
module throttle_panel_cutout() push_pull_panel_cutout();
module throttle_panel_countersinks() mount_panel_countersinks();
