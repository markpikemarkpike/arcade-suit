// Magic mode: the M5Stack joins Wi-Fi, serves one web page, and runs whatever Lua game that page sends.
// The phone's browser talks to Claude. This board never sees the API key and never does TLS.
#pragma once
#include <WiFi.h>
#include <WebServer.h>
#include "esp_partition.h"
#include "luagame.h"
#include "page.h"
#include "config.h"

SET_LOOP_TASK_STACK_SIZE(16 * 1024);  // The Lua compiler needs more stack than the 8 KB default.

static const char* AP_NAME = SETUP_NETWORK_NAME;
static char apPass[9] = "";  // Made up on first use, kept in flash, shown on the M5Stack's screen. No two suits share one.
static const size_t MAX_SCRIPT = 7000;

LuaGame lua;
WebServer server(80);
enum NetState { NET_OFF, NET_JOINING, NET_STA, NET_AP };
NetState net = NET_OFF;
String wifiSsid, wifiPass;
uint32_t netAt = 0, busyUntil = 0, oopsUntil = 0, frameAt = 0, lcdMagicAt = 0;
char lastErr[120] = "";
bool magicActive = false, lcdDirty = true, joinPending = false, serverUp = false;
int lastStations = -1;
bool wifiParked = false;   // True while Wi-Fi rests so that a lost controller can reconnect.
bool lean = false;         // True while Wi-Fi is switched off to give a big game more memory.
bool pendingLean = false;  // A game arrived that does not fit next to Wi-Fi. Start it once the reply has gone out.

// ---------------------------------------------------------------- small helpers
int32_t since(uint32_t t) { return (int32_t)(millis() - t); }  // Milliseconds since t. Never wraps to a huge number.
unsigned freeKB() { return (unsigned)(heap_caps_get_free_size(MALLOC_CAP_8BIT) / 1024); }
void ledText(Screen& s, const char* t, int x, int y, uint32_t c) {
  for (; *t; t++, x += 4) {
    int ch = *t;
    if (ch >= 'a' && ch <= 'z') ch -= 32;
    if (ch < 32 || ch > 90) ch = '?';
    uint16_t f = LG_FONT[ch - 32];
    for (int j = 0; j < 5; j++) for (int i = 0; i < 3; i++) if (f & (1 << (14 - (j * 3 + i)))) s.set(x + i, y + j, c);
  }
}
uint32_t wheel(int h) {  // 0..255 rainbow
  h &= 255;
  if (h < 85) return rgb(255 - h * 3, h * 3, 0);
  if (h < 170) { h -= 85; return rgb(0, 255 - h * 3, h * 3); }
  h -= 170;
  return rgb(h * 3, 0, 255 - h * 3);
}
String jsonEscape(const char* t) {
  String o;
  for (; *t; t++) {
    char c = *t;
    if (c == '"' || c == '\\') { o += '\\'; o += c; }
    else if ((uint8_t)c < 32) o += ' ';
    else o += c;
  }
  return o;
}
const char* magicState() {
  if (lua.running()) return "playing";
  if (busyUntil) return "busy";
  if (lastErr[0]) return "error";
  return "idle";
}
String magicUrl() {
  return String("http://") + (net == NET_STA ? WiFi.localIP().toString() : WiFi.softAPIP().toString()) + "/";
}

// ---------------------------------------------------------------- storage
// The last good game lives in the first 8 KB of the spare flash partition: 4 bytes "JARC" (a made-up tag), 4 bytes length, then the text.
// No file system, so it costs no memory. Lua compiles straight out of memory-mapped flash.
const esp_partition_t* gamePart() {
  static const esp_partition_t* p = esp_partition_find_first(ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_SPIFFS, nullptr);
  return p;
}
int savedCache = -1;  // Length of the saved game, or -1 for "not looked yet".
void saveGame(const char* code, size_t len) {
  const esp_partition_t* p = gamePart();
  if (!p || len > MAX_SCRIPT) return;
  uint32_t head[2] = {0x4352414A, (uint32_t)len};
  savedCache = -1;
  if (esp_partition_erase_range(p, 0, 8192) != ESP_OK) return;
  esp_partition_write(p, 8, code, len);
  esp_partition_write(p, 0, head, 8);  // Written last, so a power cut never leaves a half game marked as good.
}
size_t savedLen() {
  if (savedCache >= 0) return savedCache;
  const esp_partition_t* p = gamePart();
  uint32_t head[2] = {0, 0};
  if (!p || esp_partition_read(p, 0, head, 8) != ESP_OK) return 0;
  savedCache = (head[0] == 0x4352414A && head[1] > 0 && head[1] <= MAX_SCRIPT) ? head[1] : 0;
  return savedCache;
}
bool loadSavedGame() {
  size_t n = savedLen();
  if (!n) return false;
  const void* ptr = nullptr;
  spi_flash_mmap_handle_t h;
  if (esp_partition_mmap(gamePart(), 0, 8192, SPI_FLASH_MMAP_DATA, &ptr, &h) != ESP_OK) return false;
  bool ok = lua.load((const char*)ptr + 8, n, &game.s, esp_random());
  spi_flash_munmap(h);
  if (!ok) snprintf(lastErr, sizeof(lastErr), "%s", lua.err);
  return ok;
}

// ---------------------------------------------------------------- Wi-Fi
// Networks to try, in order: the saved name, then the same name with the other kind of apostrophe, because
// "Sam's iPhone" is really spelled with a curly one. It never tries a network you did not name.
struct Candidate { String ssid, pass; };
Candidate cand[4];
int nCand = 0, iCand = 0;

void btSearch(bool on) {
  static int8_t now = -1;
  if (now == (on ? 1 : 0)) return;
  now = on ? 1 : 0;
  BP32.enableNewBluetoothConnections(on);
}
void makeApPass() {
  if (apPass[0]) return;
  Preferences w;
  w.begin("wifi", false);
  String p = w.getString("setup", "");
  if (p.length() != 8) {
    static const char A[] = "abcdefghjkmnpqrstuvwxyz23456789";  // No 0, o, 1, l or i: it may have to be typed by hand.
    p = "";
    for (int i = 0; i < 8; i++) p += A[esp_random() % (sizeof(A) - 1)];
    w.putString("setup", p);
  }
  w.end();
  strlcpy(apPass, p.c_str(), sizeof(apPass));
}
void netAp() {
  makeApPass();
  WiFi.setAutoReconnect(false);
  WiFi.disconnect(false, false);
  WiFi.mode(WIFI_AP_STA);  // The idle station side lets the settings page scan for networks.
  WiFi.softAP(AP_NAME, apPass);
  net = NET_AP;
  netAt = millis();
  lcdDirty = true;
}
void netSleep();
void netTry() {
  if (iCand >= nCand) {
    if (lua.running() || game.mode != Arcade::MAGIC) { netSleep(); return; }  // Nobody is waiting for the phone. Free the radio.
    if (wifiSsid.length() && nCand) iCand = 0;                                // Keep looking for the hotspot we know.
    else { netAp(); return; }
  }
  WiFi.disconnect(false, false);
  WiFi.begin(cand[iCand].ssid.c_str(), cand[iCand].pass.c_str());
  net = NET_JOINING;
  netAt = millis();
  lcdDirty = true;
}
void netJoin() {
  btSearch(false);
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  nCand = iCand = 0;
  if (wifiSsid.length()) {
    cand[nCand++] = {wifiSsid, wifiPass};
    String alt = wifiSsid;
    if (alt.indexOf('\'') >= 0) alt.replace("'", "\xE2\x80\x99");
    else alt.replace("\xE2\x80\x99", "'");
    if (alt != wifiSsid) cand[nCand++] = {alt, wifiPass};
  }
  netTry();  // With no name to try, this starts the suit's own setup network.
}

void netStart();
// Switches Wi-Fi off. That frees roughly 45 KB for a game that needs it. SELECT on the controller brings Wi-Fi back.
void netSleep() {
  WiFi.setAutoReconnect(false);
  WiFi.disconnect(true, false);
  WiFi.mode(WIFI_OFF);
  net = NET_OFF;
  lean = true;
  lcdDirty = true;
}
bool outOfMemory(const char* e) { return strstr(e, "not enough memory") != nullptr; }
// Runs the saved game. If it does not fit next to Wi-Fi, tries once more with Wi-Fi off.
bool runSaved() {
  lastErr[0] = 0;
  bool ok = loadSavedGame();
  if (!ok && net != NET_OFF && outOfMemory(lastErr)) {
    netSleep();
    lastErr[0] = 0;
    ok = loadSavedGame();
    if (!ok) netStart();
  }
  lcdDirty = true;
  return ok;
}

void handleRoot() {
  server.sendHeader("Cache-Control", "no-store");
  server.send_P(200, "text/html; charset=utf-8", PAGE_HTML);
}
void handleStatus() {
  char b[600];
  snprintf(b, sizeof(b),
           "{\"state\":\"%s\",\"error\":\"%s\",\"frames\":%lu,\"heap\":%u,\"minheap\":%u,\"block\":%u,\"lua\":%u,\"spill\":%u,\"worst\":%ld,\"pad\":%d,\"net\":\"%s\",\"version\":\"v1.0\"}",
           magicState(), jsonEscape(lastErr).c_str(), (unsigned long)lua.frame, (unsigned)heap_caps_get_free_size(MALLOC_CAP_8BIT),
           (unsigned)heap_caps_get_minimum_free_size(MALLOC_CAP_8BIT), (unsigned)heap_caps_get_largest_free_block(MALLOC_CAP_8BIT),
           (unsigned)lua.peak, (unsigned)lua.spillPeak, lua.worst, (pad && pad->isConnected()) ? 1 : 0, net == NET_STA ? "hotspot" : "own");
  server.sendHeader("Cache-Control", "no-store");
  server.send(200, "application/json", b);
}
void handleBusy() {
  lua.close();  // Frees memory before the new game arrives.
  lastErr[0] = 0;
  busyUntil = millis() + 150000;
  oopsUntil = 0;
  game.mode = Arcade::MAGIC;
  lcdDirty = true;
  server.send(200, "text/plain", "ok");
}
void handleIdle() {  // The page gave up. Go back to the saved game or the waiting screen.
  busyUntil = 0;
  lcdDirty = true;
  server.send(200, "text/plain", "ok");
}
// The page sends the program as a file upload, so it arrives in small pieces. They are collected in the
// ESP32's spare 8 KB of RTC memory, which costs nothing from the main heap.
RTC_NOINIT_ATTR char upBuf[MAX_SCRIPT];
size_t upLen = 0;
bool upBad = false;
void handleGameUpload() {
  HTTPUpload& u = server.upload();
  if (u.status == UPLOAD_FILE_START) {
    lua.close();
    upLen = 0;
    upBad = false;
  } else if (u.status == UPLOAD_FILE_WRITE) {
    if (upBad || upLen + u.currentSize > MAX_SCRIPT) upBad = true;
    else { memcpy(upBuf + upLen, u.buf, u.currentSize); upLen += u.currentSize; }
  } else if (u.status == UPLOAD_FILE_ABORTED) {
    upLen = 0;
  }
}
void handleGame() {
  busyUntil = 0;
  lcdDirty = true;
  game.mode = Arcade::MAGIC;
  magicActive = true;
  lastErr[0] = 0;
  oopsUntil = 0;
  if (upBad) snprintf(lastErr, sizeof(lastErr), "the program is too long, keep it under 6000 characters");
  else if (!upLen) snprintf(lastErr, sizeof(lastErr), "empty program");
  else if (!lua.load(upBuf, upLen, &game.s, esp_random())) snprintf(lastErr, sizeof(lastErr), "%s", lua.err);
  if (outOfMemory(lastErr)) {  // Too big to share memory with Wi-Fi. Say ok, then magicLoop restarts it with Wi-Fi off.
    lastErr[0] = 0;
    pendingLean = true;
    server.send(200, "text/plain", "ok");
    return;
  }
  if (lastErr[0]) {
    oopsUntil = millis() + 2500;
    server.send(400, "text/plain", lastErr);
  } else {
    server.send(200, "text/plain", "ok");
    saveGame(upBuf, upLen);
  }
  upLen = 0;
  upBad = false;
  frameAt = millis();
}
void handleCode() {
  size_t n = savedLen();
  if (!n) { server.send(404, "text/plain", ""); return; }
  const void* ptr = nullptr;
  spi_flash_mmap_handle_t h;
  if (esp_partition_mmap(gamePart(), 0, 8192, SPI_FLASH_MMAP_DATA, &ptr, &h) != ESP_OK) { server.send(404, "text/plain", ""); return; }
  server.setContentLength(n);
  server.send(200, "text/plain", "");
  server.sendContent((const char*)ptr + 8, n);
  spi_flash_munmap(h);
}
void handleScreen() {  // What the LEDs show right now: 1024 pixels, row by row, 4 bytes each (blue, green, red, 0).
  server.sendHeader("Cache-Control", "no-store");
  server.setContentLength(sizeof(game.s.px));
  server.send(200, "application/octet-stream", "");
  server.sendContent((const char*)game.s.px, sizeof(game.s.px));
}
void handleScan() {
  int n = WiFi.scanNetworks();
  String o = "[";
  for (int i = 0; i < n && i < 15; i++) {
    if (WiFi.SSID(i).length() == 0) continue;
    if (o.length() > 1) o += ',';
    o += '"'; o += jsonEscape(WiFi.SSID(i).c_str()); o += '"';
  }
  o += ']';
  WiFi.scanDelete();
  server.send(200, "application/json", o);
}
void handleWifi() {
  String s = server.arg("ssid"), p = server.arg("pass");
  if (s.length() == 0 || s.length() > 32 || p.length() > 63) { server.send(400, "text/plain", "bad name or password"); return; }
  wifiSsid = s; wifiPass = p;
  Preferences w;
  w.begin("arcadewifi");
  w.putString("ssid", s);
  w.putString("pass", p);
  w.end();
  server.send(200, "text/plain", "ok");
  joinPending = true;
  netAt = millis();
}

void netStart() {
  if (net != NET_OFF) return;
  lean = false;
  Preferences w;
  w.begin("arcadewifi", true);
  wifiSsid = w.getString("ssid", HOTSPOT_NAME);  // Flashing at 0x0 wipes the saved name. A name set in config.h survives a reinstall.
  wifiPass = w.getString("pass", HOTSPOT_PASS);
  w.end();
  WiFi.persistent(false);
  WiFi.setHostname("arcade");
  netJoin();
  if (!serverUp) {
    server.on("/", HTTP_GET, handleRoot);
    server.on("/status", HTTP_GET, handleStatus);
    server.on("/busy", HTTP_POST, handleBusy);
    server.on("/idle", HTTP_POST, handleIdle);
    server.on("/game", HTTP_POST, handleGame, handleGameUpload);
    server.on("/code", HTTP_GET, handleCode);
    server.on("/screen", HTTP_GET, handleScreen);
    server.on("/scan", HTTP_GET, handleScan);
    server.on("/wifi", HTTP_POST, handleWifi);
    server.onNotFound([]() { server.send(404, "text/plain", ""); });
    serverUp = true;
  }
  server.begin();  // Closes and reopens the listening socket, so it is fresh after Wi-Fi was off.
}
void netPoll() {
  static uint32_t lostAt = 0;
  if (joinPending && since(netAt) > 600) { joinPending = false; netJoin(); }
  if (net == NET_JOINING) {
    if (WiFi.status() == WL_CONNECTED) {
      net = NET_STA;
      lostAt = 0;
      lcdDirty = true;
      if (cand[iCand].ssid != wifiSsid || cand[iCand].pass != wifiPass) {  // Remember what worked.
        wifiSsid = cand[iCand].ssid; wifiPass = cand[iCand].pass;
        Preferences w;
        w.begin("arcadewifi");
        w.putString("ssid", wifiSsid);
        w.putString("pass", wifiPass);
        w.end();
      }
    } else if (since(netAt) > 12000) {
      iCand++;
      netTry();
    }
  } else if (net == NET_STA) {
    if (WiFi.status() == WL_CONNECTED) lostAt = 0;
    else if (!lostAt) lostAt = millis() | 1;
    else if (since(lostAt) > 4000) {  // The phone went out of range or the hotspot went to sleep.
      lostAt = 0;
      if (lua.running()) netSleep();  // Keep playing in peace. SELECT looks for the phone again.
      else netJoin();
    }
  } else if (net == NET_AP) {
    int n = WiFi.softAPgetStationNum();
    if (n != lastStations) { lastStations = n; lcdDirty = true; }
    // Nobody is using the setup network, so look for the hotspot again. Only from the waiting screen: the search freezes the LEDs for 3 s.
    if (n == 0 && since(netAt) > 45000 && game.mode == Arcade::MAGIC && !lua.running()) netJoin();
  }
  if (net != NET_OFF) server.handleClient();
}

// ---------------------------------------------------------------- M5Stack screen
void lcdMagic() {
  auto& d = M5.Display;
  d.fillScreen(TFT_BLACK);
  d.setTextSize(2);
  d.setCursor(8, 6);
  d.setTextColor(TFT_YELLOW, TFT_BLACK);
  d.println("Magic mode  v1.0");
  d.setTextColor(TFT_WHITE, TFT_BLACK);
  if (net == NET_OFF) {
    d.setCursor(8, 50);
    d.println(wifiParked ? "Controller is off." : "Wi-Fi is resting while");
    d.setCursor(8, 72);
    d.println(wifiParked ? "Press START on it." : "this game plays.");
    d.setCursor(8, 110);
    d.println(wifiParked ? "" : "Press SELECT on the");
    d.setCursor(8, 132);
    d.println(wifiParked ? "" : "controller to wake it.");
  } else if (net == NET_JOINING) {
    d.setCursor(8, 40);
    d.println("Joining Wi-Fi:");
    d.setCursor(8, 62);
    d.println(cand[iCand < nCand ? iCand : 0].ssid.substring(0, 24));
    d.setTextSize(1);
    d.setCursor(8, 100);
    d.println("On the iPhone open Settings > Personal Hotspot");
    d.setCursor(8, 114);
    d.println("and stay on that screen. Maximize Compatibility ON.");
    d.setCursor(8, 140);
    d.println("Wrong network? Controller off, hold the right button 3 s.");
  } else if (net == NET_STA) {
    d.qrcode(magicUrl().c_str(), 8, 30, 170, 3);
    d.setCursor(188, 40);  d.println("Scan with");
    d.setCursor(188, 60);  d.println("the iPhone");
    d.setCursor(188, 80);  d.println("camera");
    d.setTextSize(1);
    d.setCursor(188, 120); d.println("or type in Safari:");
    d.setCursor(188, 134); d.println(WiFi.localIP().toString());
  } else if (net == NET_AP) {
    bool joined = WiFi.softAPgetStationNum() > 0;
    String q = joined ? magicUrl() : String("WIFI:T:WPA;S:") + AP_NAME + ";P:" + apPass + ";;";
    d.qrcode(q.c_str(), 8, 30, 170, 3);
    d.setCursor(188, 34);  d.println(joined ? "Step 2" : "Step 1");
    d.setTextSize(1);
    if (!joined) {
      d.setCursor(188, 62);  d.println("Scan to join my Wi-Fi");
      d.setCursor(188, 80);  d.printf("Name: %s", AP_NAME);
      d.setCursor(188, 94);  d.printf("Pass: %s", apPass);
    } else {
      d.setCursor(188, 62);  d.println("Scan to open the page");
      d.setCursor(188, 80);  d.println("or type in Safari:");
      d.setCursor(188, 94);  d.println("192.168.4.1");
    }
  }
  d.setTextSize(1);
  d.setCursor(8, 208);
  d.printf("State: %s   Pad: %s   Free: %u KB", magicState(), (pad && pad->isConnected()) ? "ON" : "off", freeKB());
  d.setCursor(8, 222);
  d.setTextColor(TFT_RED, TFT_BLACK);
  d.print(String(lastErr).substring(0, 50));
  d.setTextColor(TFT_WHITE, TFT_BLACK);
  d.setTextSize(2);
}

// ---------------------------------------------------------------- LED screens while no game is running
void drawWaiting(Screen& s, uint32_t now) {
  s.clear();
  int t = now / 40;
  if (oopsUntil && (int32_t)(oopsUntil - now) > 0) {
    for (int i = 0; i < 12; i++) { s.rect(10 + i, 4 + i, 2, 2, rgb(255, 0, 30)); s.rect(21 - i, 4 + i, 2, 2, rgb(255, 0, 30)); }
    ledText(s, "OOPS", 8, 22, rgb(255, 255, 255));
    return;
  }
  if (wifiParked) {
    ledText(s, "PRESS", 6, 8, rgb(255, 220, 0));
    ledText(s, "START", 6, 16, rgb(255, 255, 255));
    return;
  }
  if (busyUntil) {  // Building: rainbow bricks stack up.
    int n = (t / 2) % 56;
    for (int i = 0; i < n && i < 48; i++) s.rect((i % 8) * 4, 19 - (i / 8) * 4, 3, 3, wheel(i * 9 + t * 2));
    ledText(s, "MAKING", 4, 25, rgb(255, 255, 255));
    return;
  }
  if (net == NET_JOINING) {
    int k = (t / 8) % 4;
    s.rect(15, 16, 2, 2, rgb(0, 120, 255));
    for (int r = 1; r <= k; r++) for (int x = -r * 3; x <= r * 3; x++) { int y = 15 - r * 3 + (x * x) / (r * 4); s.set(15 + x, y, rgb(0, 120, 255)); s.set(16 + x, y, rgb(0, 120, 255)); }
    ledText(s, "WIFI", 8, 24, rgb(255, 255, 255));
    return;
  }
  // Ready: twinkling stars and an invitation.
  for (int i = 0; i < 14; i++) {
    int x = (i * 37 + 5) % 32, y = (i * 23 + 3) % 17, ph = (t + i * 11) % 60;
    if (ph < 30) s.set(x, y, wheel(i * 18 + t));
    if (ph > 8 && ph < 22) { s.set(x + 1, y, wheel(i * 18 + t)); s.set(x - 1, y, wheel(i * 18 + t)); s.set(x, y + 1, wheel(i * 18 + t)); s.set(x, y - 1, wheel(i * 18 + t)); }
  }
  ledText(s, net == NET_AP ? "SET UP" : "ASK ME", 4, 19, wheel(t * 2));
  ledText(s, net == NET_AP ? "WIFI" : savedLen() ? "A=PLAY" : "4 GAME", net == NET_AP ? 8 : 4, 26, rgb(255, 255, 255));
}

// ---------------------------------------------------------------- called from loop()
void magicLeave() {
  lua.close();
  magicActive = false;
  busyUntil = 0;
  oopsUntil = 0;
  pendingLean = false;
  netStart();  // In case Wi-Fi was resting for a big game.
}
// SELECT or START while a made-up game runs: stop it and listen for a new one. Returns false if there was nothing to stop.
bool magicStopGame() {
  if (!lua.running()) return false;
  lua.close();
  netStart();
  lcdDirty = true;
  return true;
}
void magicLoop(uint32_t now, uint8_t inputs) {
  static uint8_t prevInputs = 0;
  uint8_t pressed = inputs & ~prevInputs;
  prevInputs = inputs;
  if (!magicActive) {  // Just picked from the menu.
    magicActive = true;
    lcdDirty = true;
    pressed = 0;
    Screen& s = game.s;
    s.clear();
    ledText(s, "MAGIC", 6, 13, rgb(255, 220, 0));
    show(s);
    netStart();
    frameAt = millis();
  }
  if (pendingLean) {
    pendingLean = false;
    delay(200);  // Let the "ok" reach the phone first.
    netSleep();
    if (lua.load(upBuf, upLen, &game.s, esp_random())) saveGame(upBuf, upLen);
    else {
      snprintf(lastErr, sizeof(lastErr), "%s", lua.err);
      oopsUntil = millis() + 2500;
      netStart();
    }
    upLen = 0;
    frameAt = millis();
  }
  if (busyUntil && (int32_t)(now - busyUntil) > 0) { busyUntil = 0; lcdDirty = true; }
  if (!lua.running()) {
    // Escape hatch to redo the Wi-Fi setup. Only without a controller: in the fanny pack the buttons get squeezed.
    if (M5.BtnC.pressedFor(3000) && net != NET_AP && !(pad && pad->isConnected())) netAp();
    if (pressed & (BTN_A | BTN_B)) {
      if (net == NET_AP) { if (since(netAt) > 3000 && WiFi.softAPgetStationNum() == 0) netJoin(); }  // Look for the hotspot again now.
      else if (!busyUntil && savedLen()) { if (!runSaved()) oopsUntil = millis() + 2500; }           // Play the last game again.
    }
  }

  if (lua.running() && !lua.step(inputs)) {
    snprintf(lastErr, sizeof(lastErr), "%s", lua.err);
    lcdDirty = true;
    bool again = false;
    if (net != NET_OFF && outOfMemory(lastErr)) {  // It ran out of room next to Wi-Fi. Start it again with Wi-Fi off.
      netSleep();
      again = runSaved();
    }
    if (!again) {
      oopsUntil = millis() + 2500;
      netStart();  // Wi-Fi back on, so the phone can read the error and ask for a fix.
    }
  }
  if (!lua.running()) drawWaiting(game.s, now);
  show(game.s);  // Takes about 31 ms.
  int32_t spare = (int32_t)(frameAt + 1000 / LuaGame::FPS - millis());
  if (spare > 0 && spare < 50) delay(spare);
  frameAt = millis();

  if (lcdDirty || now - lcdMagicAt > 5000) {
    if (lcdDirty || !lua.running()) lcdMagic();
    lcdDirty = false;
    lcdMagicAt = now;
  }
}
