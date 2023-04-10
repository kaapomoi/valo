#include <ArduinoJson.h>
#include <ESP8266WebServer.h>
#include <ESP8266WiFi.h>
#include <ESP8266mDNS.h>
#include <WiFiClient.h>
#define FASTLED_ESP8266_NODEMCU_PIN_ORDER
#include "FastLED.h"
#include "secret.h"

#ifndef SSID
#define SSID "NOT_VALID"
#define PASS "NOT_VALID"
#endif

const char* ssid = SSID;
const char* password = PASS;

#define NUM_LEDS 60
CRGB leds[NUM_LEDS];

#define FRAMES_PER_SECOND 100

unsigned long cur_time = 0;
unsigned long prev_time = 0;
unsigned long frame_time = ceil((float)1000 / (float)FRAMES_PER_SECOND);

/// Gradient change mode variables
unsigned long gradient_color_index{0};
CRGBPalette256 gradient_palette;

/// Used in basic color modes
CRGB current_color;
CRGB target_color;
std::uint8_t current_brightness;

/// Wakeup time parameters
std::uint32_t wakeup_frames_until_update;
std::uint32_t wakeup_frame_counter;

enum class LedMode : uint8_t { off = 0, solid = 1, sparkle = 2, gradient_change = 3, wakeup = 4 };

LedMode led_mode{LedMode::off};

ESP8266WebServer server(80);

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

StaticJsonDocument<256> parse_request() {
    StaticJsonDocument<256> doc;

    if (!checkIncomingRequest()) {
        return doc;
    }

    String const message{server.arg("plain")};

    Serial.println("/api/v1/basic got message: " + message);

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

void setup(void)
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

    FastLED.addLeds<APA102, DATA_PIN, CLOCK_PIN, BGR>(leds, NUM_LEDS);

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
    server.on("/api/v1/basic", HTTP_POST, handleColorApiV1Basic);
    server.on("/api/v1/multi", HTTP_POST, handleColorApiV1Multi);
    server.on("/api/v1/wakeup", HTTP_POST, handleColorApiV1Wakeup);
    server.onNotFound(
        []() { server.send(404, "text/plain", "404: Not found. Try to POST on /api/v1"); });

    if (MDNS.begin("valo")) {
        Serial.println("MDNS Service started");
    }

    // Start the server
    const char* headerkeys[] = {"User-Agent", "Cookie"};
    size_t headerkeyssize = sizeof(headerkeys) / sizeof(char*);
    // ask server to track these headers
    server.collectHeaders(headerkeys, headerkeyssize);
    server.begin();
    Serial.println("HTTP server started");
    prev_time = millis();
}

void updateLeds()
{
    static constexpr auto lerp_amount{UINT16_MAX / 10};
    current_color = current_color.lerp16(target_color, lerp_amount);

    switch (led_mode) {
    case LedMode::off: {
        break;
    }
    case LedMode::solid: {
        for (int i = 0; i < NUM_LEDS; i++) {
            leds[i] = current_color;
        }
        break;
    }
    case LedMode::sparkle: {
        fadeToBlackBy(leds, NUM_LEDS, 10);
        int pos = random8(NUM_LEDS);
        leds[pos] += current_color + CRGB(random8(32), random8(32), random8(32));
        break;
    }
    case LedMode::gradient_change: {
        for (int i = 0; i < NUM_LEDS; i++) {
            leds[i] = ColorFromPalette(gradient_palette, gradient_color_index, 255, LINEARBLEND);
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
                leds[i] = current_color;
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

void loop(void)
{
    server.handleClient();

    // Caveman impl.
    if (led_mode == LedMode::off) {
        FastLED.clear(true);
    }
    else if ((millis() - prev_time) >= frame_time) {
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
