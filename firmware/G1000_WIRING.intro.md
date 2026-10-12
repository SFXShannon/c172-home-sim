# G1000 dashboard: electronics and MSFS setup

The dashboard uses four small boards, all plugged into one powered USB hub:

| Board | Runs | Handles |
|---|---|---|
| Arduino Pro Micro | [`c172_panel.ino`](c172_panel/c172_panel.ino) (a USB joystick) | Throttle, mixture, prop, flaps (axes), parking brake, fuel selector, trim wheel |
| Arduino Mega 2560 #1 | [MobiFlight](https://www.mobiflight.com) | PFD bezel: 32 keys, 9 knobs |
| Arduino Mega 2560 #2 | MobiFlight | MFD bezel: same as the PFD |
| Arduino Mega 2560 #3 | MobiFlight | Audio panel, C-post switches, lights/dimming panel, ignition key, standby gauges |

As far as I know, your GP-Wiz is a button-only board. It could take some of the board 3 switches if you like, but the knobs (encoders) and dimmers need the Megas.

## Wiring rules (all boards)

- **Switches and keys:** wire between the pin and **GND**. MobiFlight turns on the internal pull-ups, so you don't need resistors.
- **Encoders:** A and B to the two listed pins, the middle pin (C) to **GND**. On the ALPS dual-shaft EC11, wire the outer and inner encoders separately; they're listed as two encoders below.
- **Encoder push switches** (VOL, HDG, RANGE): the two switch legs go to the listed pin and GND.
- **Rockers and toggles:** use the common terminal and the ON terminal.
- **Grounds:** run one ground bus per bezel (a bare wire along the back of the switch plate) and solder every switch's ground leg to it. That's about 65 wires per bezel, so ribbon cable or Dupont jumpers to the Mega headers keep it tidy.

## Screens

The PFD and MFD screens are two 10.4" 4:3 1024×768 LCD panels with HDMI driver boards (the usual "10.4 inch LCD + HDMI controller kit"). In MSFS 2024, right-Alt + click the PFD to pop it out, drag it to the PFD screen and make it full screen. Do the same for the MFD. The screen cradles hold the LCD by its edges, so measure your panel and set `lcd_w`, `lcd_h` and `lcd_t` in `parts/g1000-gdu/gdu1040.scad` before printing them.

## MobiFlight events

In MobiFlight, add each input with **Action type: MSFS2020 - Events (Presets)** (it works with MSFS 2024) and search the HubHop preset list for the control. Look in the "Cessna 172 / G1000" or "Generic AS1000" groups. Suggested presets:

| Control | Preset / event to search for |
|---|---|
| Softkeys | `AS1000 PFD Softkey 1..12` / `AS1000 MFD Softkey 1..12` |
| NAV, COM, FMS knobs | `AS1000 PFD NAV Large / Small Inc / Dec`, `... COM ...`, `... FMS Upper / Lower ...` |
| NAV / COM flip keys | `AS1000 PFD NAV Switch`, `AS1000 PFD COM Switch` |
| HDG, CRS, BARO | `Heading bug inc / dec`, `VOR1 OBI inc / dec`, `Kohlsman inc / dec` (push HDG = heading bug sync) |
| RANGE | `AS1000 PFD/MFD Range inc / dec` |
| FMS keys | `AS1000 PFD/MFD DirectTo, Menu, FPL, PROC, CLR, ENT` |
| AP keys | `AP master`, `Flight director`, `AP heading hold`, `AP altitude hold`, `AP NAV1 hold`, `AP approach hold`, `AP back course`, `AP VS hold`, `FLC`, `VS / pitch up / down`, `VNAV` |
| ALT knob | `AP altitude var inc / dec` (outer = 1000 ft, inner = 100 ft) |
| MASTER ALT / BAT | `Alternator set`, `Master battery set` (bind the press as on and the release as off) |
| AVIONICS BUS 1 / 2 | `Avionics master 1 / 2 set` |
| Lights | `Beacon / Landing / Taxi / Nav / Strobe lights set` |
| FUEL PUMP, PITOT HEAT | `Fuel pump set`, `Pitot heat set` |
| Ignition | `Magneto off / right / left / both / start` |
| Dimmers | `Light potentiometer set` (analog input), one index per knob |
| Audio panel | `COM1 / COM2 transmit select`, `COM receive`, `NAV1 / NAV2 / ADF / DME / MKR audio`; the dual knob's outer and inner rings are two encoders (for example volume and squelch) |

Preset names in HubHop change now and then, so search by these words. The events above are the standard MSFS ones I expect; check each one on the ground before relying on it.

The Pro Micro shows up as a normal joystick. In MSFS, bind X to *Throttle axis*, Y to *Mixture axis*, Z to *Propeller axis* and Rx to *Flaps axis*. The buttons are listed in [`README.md`](README.md).

## Standby gauges

The three standby instruments are MobiFlight **outputs** on board 3: two steppers and two servos, read from sim variables.

| Gauge | MobiFlight device | Sim variable | Mapping |
|---|---|---|---|
| Airspeed | Stepper, the x27 profile (or 4 pins, 945 steps for 315 degrees at 1/3 degree per step) | `AIRSPEED INDICATED` (knots) | The needle rests on the X27's stop below 40 kt. Use MobiFlight's interpolation: 0 kt → 0 steps, 40 kt → 22 steps, 200 kt → 922 steps (3 steps per degree, 300 degrees from 40 to 200 kt). |
| Altimeter | Stepper, the 28BYJ-48 profile (ULN2003 driver board), with the hall sensor as its zero/homing pin | `INDICATED ALTITUDE` (feet) | One motor turn is 1000 ft: steps = feet × (steps per turn ÷ 1000), with the steps per turn MobiFlight uses for the 28BYJ-48 (about 2048). The gear train moves the 1000-ft hand by itself. |
| Altimeter baro knob | Encoder | `KOHLSMAN_INC` / `KOHLSMAN_DEC` | For the standby altimeter, use the second Kollsman index if your aircraft has one; otherwise it sets the main baro. |
| Attitude, roll | Servo | `ATTITUDE INDICATOR BANK DEGREES` | −90…+90° → servo 0…180° (centre = wings level). Reverse it if it rolls the wrong way. |
| Attitude, pitch | Servo | `ATTITUDE INDICATOR PITCH DEGREES` | Servo = 90° + 2 × pitch: the drum turns 2° per degree of pitch, so the 5° pitch lines are 5 mm apart. |

- **Power:** the X27 and the 28BYJ-48's ULN2003 board run fine from the Mega's 5 V. The two SG90 servos draw up to about 0.7 A each when they move, so give them their own 5 V supply (a 5 V 2 A adapter or the powered USB hub), with its ground tied to the Mega's GND.
- **Hall sensor:** an A3144 (or any 3-pin digital hall switch) on the altimeter's back plate, its output to the listed pin, plus 5 V and GND. A 3 × 2 mm magnet goes in the centre wheel. At start-up MobiFlight turns the hand until the magnet passes the sensor, and that's zero. Before glueing the magnet, set both hands to 0 and put the magnet over the sensor.
- **Airspeed zero:** the X27 has a stop. When MobiFlight resets it, the needle runs back against the stop, and the stop is the face's zero.

Sim variable names change between aircraft and versions, so check them in MobiFlight's variable list first.

## Pin maps

The tables below are generated by `make_pinmaps.py`. Any free pin works; these are just a tidy starting point.

