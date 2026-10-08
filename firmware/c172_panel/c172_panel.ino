// C172 home-sim panel -> one USB game controller
//
// Board:   Arduino Pro Micro (ATmega32U4) or Leonardo
// Library: "Joystick" by Matthew Heironimus (ArduinoJoystickLibrary)
//          https://github.com/MHeironimus/ArduinoJoystickLibrary
//
// Shows up in Windows / MSFS as a joystick with 4 axes and 16 buttons:
//
//   X axis  throttle   (slide pot wiper -> A0)
//   Y axis  mixture    (slide pot wiper -> A1)
//   Z axis  prop       (slide pot wiper -> A2, optional)
//   Rx axis flaps      (flap lever slide pot wiper -> A3, optional)
//
//   Button 1   parking brake SET      (held while the handle is out)
//   Button 2   parking brake - pulse when it becomes SET
//   Button 3   parking brake - pulse when it becomes RELEASED
//   Button 4   fuel selector LEFT     (held)
//   Button 5   fuel selector BOTH     (held)
//   Button 6   fuel selector RIGHT    (held)
//   Button 7   fuel selector OFF      (held, only if you built has_off)
//   Button 8   trim NOSE DOWN         (one pulse per click of the wheel)
//   Button 9   trim NOSE UP           (one pulse per click of the wheel)
//
// Wiring: every switch goes between its pin and GND (internal pull-ups are
// used). Pots: ends to VCC and GND, wiper to the analog pin.
//
//   Pin 2  parking brake microswitch (COM -> GND, NC -> pin 2)
//   Pin 3  fuel selector position LEFT   (rotary switch common -> GND)
//   Pin 4  fuel selector position BOTH
//   Pin 5  fuel selector position RIGHT
//   Pin 6  fuel selector position OFF
//   Pin 7  trim encoder A
//   Pin 8  trim encoder B   (encoder C / middle pin -> GND)

#include <Joystick.h>

// ---- settings ---------------------------------------------------------------
const bool HAS_PROP = false;        // true if you built the prop control
const bool HAS_FLAPS = false;       // true if you built the flap lever
const bool REVERSE_THROTTLE = false;
const bool REVERSE_MIXTURE  = false;
const bool REVERSE_PROP     = false;
const bool REVERSE_FLAPS    = false;
const bool REVERSE_TRIM     = false;  // swap if nose-down/up come out backwards
const int  STEPS_PER_DETENT = 4;      // EC11 encoders: usually 4 (try 2 if it skips)
const int  PULSE_MS         = 40;     // how long each trim / brake pulse is held

// ---- pins -------------------------------------------------------------------
const int PIN_THROTTLE = A0, PIN_MIXTURE = A1, PIN_PROP = A2, PIN_FLAPS = A3;
const int PIN_BRAKE = 2;
const int PIN_FUEL[4] = {3, 4, 5, 6};     // LEFT, BOTH, RIGHT, OFF
const int PIN_ENC_A = 7, PIN_ENC_B = 8;

Joystick_ Joystick(JOYSTICK_DEFAULT_REPORT_ID, JOYSTICK_TYPE_JOYSTICK,
                   16, 0,                 // buttons, hat switches
                   true, true, true,      // X, Y, Z
                   true, false, false,    // Rx, Ry, Rz
                   false, false,          // rudder, throttle
                   false, false, false);  // accelerator, brake, steering

// Simple smoothing so the axes don't jitter
int smooth(int pin, float &state) {
  state += (analogRead(pin) - state) * 0.2;
  return (int)(state + 0.5);
}

float sThr = 0, sMix = 0, sProp = 0, sFlap = 0;
int lastBrake = -1;
unsigned long brakePulseUntil[2] = {0, 0};   // [0]=set pulse, [1]=release pulse

// Trim encoder
int encLast = 0, encCount = 0;
int trimPending = 0;                          // + = nose down pulses, - = nose up
unsigned long trimPulseUntil = 0, trimGapUntil = 0;
int trimButton = -1;

const int8_t QDEC[16] = {0, -1, 1, 0, 1, 0, 0, -1, -1, 0, 0, 1, 0, 1, -1, 0};

void readEncoder() {
  int s = (digitalRead(PIN_ENC_A) << 1) | digitalRead(PIN_ENC_B);
  encCount += QDEC[(encLast << 2) | s];
  encLast = s;
  if (encCount >= STEPS_PER_DETENT)  { trimPending += REVERSE_TRIM ? -1 : 1; encCount = 0; }
  if (encCount <= -STEPS_PER_DETENT) { trimPending += REVERSE_TRIM ? 1 : -1; encCount = 0; }
}

void setup() {
  pinMode(PIN_BRAKE, INPUT_PULLUP);
  for (int i = 0; i < 4; i++) pinMode(PIN_FUEL[i], INPUT_PULLUP);
  pinMode(PIN_ENC_A, INPUT_PULLUP);
  pinMode(PIN_ENC_B, INPUT_PULLUP);
  encLast = (digitalRead(PIN_ENC_A) << 1) | digitalRead(PIN_ENC_B);

  Joystick.setXAxisRange(0, 1023);
  Joystick.setYAxisRange(0, 1023);
  Joystick.setZAxisRange(0, 1023);
  Joystick.setRxAxisRange(0, 1023);
  Joystick.begin(false);
  sThr = analogRead(PIN_THROTTLE); sMix = analogRead(PIN_MIXTURE); sProp = analogRead(PIN_PROP); sFlap = analogRead(PIN_FLAPS);
}

void loop() {
  unsigned long now = millis();

  // ---- axes
  int t = smooth(PIN_THROTTLE, sThr);
  int m = smooth(PIN_MIXTURE, sMix);
  int p = HAS_PROP ? smooth(PIN_PROP, sProp) : 1023;
  Joystick.setXAxis(REVERSE_THROTTLE ? 1023 - t : t);
  Joystick.setYAxis(REVERSE_MIXTURE  ? 1023 - m : m);
  Joystick.setZAxis(REVERSE_PROP     ? 1023 - p : p);
  int fl = HAS_FLAPS ? smooth(PIN_FLAPS, sFlap) : 0;
  Joystick.setRxAxis(REVERSE_FLAPS   ? 1023 - fl : fl);

  // ---- parking brake (held + edge pulses)
  int brake = digitalRead(PIN_BRAKE) == LOW;
  if (lastBrake != -1 && brake != lastBrake) brakePulseUntil[brake ? 0 : 1] = now + PULSE_MS;
  lastBrake = brake;
  Joystick.setButton(0, brake);
  Joystick.setButton(1, now < brakePulseUntil[0]);
  Joystick.setButton(2, now < brakePulseUntil[1]);

  // ---- fuel selector
  for (int i = 0; i < 4; i++) Joystick.setButton(3 + i, digitalRead(PIN_FUEL[i]) == LOW);

  // ---- trim wheel: turn each detent into one button pulse
  readEncoder();
  if (trimButton >= 0 && now >= trimPulseUntil) {
    Joystick.setButton(trimButton, 0);
    trimButton = -1;
    trimGapUntil = now + PULSE_MS / 2;
  }
  if (trimButton < 0 && trimPending != 0 && now >= trimGapUntil) {
    trimButton = trimPending > 0 ? 7 : 8;
    trimPending += trimPending > 0 ? -1 : 1;
    Joystick.setButton(trimButton, 1);
    trimPulseUntil = now + PULSE_MS;
  }

  Joystick.sendState();
  // keep polling the encoder quickly between USB reports
  for (int i = 0; i < 20; i++) { readEncoder(); delayMicroseconds(100); }
}
