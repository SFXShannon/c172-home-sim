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


## Board 1: PFD bezel

One Arduino Mega 2560 behind the PFD. 32 keys + 9 knobs (5 of them dual).

64 pins used of 67.

| Input | Type | Mega pin(s) |
|---|---|---|
| PFD NAV VOL (turn) | Encoder | D2 (A), D3 (B) |
| PFD NAV VOL push (ID) | Button / switch | D4 |
| PFD NAV outer knob | Encoder | D5 (A), D6 (B) |
| PFD NAV inner knob | Encoder | D7 (A), D8 (B) |
| PFD NAV flip key | Button / switch | D9 |
| PFD HDG knob | Encoder | D10 (A), D11 (B) |
| PFD HDG push (sync) | Button / switch | D12 |
| PFD ALT outer knob | Encoder | D14 (A), D15 (B) |
| PFD ALT inner knob | Encoder | D16 (A), D17 (B) |
| PFD COM VOL (turn) | Encoder | D18 (A), D19 (B) |
| PFD COM VOL push (squelch) | Button / switch | D20 |
| PFD COM outer knob | Encoder | D21 (A), D22 (B) |
| PFD COM inner knob | Encoder | D23 (A), D24 (B) |
| PFD COM flip key | Button / switch | D25 |
| PFD CRS knob (inner) | Encoder | D26 (A), D27 (B) |
| PFD BARO knob (outer) | Encoder | D28 (A), D29 (B) |
| PFD RANGE knob | Encoder | D30 (A), D31 (B) |
| PFD RANGE push (pan) | Button / switch | D32 |
| PFD FMS outer knob | Encoder | D33 (A), D34 (B) |
| PFD FMS inner knob | Encoder | D35 (A), D36 (B) |
| PFD softkey 1 | Button / switch | D37 |
| PFD softkey 2 | Button / switch | D38 |
| PFD softkey 3 | Button / switch | D39 |
| PFD softkey 4 | Button / switch | D40 |
| PFD softkey 5 | Button / switch | D41 |
| PFD softkey 6 | Button / switch | D42 |
| PFD softkey 7 | Button / switch | D43 |
| PFD softkey 8 | Button / switch | D44 |
| PFD softkey 9 | Button / switch | D45 |
| PFD softkey 10 | Button / switch | D46 |
| PFD softkey 11 | Button / switch | D47 |
| PFD softkey 12 | Button / switch | D48 |
| PFD AP | Button / switch | D49 |
| PFD FD | Button / switch | D50 |
| PFD HDG | Button / switch | D51 |
| PFD ALT | Button / switch | D52 |
| PFD NAV | Button / switch | D53 |
| PFD VNV | Button / switch | A0 |
| PFD APR | Button / switch | A1 |
| PFD BC | Button / switch | A2 |
| PFD VS | Button / switch | A3 |
| PFD NOSE UP | Button / switch | A4 |
| PFD FLC | Button / switch | A5 |
| PFD NOSE DN | Button / switch | A6 |
| PFD DIRECT-TO | Button / switch | A7 |
| PFD MENU | Button / switch | A8 |
| PFD FPL | Button / switch | A9 |
| PFD PROC | Button / switch | A10 |
| PFD CLR | Button / switch | A11 |
| PFD ENT | Button / switch | A12 |

## Board 2: MFD bezel

Identical to board 1, for the MFD. Name it differently in MobiFlight (e.g. "MFD").

64 pins used of 67.

| Input | Type | Mega pin(s) |
|---|---|---|
| MFD NAV VOL (turn) | Encoder | D2 (A), D3 (B) |
| MFD NAV VOL push (ID) | Button / switch | D4 |
| MFD NAV outer knob | Encoder | D5 (A), D6 (B) |
| MFD NAV inner knob | Encoder | D7 (A), D8 (B) |
| MFD NAV flip key | Button / switch | D9 |
| MFD HDG knob | Encoder | D10 (A), D11 (B) |
| MFD HDG push (sync) | Button / switch | D12 |
| MFD ALT outer knob | Encoder | D14 (A), D15 (B) |
| MFD ALT inner knob | Encoder | D16 (A), D17 (B) |
| MFD COM VOL (turn) | Encoder | D18 (A), D19 (B) |
| MFD COM VOL push (squelch) | Button / switch | D20 |
| MFD COM outer knob | Encoder | D21 (A), D22 (B) |
| MFD COM inner knob | Encoder | D23 (A), D24 (B) |
| MFD COM flip key | Button / switch | D25 |
| MFD CRS knob (inner) | Encoder | D26 (A), D27 (B) |
| MFD BARO knob (outer) | Encoder | D28 (A), D29 (B) |
| MFD RANGE knob | Encoder | D30 (A), D31 (B) |
| MFD RANGE push (pan) | Button / switch | D32 |
| MFD FMS outer knob | Encoder | D33 (A), D34 (B) |
| MFD FMS inner knob | Encoder | D35 (A), D36 (B) |
| MFD softkey 1 | Button / switch | D37 |
| MFD softkey 2 | Button / switch | D38 |
| MFD softkey 3 | Button / switch | D39 |
| MFD softkey 4 | Button / switch | D40 |
| MFD softkey 5 | Button / switch | D41 |
| MFD softkey 6 | Button / switch | D42 |
| MFD softkey 7 | Button / switch | D43 |
| MFD softkey 8 | Button / switch | D44 |
| MFD softkey 9 | Button / switch | D45 |
| MFD softkey 10 | Button / switch | D46 |
| MFD softkey 11 | Button / switch | D47 |
| MFD softkey 12 | Button / switch | D48 |
| MFD AP | Button / switch | D49 |
| MFD FD | Button / switch | D50 |
| MFD HDG | Button / switch | D51 |
| MFD ALT | Button / switch | D52 |
| MFD NAV | Button / switch | D53 |
| MFD VNV | Button / switch | A0 |
| MFD APR | Button / switch | A1 |
| MFD BC | Button / switch | A2 |
| MFD VS | Button / switch | A3 |
| MFD NOSE UP | Button / switch | A4 |
| MFD FLC | Button / switch | A5 |
| MFD NOSE DN | Button / switch | A6 |
| MFD DIRECT-TO | Button / switch | A7 |
| MFD MENU | Button / switch | A8 |
| MFD FPL | Button / switch | A9 |
| MFD PROC | Button / switch | A10 |
| MFD CLR | Button / switch | A11 |
| MFD ENT | Button / switch | A12 |

## Board 3: audio panel, switch panels, ignition, standby gauges

One Mega for everything else. The four dimmer pots go to A12-A15 as MobiFlight analog inputs (pin numbers shown above stop before them).

59 pins used of 67.

| Input | Type | Mega pin(s) |
|---|---|---|
| GMA COM1 MIC | Button / switch | D2 |
| GMA COM1 | Button / switch | D3 |
| GMA COM2 MIC | Button / switch | D4 |
| GMA COM2 | Button / switch | D5 |
| GMA COM3 MIC | Button / switch | D6 |
| GMA COM3 | Button / switch | D7 |
| GMA COM1/2 | Button / switch | D8 |
| GMA TEL | Button / switch | D9 |
| GMA PA | Button / switch | D10 |
| GMA SPKR | Button / switch | D11 |
| GMA MKR/MUTE | Button / switch | D12 |
| GMA HI SENS | Button / switch | D14 |
| GMA DME | Button / switch | D15 |
| GMA NAV1 | Button / switch | D16 |
| GMA ADF | Button / switch | D17 |
| GMA NAV2 | Button / switch | D18 |
| GMA AUX | Button / switch | D19 |
| GMA MAN SQ | Button / switch | D20 |
| GMA PLAY | Button / switch | D21 |
| GMA PILOT | Button / switch | D22 |
| GMA COPLT | Button / switch | D23 |
| GMA knob outer | Encoder | D24 (A), D25 (B) |
| GMA knob inner | Encoder | D26 (A), D27 (B) |
| GMA DISPLAY BACKUP | Button / switch | D28 |
| STBY BATT ON | Button / switch | D29 |
| STBY BATT TEST | Button / switch | D30 |
| STBY BATT test light | LED output | D31 |
| MASTER ALT | Button / switch | D32 |
| MASTER BAT | Button / switch | D33 |
| AVIONICS BUS 1 | Button / switch | D34 |
| AVIONICS BUS 2 | Button / switch | D35 |
| BEACON light | Button / switch | D36 |
| LAND light | Button / switch | D37 |
| TAXI light | Button / switch | D38 |
| NAV light | Button / switch | D39 |
| STROBE light | Button / switch | D40 |
| FUEL PUMP | Button / switch | D41 |
| PITOT HEAT | Button / switch | D42 |
| CABIN PWR 12V | Button / switch | D43 |
| Ignition OFF | Button / switch | D44 |
| Ignition R | Button / switch | D45 |
| Ignition L | Button / switch | D46 |
| Ignition BOTH | Button / switch | D47 |
| Ignition START | Button / switch | D48 |
| Standby airspeed (X27.168) | Stepper | D49 (1), D50 (2), D51 (3), D52 (4) |
| Standby altimeter (28BYJ-48 via ULN2003 IN1-IN4) | Stepper | D53 (1), A0 (2), A1 (3), A2 (4) |
| Standby altimeter zero (hall sensor) | Stepper zero (homing) input | A3 |
| Standby altimeter baro knob | Encoder | A4 (A), A5 (B) |
| Standby attitude roll servo | Servo | A6 |
| Standby attitude pitch servo | Servo | A7 |
