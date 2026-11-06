// C172 home-sim TEST PANEL -> one USB game controller
//
// Everything on the push-pull test panel, on one Pro Micro:
// throttle, prop, mixture, trim wheel, parking brake, fuel selector and the
// ignition key.
//
// Board:   Arduino Pro Micro (ATmega32U4) or Leonardo.
//          In the Arduino IDE choose "Arduino Leonardo".
// Library: "Joystick" by Matthew Heironimus (ArduinoJoystickLibrary)
//          https://github.com/MHeironimus/ArduinoJoystickLibrary
//
// Shows up in Windows / MSFS as a joystick with 3 axes and 14 buttons.
// Buttons 1-9 are numbered the same as the full-panel sketch in /firmware,
// so bindings carry over.
//
//   X axis  throttle    (slide pot wiper -> A0)
//   Y axis  mixture     (slide pot wiper -> A1)
//   Z axis  prop        (slide pot wiper -> A2)
//
//   Button 1   parking brake SET       (held while the handle is out)
//   Button 2   parking brake - pulse when it becomes SET
//   Button 3   parking brake - pulse when it becomes RELEASED
//   Button 4   fuel selector LEFT      (held)
//   Button 5   fuel selector BOTH      (held)
//   Button 6   fuel selector RIGHT     (held)
//   Button 7   fuel selector OFF       (held)
//   Button 8   trim NOSE DOWN          (one pulse per click of the wheel)
//   Button 9   trim NOSE UP            (one pulse per click of the wheel)
//   Button 10  ignition OFF            (held while the key is at OFF)
//   Button 11  ignition R              (held)
//   Button 12  ignition L              (held)
//   Button 13  ignition BOTH           (held)
//   Button 14  ignition START          (held)
//
// Pins (every switch goes between its pin and GND; internal pull-ups are used):
//
//   A0  throttle pot wiper        A1  mixture pot wiper     A2  prop pot wiper
//   2   parking brake microswitch (COM -> GND, NC -> pin 2)
//   3 / 4 / 5 / 6   fuel selector LEFT / BOTH / RIGHT / OFF (common -> GND)
//   7 / 8   trim encoder A / B      (encoder middle pin -> GND)
//   9 / 10 / 14 / 15 / 16   ignition switch positions OFF / R / L / BOTH / START
//                            (rotary switch common -> GND)
//   Pot ends go to VCC and GND.
//
// IGNITION KEY: a 1-pole 12-position rotary switch (RS26 type) with its stop
// washer set to 5 positions. Wire its common to GND and positions 1-5 to the
// five pins above, in order, so position 1 (fully anticlockwise) is OFF.
// If they come out backwards, set REVERSE_IGNITION = true instead of rewiring.
// While the switch is between two positions no ignition button is held.
//
// SETUP APP: tools/test-panel-app (C172 Test Panel.exe) talks to this sketch
// over the Pro Micro's USB serial port. It shows every input live, checks the
// wiring pin by pin, calibrates the levers and changes the settings below
// without re-uploading. Settings saved from the app live in EEPROM and
// override the defaults below; "Defaults" in the app goes back to them.
//
// LEVER CALIBRATION: after flashing, move every lever end to end once. The
// sketch learns each one's range and saves it in EEPROM, so it survives
// unplugging. To start over, set RESET_CALIBRATION = true, upload, then set it
// back to false and upload again.

#include <Joystick.h>
#include <EEPROM.h>

// ---- settings (defaults - the setup app can change these and save them) ----
const bool DEF_REVERSE_THROTTLE = false;
const bool DEF_REVERSE_MIXTURE  = false;
const bool DEF_REVERSE_PROP     = false;
const bool DEF_REVERSE_TRIM     = false;  // swap if nose-down/up come out backwards
const bool DEF_REVERSE_IGNITION = false;  // true if OFF and START come out swapped
const int  DEF_TRIM_STEPS_PER_DETENT = 4; // EC11 trim encoder: usually 4 (try 2 if it skips)
const int  DEF_PULSE_MS = 40;             // how long each trim / brake pulse is held
const bool RESET_CALIBRATION = false;     // true = forget the learned lever ranges and saved settings
// Fuel selector stand-in: an ON-OFF-ON toggle instead of the rotary selector.
// Wire one pole: centre pin -> GND, the outer pins -> pins 3 (LEFT) and 5 (RIGHT).
// With this true, the toggle's centre (off) position reads as BOTH. No OFF position.
const bool DEF_FUEL_TOGGLE = false;
const bool DEF_AUTO_CAL = true;           // ranges grow on their own as the levers move

const char FW_VERSION[] = "2";

// the live settings (loaded from EEPROM in setup)
bool REVERSE_THROTTLE, REVERSE_MIXTURE, REVERSE_PROP, REVERSE_TRIM, REVERSE_IGNITION;
bool FUEL_TOGGLE, AUTO_CAL;
int  TRIM_STEPS_PER_DETENT, PULSE_MS;

// ---- pins -------------------------------------------------------------------
const int PIN_THROTTLE = A0, PIN_MIXTURE = A1, PIN_PROP = A2;
const int PIN_BRAKE = 2;
const int PIN_FUEL[4] = {3, 4, 5, 6};     // LEFT, BOTH, RIGHT, OFF
const int PIN_TRIM_A = 7, PIN_TRIM_B = 8;
const int PIN_IGN[5] = {9, 10, 14, 15, 16};   // OFF, R, L, BOTH, START

// ---- button numbers (0-based here; Windows shows them +1) -------------------
const int BTN_BRAKE = 0, BTN_BRAKE_SET = 1, BTN_BRAKE_REL = 2;
const int BTN_FUEL = 3;                   // 3..6
const int BTN_TRIM_DN = 7, BTN_TRIM_UP = 8;
const int BTN_IGN = 9;                    // 9..13 = OFF, R, L, BOTH, START

Joystick_ Joystick(JOYSTICK_DEFAULT_REPORT_ID, JOYSTICK_TYPE_JOYSTICK,
                   14, 0,                 // buttons, hat switches
                   true, true, true,      // X, Y, Z
                   false, false, false,   // Rx, Ry, Rz
                   false, false,          // rudder, throttle
                   false, false, false);  // accelerator, brake, steering

// ---- axes: smoothing + self-calibration ------------------------------------
int smooth(int pin, float &state) {
  state += (analogRead(pin) - state) * 0.2;
  return (int)(state + 0.5);
}

const int CAL_ADDR = 0, CAL_MAGIC = 0x172D;   // different from the full-panel sketch
const int DEAD = 6;                 // small dead zone at each end so 0 % / 100 % are easy to hit
int calLo[3], calHi[3];
bool calDirty = false;
unsigned long calSaveAt = 0;

void loadCalibration() {
  int magic;
  EEPROM.get(CAL_ADDR, magic);
  if (magic == CAL_MAGIC && !RESET_CALIBRATION) {
    EEPROM.get(CAL_ADDR + 2, calLo);
    EEPROM.get(CAL_ADDR + 2 + sizeof(calLo), calHi);
  } else {
    for (int i = 0; i < 3; i++) { calLo[i] = 450; calHi[i] = 570; }   // grows as you move the levers
  }
}
void saveCalibration() {
  EEPROM.put(CAL_ADDR, CAL_MAGIC);
  EEPROM.put(CAL_ADDR + 2, calLo);
  EEPROM.put(CAL_ADDR + 2 + sizeof(calLo), calHi);
}
int calibrated(int i, int raw) {
  if (AUTO_CAL) {
    if (raw < calLo[i] - 3) { calLo[i] = raw; calDirty = true; }
    if (raw > calHi[i] + 3) { calHi[i] = raw; calDirty = true; }
  }
  int lo = calLo[i] + DEAD, hi = calHi[i] - DEAD;
  if (hi <= lo) hi = lo + 1;
  long v = map(raw, lo, hi, 0, 1023);
  return (int)constrain(v, 0L, 1023L);
}


// ---- saved settings (separate EEPROM block from the lever ranges) ----------
const int SET_ADDR = 32, SET_MAGIC = 0x172E;
struct Saved { int magic; uint8_t flags, trimSteps, pulseMs, spare; };
enum { F_REV_THR = 1, F_REV_MIX = 2, F_REV_PROP = 4, F_REV_TRIM = 8, F_REV_IGN = 16,
       F_FUEL_TOGGLE = 32, F_AUTO_CAL = 64 };

void defaultSettings() {
  REVERSE_THROTTLE = DEF_REVERSE_THROTTLE; REVERSE_MIXTURE = DEF_REVERSE_MIXTURE;
  REVERSE_PROP = DEF_REVERSE_PROP; REVERSE_TRIM = DEF_REVERSE_TRIM;
  REVERSE_IGNITION = DEF_REVERSE_IGNITION; FUEL_TOGGLE = DEF_FUEL_TOGGLE;
  AUTO_CAL = DEF_AUTO_CAL;
  TRIM_STEPS_PER_DETENT = DEF_TRIM_STEPS_PER_DETENT; PULSE_MS = DEF_PULSE_MS;
}
void loadSettings() {
  defaultSettings();
  Saved sv;
  EEPROM.get(SET_ADDR, sv);
  if (sv.magic != SET_MAGIC || RESET_CALIBRATION) return;
  REVERSE_THROTTLE = sv.flags & F_REV_THR;  REVERSE_MIXTURE = sv.flags & F_REV_MIX;
  REVERSE_PROP = sv.flags & F_REV_PROP;     REVERSE_TRIM = sv.flags & F_REV_TRIM;
  REVERSE_IGNITION = sv.flags & F_REV_IGN;  FUEL_TOGGLE = sv.flags & F_FUEL_TOGGLE;
  AUTO_CAL = sv.flags & F_AUTO_CAL;
  TRIM_STEPS_PER_DETENT = constrain(sv.trimSteps, 1, 8);
  PULSE_MS = constrain(sv.pulseMs, 10, 250);
}
void saveSettings() {
  Saved sv;
  sv.magic = SET_MAGIC;
  sv.flags = (REVERSE_THROTTLE ? F_REV_THR : 0) | (REVERSE_MIXTURE ? F_REV_MIX : 0) |
             (REVERSE_PROP ? F_REV_PROP : 0) | (REVERSE_TRIM ? F_REV_TRIM : 0) |
             (REVERSE_IGNITION ? F_REV_IGN : 0) | (FUEL_TOGGLE ? F_FUEL_TOGGLE : 0) |
             (AUTO_CAL ? F_AUTO_CAL : 0);
  sv.trimSteps = TRIM_STEPS_PER_DETENT; sv.pulseMs = PULSE_MS; sv.spare = 0;
  EEPROM.put(SET_ADDR, sv);
}

// ---- serial link to the setup app -------------------------------------------
// One command per line. Replies are one line each.
//   HELLO            -> C172TP,<version>
//   GET              -> CFG,revThr,revMix,revProp,revTrim,revIgn,fuelToggle,autoCal,
//                           trimSteps,pulseMs,lo0,hi0,lo1,hi1,lo2,hi2
//   SET <name> <n>   -> OK / ERR   (takes effect now; SAVE keeps it after unplugging)
//      names: REV_THR REV_MIX REV_PROP REV_TRIM REV_IGN FUEL_TOGGLE AUTO_CAL
//             TRIM_STEPS PULSE_MS LO0 HI0 LO1 HI1 LO2 HI2
//   SAVE             -> OK   (settings and lever ranges to EEPROM)
//   LOAD             -> OK   (throw away unsaved changes: reload what's in EEPROM)
//   DEFAULTS         -> OK   (back to the defaults at the top of this sketch; not saved)
//   STREAM 1 / 0     -> OK   (live data on/off)
// Live data, about 25 times a second while streaming:
//   D,raw0,raw1,raw2,out0,out1,out2,buttons,pins,trim
//   raw = smoothed analogRead, out = axis value sent (0-1023, after reversing),
//   buttons = hex bit mask of buttons 1-14, pins = hex mask of switch pins
//   pulled LOW (bit 0 pin 2, bits 1-4 pins 3-6, bits 5-6 pins 7-8,
//   bits 7-11 pins 9,10,14,15,16), trim = running count of trim clicks (+ = nose down).
bool streaming = false;
unsigned long nextStream = 0;
char cmd[40];
int cmdLen = 0;
long trimCount = 0;
uint16_t buttonMask = 0;

void sendLine(const char *line) {
  // Serial.dtr() rather than "if (Serial)", which costs a 10 ms delay on the 32U4
  if (Serial.dtr() && Serial.availableForWrite() >= (int)strlen(line) + 2) Serial.println(line);
}

bool setValue(const char *name, long v) {
  if      (!strcmp(name, "REV_THR"))     REVERSE_THROTTLE = v;
  else if (!strcmp(name, "REV_MIX"))     REVERSE_MIXTURE = v;
  else if (!strcmp(name, "REV_PROP"))    REVERSE_PROP = v;
  else if (!strcmp(name, "REV_TRIM"))    REVERSE_TRIM = v;
  else if (!strcmp(name, "REV_IGN"))     REVERSE_IGNITION = v;
  else if (!strcmp(name, "FUEL_TOGGLE")) FUEL_TOGGLE = v;
  else if (!strcmp(name, "AUTO_CAL"))    AUTO_CAL = v;
  else if (!strcmp(name, "TRIM_STEPS"))  TRIM_STEPS_PER_DETENT = constrain(v, 1, 8);
  else if (!strcmp(name, "PULSE_MS"))    PULSE_MS = constrain(v, 10, 250);
  else if ((name[0] == 'L' && name[1] == 'O') || (name[0] == 'H' && name[1] == 'I')) {
    int i = name[2] - '0';
    if (i < 0 || i > 2 || name[3]) return false;
    v = constrain(v, 0L, 1023L);
    if (name[0] == 'L') calLo[i] = v; else calHi[i] = v;
  }
  else return false;
  return true;
}

void runCommand(char *c) {
  for (char *p = c; *p; p++) *p = toupper(*p);
  char buf[96];
  if (!strcmp(c, "HELLO")) {
    snprintf(buf, sizeof buf, "C172TP,%s", FW_VERSION); sendLine(buf);
  } else if (!strcmp(c, "GET")) {
    snprintf(buf, sizeof buf, "CFG,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
             REVERSE_THROTTLE, REVERSE_MIXTURE, REVERSE_PROP, REVERSE_TRIM, REVERSE_IGNITION,
             FUEL_TOGGLE, AUTO_CAL, TRIM_STEPS_PER_DETENT, PULSE_MS,
             calLo[0], calHi[0], calLo[1], calHi[1], calLo[2], calHi[2]);
    sendLine(buf);
  } else if (!strncmp(c, "SET ", 4)) {
    char *name = c + 4, *val = strchr(name, ' ');
    if (val) { *val++ = 0; sendLine(setValue(name, atol(val)) ? "OK" : "ERR"); }
    else sendLine("ERR");
  } else if (!strcmp(c, "SAVE")) {
    saveSettings(); saveCalibration(); sendLine("OK");
  } else if (!strcmp(c, "LOAD")) {
    loadSettings(); loadCalibration(); sendLine("OK");
  } else if (!strcmp(c, "DEFAULTS")) {
    defaultSettings(); sendLine("OK");
  } else if (!strncmp(c, "STREAM ", 7)) {
    streaming = c[7] == '1'; sendLine("OK");
  } else if (c[0]) {
    sendLine("ERR");
  }
}

void pollSerial() {
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\n' || ch == '\r') { cmd[cmdLen] = 0; runCommand(cmd); cmdLen = 0; }
    else if (cmdLen < (int)sizeof(cmd) - 1) cmd[cmdLen++] = ch;
  }
  if (!Serial.dtr()) streaming = false;   // app closed the port
}

uint16_t pinMask() {
  const int pins[12] = {2, 3, 4, 5, 6, 7, 8, 9, 10, 14, 15, 16};
  uint16_t m = 0;
  for (int i = 0; i < 12; i++) if (digitalRead(pins[i]) == LOW) m |= 1 << i;
  return m;
}

void setButton(int b, bool on) {
  Joystick.setButton(b, on);
  if (on) buttonMask |= 1 << b; else buttonMask &= ~(1 << b);
}

float sThr = 0, sMix = 0, sProp = 0;

// ---- trim encoder (quadrature) ----------------------------------------------
const int8_t QDEC[16] = {0, -1, 1, 0, 1, 0, 0, -1, -1, 0, 0, 1, 0, 1, -1, 0};

struct Encoder {
  int pinA, pinB, last, steps;
  void begin() {
    pinMode(pinA, INPUT_PULLUP);
    pinMode(pinB, INPUT_PULLUP);
    last = (digitalRead(pinA) << 1) | digitalRead(pinB);
    steps = 0;
  }
  void poll() {
    int s = (digitalRead(pinA) << 1) | digitalRead(pinB);
    steps += QDEC[(last << 2) | s];
    last = s;
  }
};

Encoder trimEnc = {PIN_TRIM_A, PIN_TRIM_B, 0, 0};

void pollEncoders() { trimEnc.poll(); }

// ---- parking brake ----------------------------------------------------------
int lastBrake = -1;
unsigned long brakePulseUntil[2] = {0, 0};   // [0] = set pulse, [1] = release pulse

// ---- trim wheel: each click becomes one button pulse ------------------------
int trimPending = 0;                         // + = nose down pulses, - = nose up
unsigned long trimPulseUntil = 0, trimGapUntil = 0;
int trimButton = -1;

void updateTrim(unsigned long now) {
  while (trimEnc.steps >= TRIM_STEPS_PER_DETENT)  { trimPending += REVERSE_TRIM ? -1 : 1; trimEnc.steps -= TRIM_STEPS_PER_DETENT; }
  while (trimEnc.steps <= -TRIM_STEPS_PER_DETENT) { trimPending += REVERSE_TRIM ? 1 : -1; trimEnc.steps += TRIM_STEPS_PER_DETENT; }

  if (trimButton >= 0 && now >= trimPulseUntil) {
    setButton(trimButton, 0);
    trimButton = -1;
    trimGapUntil = now + PULSE_MS / 2;
  }
  if (trimButton < 0 && trimPending != 0 && now >= trimGapUntil) {
    trimButton = trimPending > 0 ? BTN_TRIM_DN : BTN_TRIM_UP;
    trimCount += trimPending > 0 ? 1 : -1;
    trimPending += trimPending > 0 ? -1 : 1;
    setButton(trimButton, 1);
    trimPulseUntil = now + PULSE_MS;
  }
}

// ---- ignition key: one held button per switch position ----------------------
void updateIgnition() {
  for (int i = 0; i < 5; i++) {
    int pin = PIN_IGN[REVERSE_IGNITION ? 4 - i : i];
    setButton(BTN_IGN + i, digitalRead(pin) == LOW);
  }
}

// ---- setup / loop -----------------------------------------------------------
void setup() {
  pinMode(PIN_BRAKE, INPUT_PULLUP);
  for (int i = 0; i < 4; i++) pinMode(PIN_FUEL[i], INPUT_PULLUP);
  for (int i = 0; i < 5; i++) pinMode(PIN_IGN[i], INPUT_PULLUP);
  trimEnc.begin();

  Joystick.setXAxisRange(0, 1023);
  Joystick.setYAxisRange(0, 1023);
  Joystick.setZAxisRange(0, 1023);
  Joystick.begin(false);
  loadCalibration();
  loadSettings();
  Serial.begin(115200);
  sThr = analogRead(PIN_THROTTLE); sMix = analogRead(PIN_MIXTURE); sProp = analogRead(PIN_PROP);
}

void loop() {
  unsigned long now = millis();

  // ---- levers
  int raw[3] = {smooth(PIN_THROTTLE, sThr), smooth(PIN_MIXTURE, sMix), smooth(PIN_PROP, sProp)};
  int t = calibrated(0, raw[0]);
  int m = calibrated(1, raw[1]);
  int p = calibrated(2, raw[2]);
  int out[3] = {REVERSE_THROTTLE ? 1023 - t : t, REVERSE_MIXTURE ? 1023 - m : m, REVERSE_PROP ? 1023 - p : p};
  Joystick.setXAxis(out[0]);
  Joystick.setYAxis(out[1]);
  Joystick.setZAxis(out[2]);
  // save a grown range once the levers have been still for 2 s (saves EEPROM wear)
  if (calDirty) { calSaveAt = now + 2000; calDirty = false; }
  if (calSaveAt && now > calSaveAt) { saveCalibration(); calSaveAt = 0; }

  // ---- parking brake (held + edge pulses)
  int brake = digitalRead(PIN_BRAKE) == LOW;
  if (lastBrake != -1 && brake != lastBrake) brakePulseUntil[brake ? 0 : 1] = now + PULSE_MS;
  lastBrake = brake;
  setButton(BTN_BRAKE, brake);
  setButton(BTN_BRAKE_SET, now < brakePulseUntil[0]);
  setButton(BTN_BRAKE_REL, now < brakePulseUntil[1]);

  // ---- fuel selector
  bool fuel[4];
  for (int i = 0; i < 4; i++) fuel[i] = digitalRead(PIN_FUEL[i]) == LOW;
  if (FUEL_TOGGLE) { fuel[1] = !fuel[0] && !fuel[2]; fuel[3] = false; }   // centre = BOTH
  for (int i = 0; i < 4; i++) setButton(BTN_FUEL + i, fuel[i]);

  // ---- trim wheel and ignition key
  pollEncoders();
  updateTrim(now);
  updateIgnition();

  Joystick.sendState();

  // ---- setup app link
  pollSerial();
  if (streaming && now >= nextStream) {
    nextStream = now + 40;
    char buf[64];
    snprintf(buf, sizeof buf, "D,%d,%d,%d,%d,%d,%d,%X,%X,%ld",
             raw[0], raw[1], raw[2], out[0], out[1], out[2], buttonMask, pinMask(), trimCount);
    sendLine(buf);
  }
  // keep polling the trim encoder quickly between USB reports
  for (int i = 0; i < 20; i++) { pollEncoders(); delayMicroseconds(100); }
}
