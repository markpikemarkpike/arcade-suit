// Arcade Suit for the M5Stack Basic v2.7
// Runs a maze game and a falling-block game on four 16x16 WS2812B panels (32x32 total).
// Panel data wire: pin 17 or pin 2 (the same signal also comes out of 16, 5 and 26,
// so being one pin off still works). Panel ground: the end pin marked G.
// Controller: 8BitDo Zero 2 through Bluepad32. M5Stack buttons also work.
//
// Buttons on the M5Stack during play: A = left, B = action, C = right.
// Hold A and C for 2 seconds on the menu to open panel setup.

#include <Bluepad32.h>
#include <FastLED.h>
#include <M5Unified.h>
#include <Preferences.h>
#include "soc/gpio_sig_map.h"
#include "games.h"

// ---- Settings you may want to change ----
const int LED_PIN = 26;
const uint8_t EXTRA_PINS[] = {16, 17, 2, 5};  // Copies of the LED signal.
const uint8_t BRIGHTNESS = 20;     // 0 to 255. Keep this low.
const int MAX_MILLIAMPS = 1000;    // FastLED dims the panels to stay under this. Idle LED current (up to ~1 A for 1024 LEDs) comes on top.
// -----------------------------------------

CRGB leds[1024];
ControllerPtr pad = nullptr;
Arcade game;
Preferences prefs;
uint8_t rotation[4] = {2, 2, 0, 0};  // Quarter turns for each panel. Top row has its solder pads at the bottom, bottom row at the top.
bool rowsZigzag = false;             // false = wiring zigzags by columns.
// Where each panel sits, seen from the FRONT. Layout 0 is the one in the guide:
// front 2 1 / 3 4, which is 1 2 / 4 3 seen from the back.
const uint8_t LAYOUTS[4][2][2] = {
  {{1, 0}, {2, 3}}, {{0, 1}, {3, 2}}, {{2, 3}, {1, 0}}, {{3, 2}, {0, 1}}};
uint8_t layout = 0;
// Quarter turns of the WHOLE picture. 1 = the square is worn a quarter turn clockwise (seen from the front)
// from the guide layout, so Panel 1 and its wires sit at the bottom right.
uint8_t turn = 1;

uint16_t ledIndex(int x, int y) {
  for (int i = 0; i < turn; i++) { int t = x; x = y; y = 31 - t; }
  int p = LAYOUTS[layout][y / 16][x / 16];
  int u = x % 16, v = y % 16;
  for (int i = 0; i < rotation[p]; i++) { int t = u; u = 15 - v; v = t; }
  int major = rowsZigzag ? v : u;
  int minor = rowsZigzag ? u : v;
  return p * 256 + major * 16 + ((major & 1) ? 15 - minor : minor);
}

void show(Screen& s) {
  for (int y = 0; y < 32; y++)
    for (int x = 0; x < 32; x++) leds[ledIndex(x, y)] = CRGB(s.px[y][x]);
  FastLED.show();
}

void onConnected(ControllerPtr c) { if (!pad) pad = c; }
void onDisconnected(ControllerPtr c) { if (pad == c) pad = nullptr; }

bool M5Buttons = true;
uint8_t readInputs() {
  uint8_t held = 0;
  if (pad && pad->isConnected()) {
    uint8_t d = pad->dpad();
    if (d & DPAD_LEFT || pad->axisX() < -300) held |= BTN_LEFT;
    if (d & DPAD_RIGHT || pad->axisX() > 300) held |= BTN_RIGHT;
    if (d & DPAD_UP || pad->axisY() < -300) held |= BTN_UP;
    if (d & DPAD_DOWN || pad->axisY() > 300) held |= BTN_DOWN;
    if (pad->a() || pad->x()) held |= BTN_A;
    if (pad->b() || pad->y()) held |= BTN_B;
  }
  if (M5Buttons) {
    if (M5.BtnA.isPressed()) held |= BTN_LEFT;
    if (M5.BtnC.isPressed()) held |= BTN_RIGHT;
    if (M5.BtnB.isPressed()) held |= BTN_A;
  }
  return held;
}

void lcdStatus(const char* line) {
  M5.Display.fillScreen(TFT_BLACK);
  M5.Display.setCursor(8, 8);
  M5.Display.setTextSize(2);
  M5.Display.println("Arcade Suit v1.0");
  M5.Display.println();
  M5.Display.println(line);
}

#include "magic.h"

void lightCheck() {
  static const CRGB C[4] = {CRGB::Red, CRGB::Green, CRGB::Blue, CRGB::White};
  static const char* N[4] = {"Panel 1 = RED", "Panel 2 = GREEN", "Panel 3 = BLUE", "Panel 4 = WHITE"};
  for (int p = 0; p < 4; p++) {
    lcdStatus(N[p]);
    fill_solid(leds + p * 256, 256, C[p]);
    FastLED.show();
    delay(1500);
  }
  FastLED.clear(true);
}

// One big picture across all four panels. It only looks right when every
// panel is in the right place and turned the right way.
void drawSetup(Screen& s, int cur) {
  s.clear();
  s.rect(0, 0, 32, 1, rgb(255, 255, 255)); s.rect(0, 31, 32, 1, rgb(255, 255, 255));
  s.rect(0, 0, 1, 32, rgb(255, 255, 255)); s.rect(31, 0, 1, 32, rgb(255, 255, 255));
  s.rect(12, 12, 8, 8, rgb(40, 255, 40));
  s.rect(2, 2, 3, 3, rgb(255, 40, 40));
  for (int qy = 0; qy < 2; qy++)
    for (int qx = 0; qx < 2; qx++) {
      int p = ledIndex(qx * 16 + 8, qy * 16 + 8) / 256;
      s.digit(qx * 16 + 6, qy * 16 + 5, p + 1, p == cur ? rgb(255, 255, 255) : rgb(255, 170, 0));
    }
}

void panelSetup() {
  int cur = 0;
  uint32_t holdA = 0, holdB = 0, holdC = 0;
  lcdStatus("Panel setup\nHold A: TURN ALL\nA next panel\nB turn panel\nC zigzag type\nHold C: move panels\nHold B: save");
  while (true) {
    M5.update();
    uint32_t now = millis();
    if (M5.BtnA.wasPressed()) holdA = now;
    if (M5.BtnA.wasReleased() && holdA) { cur = (cur + 1) % 4; holdA = 0; }
    if (M5.BtnA.isPressed() && holdA && now - holdA > 1500) { turn = (turn + 1) % 4; holdA = 0; }
    if (M5.BtnB.wasPressed()) holdB = now;
    if (M5.BtnB.wasReleased() && holdB) { rotation[cur] = (rotation[cur] + 1) % 4; holdB = 0; }
    if (M5.BtnC.wasPressed()) holdC = now;
    if (M5.BtnC.wasReleased() && holdC) { rowsZigzag = !rowsZigzag; holdC = 0; }
    if (M5.BtnC.isPressed() && holdC && now - holdC > 1500) { layout = (layout + 1) % 4; holdC = 0; }
    if (M5.BtnB.isPressed() && holdB && now - holdB > 1500) break;
    Screen s;
    drawSetup(s, cur);
    show(s);
    delay(30);
  }
  prefs.putBytes("rot", rotation, 4);
  prefs.putBool("rows", rowsZigzag);
  prefs.putUChar("lay", layout);
  prefs.putUChar("turn", turn);
  FastLED.clear(true);
  lcdStatus("Saved");
  delay(800);
}

void setup() {
  lua.reserve();  // First thing, while the heap is still in one piece.
  auto cfg = M5.config();
  M5.begin(cfg);
  M5.Speaker.end();
  prefs.begin("arcade32");
  prefs.getBytes("rot", rotation, 4);
  rowsZigzag = prefs.getBool("rows", false);
  layout = prefs.getUChar("lay", 0) % 4;
  turn = prefs.getUChar("turn", 1) % 4;

  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, 1024);
  FastLED.setBrightness(BRIGHTNESS);
  FastLED.setMaxPowerInVoltsAndMilliamps(5, MAX_MILLIAMPS);
  FastLED.clear(true);
  // Copy the LED signal (RMT channel 0) onto the neighbouring pins.
  for (uint8_t p : EXTRA_PINS) {
    pinMode(p, OUTPUT);
    pinMatrixOutAttach(p, RMT_SIG_OUT0_IDX, false, false);
  }

  lightCheck();

  BP32.setup(&onConnected, &onDisconnected);
  BP32.enableNewBluetoothConnections(true);
  lcdStatus("Turn on controller\nor use buttons");
}

void loop() {
  static uint32_t bothHeld = 0, lcdAt = 0;
  static bool wasPad = false;
  M5.update();
  BP32.update();

  uint32_t now = millis();
  // With a controller connected, the M5Stack's own buttons are ignored everywhere: it rides in a fanny pack and gets squeezed.
  if (game.mode == Arcade::MENU && !(pad && pad->isConnected()) && M5.BtnA.isPressed() && M5.BtnC.isPressed()) {
    if (!bothHeld) bothHeld = now;
    if (now - bothHeld > 2000) { panelSetup(); bothHeld = 0; }
  } else {
    bothHeld = 0;
  }

  bool hasPad = pad && pad->isConnected();
  // Select on the controller leaves any game and goes back to the main menu. (Not Start: that button wakes the controller.)
  static bool menuHeld = false;
  bool menuBtn = hasPad ? pad->miscSelect()
                        : (game.mode == Arcade::MAGIC && M5.BtnB.pressedFor(2000));  // No controller: hold the middle button.
  if (menuBtn && !menuHeld && game.mode != Arcade::MENU) {
    if (game.mode == Arcade::MAGIC) magicLeave();
    game.mode = Arcade::MENU;
    game.idleSince = now;
    game.prev = 0xFF;  // Buttons that are still held down must not pick a menu item.
    lcdAt = 0;
  }
  menuHeld = menuBtn;
  // Wi-Fi crowds out Bluetooth, so a controller that fell asleep cannot reconnect. Rest Wi-Fi until the controller is back.
  static uint32_t padLostAt = 0;
  static bool seenPad = false;
  if (hasPad) {
    seenPad = true;
    padLostAt = 0;
    if (wifiParked) {
      wifiParked = false;
      lcdDirty = true;
      if (!lua.running()) netStart();  // A running game may have taken the freed memory. Select brings Wi-Fi back later.
    }
  } else if (net != NET_OFF && seenPad) {
    if (!padLostAt) padLostAt = now | 1;
    else if (now - padLostAt > 2000) { netSleep(); wifiParked = true; }
  }
  if (net != NET_OFF) netPoll();
  // Searching for new controllers hogs the radio. Only search while none is connected, and never while joining Wi-Fi.
  btSearch(!hasPad && net != NET_JOINING);
  if (game.mode == Arcade::MAGIC) {
    // With a controller connected, ignore the M5Stack's own buttons: it rides in a fanny pack and gets squeezed.
    M5Buttons = !hasPad;
    uint8_t in = readInputs();
    M5Buttons = true;
    magicLoop(now, in);
    return;
  }

  M5Buttons = !hasPad;
  game.update(readInputs(), now);
  M5Buttons = true;
  if (game.mode == Arcade::MAGIC) return;  // Picked just now. magicLoop takes over on the next pass.
  show(game.s);

  if (hasPad != wasPad || now - lcdAt > 1000) {
    wasPad = hasPad;
    lcdAt = now;
    char t[140];
    snprintf(t, sizeof(t), "Controller: %s\nBattery: %d%%\n\nYellow wire: 17 or 2\nGrey wire: G\n\nMaze best: %ld\nBlocks best: %ld",
             hasPad ? "ON" : "off", (int)M5.Power.getBatteryLevel(), game.best[0], game.best[1]);
    lcdStatus(t);
  }
}
