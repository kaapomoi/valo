#include <ArduinoJson.h>
#include <WebServer.h>
#include "FastLED.h"
#include <WiFi.h>
#include "secret.h"

#include <NTPClient.h>
#include <WiFiUdp.h>

#ifndef SSID
#define SSID "NOT_VALID"
#define PASS "NOT_VALID"
#endif

const char* ssid = SSID;
const char* password = PASS;

const uint8_t PROGMEM gamma8[] = {
    0,   0,   0,   0,   0,   0,   0,   0,   1,   1,   1,   1,   1,   1,   1,   2,   2,   2,   2,
    2,   3,   3,   3,   3,   4,   4,   4,   4,   5,   5,   5,   6,   6,   6,   7,   7,   8,   8,
    8,   9,   9,   10,  10,  10,  11,  11,  12,  12,  13,  13,  14,  14,  15,  15,  16,  16,  17,
    17,  18,  18,  19,  19,  20,  21,  21,  22,  22,  23,  24,  24,  25,  26,  26,  27,  28,  28,
    29,  30,  30,  31,  32,  32,  33,  34,  35,  35,  36,  37,  38,  38,  39,  40,  41,  41,  42,
    43,  44,  45,  46,  46,  47,  48,  49,  50,  51,  52,  53,  53,  54,  55,  56,  57,  58,  59,
    60,  61,  62,  63,  64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,
    79,  80,  81,  82,  83,  84,  86,  87,  88,  89,  90,  91,  92,  93,  95,  96,  97,  98,  99,
    100, 102, 103, 104, 105, 107, 108, 109, 110, 111, 113, 114, 115, 116, 118, 119, 120, 122, 123,
    124, 126, 127, 128, 129, 131, 132, 134, 135, 136, 138, 139, 140, 142, 143, 145, 146, 147, 149,
    150, 152, 153, 154, 156, 157, 159, 160, 162, 163, 165, 166, 168, 169, 171, 172, 174, 175, 177,
    178, 180, 181, 183, 184, 186, 188, 189, 191, 192, 194, 195, 197, 199, 200, 202, 204, 205, 207,
    208, 210, 212, 213, 215, 217, 218, 220, 222, 224, 225, 227, 229, 230, 232, 234, 236, 237, 239,
    241, 243, 244, 246, 248, 250, 251, 253, 255};

#define NUM_LEDS 144
CRGB leds[NUM_LEDS];

#define FRAMES_PER_SECOND 100

unsigned long cur_time = 0;
unsigned long prev_time = 0;
unsigned long frame_time = ceil((float)1000 / (float)FRAMES_PER_SECOND);

unsigned long ntp_counter = 0;
unsigned long ntp_threshold = FRAMES_PER_SECOND;

/// Gradient change mode variables
unsigned long gradient_color_index{0};
CRGBPalette256 gradient_palette;

/// Used in basic color modes
CRGB current_color;
CRGB target_color{CRGB::White};
uint8_t current_brightness{255};

/// Wakeup time parameters
uint32_t wakeup_frames_until_update{FRAMES_PER_SECOND * 600 / 255};
uint32_t wakeup_frame_counter{0};

/// Alarm parameters
bool alarm_enabled{true};
uint8_t alarm_hours{6};
uint8_t alarm_minutes{30};

enum class LedMode : uint8_t { off = 0, solid = 1, sparkle = 2, gradient_change = 3, wakeup = 4 };

LedMode led_mode{LedMode::off};

WebServer server(80);

WiFiUDP ntp_udp;
NTPClient ntp_client(ntp_udp, "pool.ntp.org", 10800);

CRGB getColorFromHex(String hex)
{
    long number = (long)strtol(&hex[0], NULL, 16);
    uint8_t red = (number >> 16 & 0xFF);
    uint8_t green = (number >> 8 & 0xFF);
    uint8_t blue = (number & 0xFF);
    return CRGB(red, green, blue);
}

std::vector<uint8_t> getColorBytesFromHex(String hex)
{
    long number = (long)strtol(&hex[0], NULL, 16);
    uint8_t red = (number >> 16 & 0xFF);
    uint8_t green = (number >> 8 & 0xFF);
    uint8_t blue = (number & 0xFF);
    return std::vector<uint8_t>{red, green, blue};
}

/// Returns whether the request has a valid body.
bool checkIncomingRequest()
{
    if (!server.hasArg("plain")) {
        Serial.println("No body in request");
        server.send(400, "text/plain", "No body in request");
        return false;
    }
    return true;
}

StaticJsonDocument<256> parse_request()
{
    StaticJsonDocument<256> doc;

    if (!checkIncomingRequest()) {
        return doc;
    }

    String const message{server.arg("plain")};

    Serial.println("/api/v1/ got message: " + message);

    DeserializationError error = deserializeJson(doc, message);

    if (error) {
        Serial.print(F("deserializeJson() failed: "));
        Serial.println(error.f_str());
    }

    return doc;
}

void handleColorApiV1Basic()
{
    StaticJsonDocument<256> doc = parse_request();

    /// Handle each input individually
    if (doc["color"] != nullptr) {
        String color = doc["color"];
        target_color = getColorFromHex(color);
    }

    if (doc["mode"] != nullptr) {
        int mode = doc["mode"];
        led_mode = LedMode{mode};
    }

    if (doc["brightness"] != nullptr) {
        current_brightness = doc["brightness"];
    }

    server.send(200, "text/plain", "Mode change OK.");
}

void handleColorApiV1Multi()
{
    StaticJsonDocument<256> doc = parse_request();

    if (doc["colors"] != nullptr) {
        JsonArray c = doc["colors"];

        uint8_t color_index{0};
        uint8_t index_per_color{256 / (c.size() - 1)};

        std::vector<uint8_t> colors(c.size(), 0);
        for (JsonVariant color_hex : c) {
            colors.push_back(color_index);
            std::vector<uint8_t> color_bytes{getColorBytesFromHex(color_hex)};

            colors.insert(colors.end(), color_bytes.begin(), color_bytes.end());
            Serial.println("Pushed a color " + String(color_index));
            color_index += index_per_color;
        }

        /// Ensure last index is 255
        static constexpr std::size_t indices_per_color{4};
        colors.at(colors.size() - indices_per_color) = 255;

        gradient_palette.loadDynamicGradientPalette(colors.data());
    }

    if (doc["speed"] != nullptr) {
        int speed = doc["speed"];
    }

    if (doc["brightness"] != nullptr) {
        current_brightness = doc["brightness"];
    }

    led_mode = LedMode::gradient_change;

    server.send(200, "text/plain", "Multi color change OK.");
}

void handleColorApiV1Wakeup()
{
    StaticJsonDocument<256> doc = parse_request();

    /// Handle each input individually
    if (doc["time_seconds"] != nullptr) {
        current_color = CRGB(15, 8, 0);
        target_color = CRGB::White;
        int time_seconds = doc["time_seconds"];
        current_brightness = 255;

        wakeup_frame_counter = 0;
        wakeup_frames_until_update = FRAMES_PER_SECOND * time_seconds / 255;

        led_mode = LedMode::wakeup;
        server.send(200, "text/plain", "Wakeup routine started.");
    }
    else {
        server.send(400, "text/plain", "Bad request. time_seconds not received.");
    }
}

void handleColorApiV1Alarm()
{
    StaticJsonDocument<256> doc = parse_request();

    if (doc["alarm_enabled"] != nullptr) {
        alarm_enabled = doc["alarm_enabled"];
        Serial.println("Alarm enabled:" + alarm_enabled);
    }
    if (doc["alarm_hours"] != nullptr) {
        alarm_hours = doc["alarm_hours"];
        Serial.println("Alarm hours:" + alarm_hours);
    }
    if (doc["alarm_minutes"] != nullptr) {
        alarm_minutes = doc["alarm_minutes"];
        Serial.println("Alarm minutes:" + alarm_minutes);
    }

    server.send(200, "text/plain", "Alarm set.");
}

void setGammaCorrectedLedColor(CRGB& led, CRGB const& color)
{
    led = color;

#if 0
    led.r = pgm_read_byte(&gamma8[color.r]);
    led.g = pgm_read_byte(&gamma8[color.g]);
    led.b = pgm_read_byte(&gamma8[color.b]);
#endif
}

void updateLeds()
{
    static constexpr auto lerp_amount{UINT16_MAX / 10};
    current_color = current_color.lerp16(target_color, lerp_amount);

    switch (led_mode) {
    case LedMode::off: {
        FastLED.clear(true);
        break;
    }
    case LedMode::solid: {
        for (int i = 0; i < NUM_LEDS; i++) {
            setGammaCorrectedLedColor(leds[i], current_color);
        }
        break;
    }
    case LedMode::sparkle: {
        fadeToBlackBy(leds, NUM_LEDS, 10);
        int const pos{random8(NUM_LEDS)};
        setGammaCorrectedLedColor(leds[pos],
                                  current_color + CRGB(random8(32), random8(32), random8(32)));
        break;
    }
    case LedMode::gradient_change: {
        for (int i = 0; i < NUM_LEDS; i++) {
            setGammaCorrectedLedColor(
                leds[i],
                ColorFromPalette(gradient_palette, gradient_color_index, 255, LINEARBLEND));
        }
        gradient_color_index += 1;
        break;
    }
    default: {
        break;
    }
    }

    FastLED.setBrightness(current_brightness);
    FastLED.show();
}

void execute_wakeup()
{
    wakeup_frame_counter++;
    if (wakeup_frame_counter >= wakeup_frames_until_update) {
        wakeup_frame_counter = 0;

        current_color += CRGB(1, 1, 1);
        if (current_color.r < 255) {
            Serial.println("Updating color");

            for (int i = 0; i < NUM_LEDS; i++) {
                setGammaCorrectedLedColor(leds[i], current_color);
            }
        }
        else {
            Serial.println("Current color is target color");
            led_mode = LedMode::solid;
        }

        FastLED.setBrightness(current_brightness);
        FastLED.show();
    }
}

void setup()
{
    const int DATA_PIN = 8;
    const int CLOCK_PIN = 6;

    // second of delay if something goes wrong, idk
    delay(1000);

    Serial.begin(115200);

    // Start wifi networking
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, password);
    Serial.println("");

    // Create LED "strip" object

    FastLED.addLeds<WS2813, DATA_PIN, GRB>(leds, NUM_LEDS);

    FastLED.setBrightness(255);
    FastLED.setDither(0);

    // Wait for connection
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("");
    Serial.print("Connected to ");
    Serial.println(ssid);
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());

    // Initialize server routings
    server.on("/api/v1/ping", HTTP_GET,
              []() { server.send(200, "text/plain", "valo@" + WiFi.localIP().toString()); });
    server.on("/api/v1/basic", HTTP_POST, handleColorApiV1Basic);
    server.on("/api/v1/multi", HTTP_POST, handleColorApiV1Multi);
    server.on("/api/v1/wakeup", HTTP_POST, handleColorApiV1Wakeup);
    server.on("/api/v1/alarm", HTTP_POST, handleColorApiV1Alarm);
    server.onNotFound(
        []() { server.send(404, "text/plain", "404: Not found. Try to POST on /api/v1"); });

    // Start the server
    const char* headerkeys[] = {"User-Agent", "Cookie"};
    size_t headerkeyssize = sizeof(headerkeys) / sizeof(char*);
    // ask server to track these headers
    server.collectHeaders(headerkeys, headerkeyssize);
    server.begin();
    Serial.println("HTTP server started");
    ntp_client.begin();
    prev_time = millis();

    float gamma = 1.8;               // Correction factor
    int max_in = 255, max_out = 255; // Top end of OUTPUT range
    Serial.print("const uint8_t PROGMEM gamma8[] = {");
    for (int i = 0; i <= max_in; i++) {
        if (i > 0)
            Serial.print(',');
        if ((i & 15) == 0)
            Serial.print("\n  ");
        Serial.print((int)(pow((float)i / (float)max_in, gamma) * max_out + 0.5));
    }
    Serial.println(" };");
}

void loop()
{
    server.handleClient();

    if ((millis() - prev_time) >= frame_time) {
        if (ntp_counter++ > ntp_threshold) {
            ntp_counter = 0;
            ntp_client.update();
            Serial.println(ntp_client.getFormattedTime());
        }

        if ((ntp_client.getHours() == alarm_hours) && (ntp_client.getMinutes() == alarm_minutes)
            && (ntp_client.getSeconds() == 0)) {
            Serial.println("Alarm rang, start wakeup.");
            current_color = CRGB(30, 10, 0);
            target_color = CRGB::White;
            current_brightness = 255;
            led_mode = LedMode::wakeup;
        }

        prev_time = millis();
        if (led_mode == LedMode::wakeup) {
            execute_wakeup();
        }
        else {
            // Update LEDs
            updateLeds();
        }
    }
}
