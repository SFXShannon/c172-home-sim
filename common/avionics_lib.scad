// Shared building blocks for the avionics bezels (G1000 PFD/MFD, audio panel).
//
// Bezels are modelled FACE-UP, as you see them from the seat: x to the right,
// y up, the face at z = 0 and everything behind it at negative z.
//
//   z 0 .. -face_t           printed front plate (key holes, knob holes, labels)
//   key caps                 T-shaped: the face part pokes 2 mm out of the
//                            front plate, the flange behind it keeps it in and
//                            presses the switch plunger directly (prints flange-down)
//   z -sw_z ..               printed switch plate holding 6 x 6 mm tactile
//                            switches (the common 6x6x5 mm through-hole kind)
//   encoders                 EC11 single and EC11 dual-shaft, bushing through
//                            the front plate, nut on the face (the knob hides it)
//
// Include after sim_common.scad.

face_t      = 3;      // front plate thickness
cap_out     = 2;      // how far keys stand proud of the face
cap_flange  = 1.2;    // key-cap flange thickness
cap_stem    = 0.2;    // free play between the cap flange and the switch plunger
tact_body   = 3.5;    // 6x6 switch body height
tact_plunge = 1.5;    // plunger above the body
pocket_d    = 1.0;    // switch body sits this deep in its pocket
sw_gap      = cap_flange + cap_stem + tact_plunge + tact_body - pocket_d;  // face back -> switch plate front
sw_z        = face_t + sw_gap;   // switch plate front face
sw_t        = 2.5;    // switch plate thickness
post_d      = 6;      // standoff posts on the back of the front plate

enc1_bush_d = 7.3;    // EC11 single: M7 bushing
enc2_bush_d = 9.3;    // EC11 dual-shaft (ALPS EC11EBB24C03 etc.); fine for M7 with a washer too
enc_body    = 13.5;   // clearance for the encoder body in the switch plate

label_font  = "Liberation Sans:style=Bold";

// ---------- front plate features (subtract from the plate; face at z = 0)

module key_hole(w, h) {
    translate([0, 0, -face_t - 1]) linear_extrude(face_t + 2) rounded_rect([w + 0.4, h + 0.4], 1.2);
}
module enc_hole(dual = false) {
    translate([0, 0, -face_t - 1]) cylinder(d = dual ? enc2_bush_d : enc1_bush_d, h = face_t + 2);
}
// Recessed label in the face. Fill with white paint.
module face_label(txt, size = 2.6, halign = "center") {
    translate([0, 0, -0.6]) linear_extrude(1)
        text(txt, size = size, font = label_font, halign = halign, valign = "center");
}
// Two-headed arrow (the frequency "flip" key symbol), 2D
module flip_arrow(w = 7, h = 3) {
    union() {
        translate([-w/2 + 1.5, -0.4]) square([w - 3, 0.8]);
        for (s = [-1, 1]) translate([s * (w/2 - 1.5), 0]) polygon([[0, h/2], [s * 1.6, 0], [0, -h/2]]);
    }
}

// Standoff posts on the back of the front plate (add to the plate)
module face_post(h = sw_gap) {
    difference() {
        translate([0, 0, -face_t - h]) cylinder(d = post_d, h = h + 0.01);
        translate([0, 0, -face_t - h - 1]) cylinder(d = m3_pilot_d, h = h);
    }
}

// ---------- switch plate features (switch plate front face at z = -sw_z, plate below it)

// Pocket + leg holes for a 6x6 tactile switch, centred on the key.
module tact_pocket() {
    translate([-3.2, -3.2, -sw_z - pocket_d]) cube([6.4, 6.4, pocket_d + 0.01]);  // locate the body
    for (x = [-3.25, 3.25], y = [-2.25, 2.25]) translate([x, y, -sw_z - sw_t - 1]) cylinder(d = 1.3, h = sw_t + 2, $fn = 12);
}
module enc_clear() {
    translate([-enc_body/2, -enc_body/2, -sw_z - sw_t - 1]) cube([enc_body, enc_body, sw_t + 2]);
}
// Key-cap label geometry, at a cap's top face (for render paint)
module cap_label_geom(w, txt, tsize = 2.2, arrow = false) {
    translate([0, 0, -0.6]) linear_extrude(1) {
        if (len(txt) > 0) text(txt, size = tsize, font = label_font, halign = "center", valign = "center");
        if (arrow) flip_arrow(min(w - 3, 7), 3);
    }
}

// Place a key cap (modelled flange-down) in its hole
module cap_in_place() { translate([0, 0, -face_t - cap_flange]) children(); }

// ---------- key caps (printed flange-down, label on top)

// w x h = visible key size. Label is engraved into the key face.
module key_cap(w, h, txt = "", tsize = 2.2, arrow = false) {
    difference() {
        union() {
            linear_extrude(cap_flange) rounded_rect([w + 3, h + 3], 1.5);
            translate([0, 0, cap_flange - 0.01]) linear_extrude(face_t + cap_out + 0.01) rounded_rect([w - 0.2, h - 0.2], 1);
        }
        top = cap_flange + face_t + cap_out;
        if (len(txt) > 0) translate([0, 0, top - 0.5]) linear_extrude(1)
            text(txt, size = tsize, font = label_font, halign = "center", valign = "center");
        if (arrow) translate([0, 0, top - 0.5]) linear_extrude(1) flip_arrow(min(w - 3, 7), 3);
        // slight dish
        translate([0, 0, top + 6 - 0.3]) scale([w / 8, h / 8, 1]) sphere(r = 6, $fn = 32);
    }
}

// ---------- knobs (printed top-down: the grip face on the bed is the knob's front)

// Single EC11 knob, 6 mm D shaft (EC11 standard: 6 mm with a flat, 4.5 across)
module knob_single(d = 15, h = 12, ribs = 24) {
    difference() {
        union() {
            ribbed_cylinder(d / 2, h, n = ribs, depth = 0.6);
            cylinder(d1 = d - 1.6, d2 = d, h = 0.8);
        }
        translate([0, 0, 1.5]) linear_extrude(h) difference() {
            circle(d = 6.15);
            translate([-5, 1.6]) square([10, 5]);
        }
    }
}
// Dual knob, outer part: on the 6 mm (slotted) outer shaft
module knob_dual_outer(d = 19, h = 7) {
    difference() {
        ribbed_cylinder(d / 2, h, n = 30, depth = 0.6);
        translate([0, 0, -1]) cylinder(d = 6.1, h = h + 2);
    }
}
// Dual knob, inner part: on the 3.5 mm (flatted) inner shaft
module knob_dual_inner(d = 12, h = 13) {
    difference() {
        union() {
            ribbed_cylinder(d / 2, h, n = 20, depth = 0.5);
            cylinder(d1 = d - 1.2, d2 = d, h = 0.6);
        }
        translate([0, 0, 2]) linear_extrude(h) difference() {
            circle(d = 3.6);
            translate([-3, 1.1]) square([6, 3]);
        }
    }
}
