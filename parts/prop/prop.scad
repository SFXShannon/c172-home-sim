// Cessna 172 PROP control. The shared mechanism lives in common/push_pull.scad;
// this file just picks the knob and panel hardware.
// Render one part:  openscad -D 'part="knob"' -o knob.stl prop.scad

control = "prop";
/* [What to show] */
part = "assembly"; // [assembly, assembly_in, assembly_out, exploded, knob, housing, carriage, escutcheon, panel_test_plate, panel_cutout]

include <../../common/push_pull.scad>
push_pull_output();

// For the panel layout files (panel/*.scad), which `use` this file.
module prop_mounted(pos = 0) assembly(pos, slab = false);
module prop_panel_cutout() push_pull_panel_cutout();
module prop_panel_countersinks() mount_panel_countersinks();
