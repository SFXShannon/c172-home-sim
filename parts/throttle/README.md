# Throttle (and the shared push-pull mechanism)

Throttle, mixture and prop all use the same simple mechanism. Only the knob and the panel nut change:

| Control | Knob | Panel nut | Folder |
|---|---|---|---|
| **Throttle** | Smooth round knob with a flat face. Print it black, or cream for older 172s | Knurled friction-lock nut | here |
| **Mixture** | Red, fine ribs around the edge, lock button in the centre (vernier style) | Hex bushing nut | [`../mixture`](../mixture) |
| **Prop** | Blue, crenellated edge (172RG / 182 / constant-speed) | Hex bushing nut | [`../prop`](../prop) |

![throttle working](../../docs/anim/throttle.gif)

| Pushed in | Pulled out | Behind the panel |
|---|---|---|
| ![](images/assembly_in.png) | ![](images/assembly_out.png) | ![](images/rear.png) |

## How it works (kept simple)

- **Shaft:** a 5/16" (7.94 mm) smooth steel rod (drill rod, ground rod or a straight piece of cold-rolled round from the hardware store). 8 mm printer rod also works: set `rod_d = 8`. It slides through a printed U-channel bolted behind the panel.
- **Friction:** a size 011 O-ring (0.301" ID × 0.070", the 5/16" O-ring in hardware-store assortments) in the front bushing holds the knob wherever you leave it, like the friction lock on the real throttle.
- **Sensor:** a printed carriage clamped to the rod with an M3 set screw pushes the lever of a slide potentiometer that sits in the bottom of the channel. It's drawn for the Fielect **128 mm** fader (10K linear, 100 mm travel, body 128 × 15.7 × 6.9 mm). The lever height (`pot_lever_h = 5`) is read off a photo, so measure yours.
- **Travel:** 60 mm (`control_travel`), set by the bushings, about like the real knob. That uses the middle 60 % of the pot's travel; the Pro Micro sketch learns the range and stretches it to the full axis. The housing reaches about 140 mm behind the panel.

## Parts list (per control)

| Qty | Item | Notes |
|---|---|---|
| 1 each | Printed: `knob`, `escutcheon`, `housing`, `carriage` | [`stl/`](stl) |
| 1 | 5/16" smooth steel rod, 212 mm (8 3/8") | OpenSCAD prints the exact length. Cut it with a hacksaw and file the ends; take any burr off so it slides through the bushings. |
| 1 | Slide potentiometer, 10 kΩ linear, 128 mm long / 100 mm travel (e.g. Fielect 128 mm fader) | Sits in the channel floor. Measure yours and set `pot_len`, `pot_w`, `pot_h`, `pot_lever_h`, `pot_travel` if they differ (a 60 mm pot works too: `pot_len = 76`, `pot_travel = 60`) |
| 1 | O-ring, size 011 (0.301" ID × 0.070") | For friction. A metric 8 × 2 mm O-ring also fits if you set `oring_cs = 2` |
| 1 + 1 | M3 × 8 set screw + M3 nut | Carriage clamp |
| 4 + 4 | M3 × 14 countersunk screws + M3 nuts | Panel mount |
| 2 | Zip ties | Hold the pot down |

## Printing

No supports needed.

- **housing:** lies on its floor. If the rod bores come out tight, ream them with an 8.5 mm (or 21/64") drill.
- **knob:** the throttle prints face-down; the mixture and prop print back-down. For the mixture, use a colour change to make the button black, or paint it.
- **escutcheon:** prints front face down.

## Assembly

1. Seat the O-ring in the groove inside the front bushing, then zip-tie the pot into the channel floor with its lever pointing up.
2. Push the rod in from the front through the bushing. Slide the carriage on with its slot over the pot lever, then push the rod on through the rear bushing.
3. Push the rod fully in and slide the carriage back against the rear bushing. Tighten the set screw.
4. Bolt the housing behind the panel with "UP" at the top. Push the escutcheon into the hole, then glue the knob onto the rod (CA or epoxy).

## Wiring and sim

Wire the pot ends to 5V and GND, and the wiper to an analog input. With the Pro Micro sketch in [`/firmware`](../../firmware): throttle on A0 (X axis), mixture on A1 (Y axis), prop on A2 (Z axis).

In MSFS, bind the axes to *Throttle axis*, *Mixture axis* and *Propeller axis*. If one works backwards, use the reverse option in MSFS or the `REVERSE_` setting in the sketch.

**Note:** the GP-Wiz is a button board, so it can't read these pots. That's why the Pro Micro sketch is included.
