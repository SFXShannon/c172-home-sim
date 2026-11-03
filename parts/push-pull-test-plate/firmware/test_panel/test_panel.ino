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
// LEVER CALIBRATION: after flashing, move every lever end to end once. The
// sketch learns each one's range and saves it in EEPROM, so it survives
// unplugging. To start over, set RESET_CALIBRATION = true, upload, then set it
// back to false and upload again.

#include <Joystick.h>
#include <EEPROM.h>

// ---- settings ---------------------------------------------------------------
const bool REVERSE_THROTTLE = false;
const bool REVERSE_MIXTURE  = false;
const bool REVERSE_PROP     = false;
const bool REVERSE_TRIM     = false;  // swap if nose-down/up come out backwards
const bool REVERSE_IGNITION = false;  // true if OFF and START come out swapped
const int  TRIM_STEPS_PER_DETENT = 4; // EC11 trim encoder: usually 4 (try 2 if it skips)
const int  PULSE_MS = 40;             // how long each trim / brake pulse is held
const bool RESET_CALIBRATION = false; // true = forget the learned lever ranges

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
  if (raw < calLo[i] - 3) { calLo[i] = raw; calDirty = true; }
  if (raw > calHi[i] + 3) { calHi[i] = raw; calDirty = true; }
  long v = map(raw, calLo[i] + DEAD, calHi[i] - DEAD, 0, 1023);
  return (int)constrain(v, 0L, 1023L);
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
    Joystick.setButton(trimButton, 0);
    trimButton = -1;
    trimGapUntil = now + PULSE_MS / 2;
  }
  if (trimButton < 0 && trimPending != 0 && now >= trimGapUntil) {
    trimButton = trimPending > 0 ? BTN_TRIM_DN : BTN_TRIM_UP;
    trimPending += trimPending > 0 ? -1 : 1;
    Joystick.setButton(trimButton, 1);
    trimPulseUntil = now + PULSE_MS;
  }
}

// ---- ignition key: one held button per switch position ----------------------
void updateIgnition() {
  for (int i = 0; i < 5; i++) {
    int pin = PIN_IGN[REVERSE_IGNITION ? 4 - i : i];
    Joystick.setButton(BTN_IGN + i, digitalRead(pin) == LOW);
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
  sThr = analogRead(PIN_THROTTLE); sMix = analogRead(PIN_MIXTURE); sProp = analogRead(PIN_PROP);
}

void loop() {
  unsigned long now = millis();

  // ---- levers
  int t = calibrated(0, smooth(PIN_THROTTLE, sThr));
  int m = calibrated(1, smooth(PIN_MIXTURE, sMix));
  int p = calibrated(2, smooth(PIN_PROP, sProp));
  Joystick.setXAxis(REVERSE_THROTTLE ? 1023 - t : t);
  Joystick.setYAxis(REVERSE_MIXTURE  ? 1023 - m : m);
  Joystick.setZAxis(REVERSE_PROP     ? 1023 - p : p);
  // save a grown range once the levers have been still for 2 s (saves EEPROM wear)
  if (calDirty) { calSaveAt = now + 2000; calDirty = false; }
  if (calSaveAt && now > calSaveAt) { saveCalibration(); calSaveAt = 0; }

  // ---- parking brake (held + edge pulses)
  int brake = digitalRead(PIN_BRAKE) == LOW;
  if (lastBrake != -1 && brake != lastBrake) brakePulseUntil[brake ? 0 : 1] = now + PULSE_MS;
  lastBrake = brake;
  Joystick.setButton(BTN_BRAKE, brake);
  Joystick.setButton(BTN_BRAKE_SET, now < brakePulseUntil[0]);
  Joystick.setButton(BTN_BRAKE_REL, now < brakePulseUntil[1]);

  // ---- fuel selector
  for (int i = 0; i < 4; i++) Joystick.setButton(BTN_FUEL + i, digitalRead(PIN_FUEL[i]) == LOW);

  // ---- trim wheel and ignition key
  pollEncoders();
  updateTrim(now);
  updateIgnition();

  Joystick.sendState();
  // keep polling the trim encoder quickly between USB reports
  for (int i = 0; i < 20; i++) { pollEncoders(); delayMicroseconds(100); }
}
