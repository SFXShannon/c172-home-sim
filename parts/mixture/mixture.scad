// Cessna 172 MIXTURE control. The shared mechanism lives in common/push_pull.scad;
// this file just picks the knob and panel hardware.
// Render one part:  openscad -D 'part="knob"' -o knob.stl mixture.scad

control = "mixture";
/* [What to show] */
part = "assembly"; // [assembly, assembly_in, assembly_out, exploded, knob, housing, carriage, escutcheon, panel_test_plate, panel_cutout]

include <../../common/push_pull.scad>
push_pull_output();

// For the panel layout files (panel/*.scad), which `use` this file.
module mixture_mounted(pos = 0) assembly(pos, slab = false);
module mixture_panel_cutout() push_pull_panel_cutout();
module mixture_panel_countersinks() mount_panel_countersinks();
