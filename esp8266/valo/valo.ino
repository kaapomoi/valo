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

const double max_brightness = 256 * 3 - 1;
const double min_brightness = 80;

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
std::uint8_t target_brightness;

enum class LedMode : uint8_t { off = 0, solid = 1, sparkle = 2, gradient_change = 3 };

LedMode led_mode{LedMode::off};

ESP8266WebServer server(80);

void handleRoot()
{

    // Create a webpage
    static String content;
    content.reserve(8192);

    content += "<!DOCTYPE HTML><html><title>HOME-OHJAIN</title>";

    // Really lightweight impl. of bootstrap
    content += "<head> <meta charset='utf-8'> <meta name='viewport' "
               "content='width=device-width, initial-scale=1, shrink-to-fit=no'> "
               "<style>.h-0{height:0}.btn-green{background-color:#DDD;padding:4%!"
               "important}.btn-green:hover{background-color:#FFF}.btn{border-"
               "radius:0px!important}#randomButton{background-color:#151515;"
               "background-position:center "
               "20%;background-size:contain;background-repeat:no-repeat;opacity:"
               "65%}#randomButton:hover{opacity:85%}#sparkleButton{background:"
               "url(http://eero.dclabra.fi/~ttv18skaapom/"
               "II_stars.png);background-color:#aaa;background-position:center;"
               "background-size:contain;background-repeat:no-repeat;opacity:65%}#"
               "sparkleButton:hover{opacity:85%}.row-3rd{height:33.3333vh}.row-"
               "6th{height:16.666666vh}.m-v-c{margin-top:auto;margin-bottom:auto}"
               ".o-0{opacity:0%}.o-25{opacity:25%}.o-50{opacity:50%}.o-75{"
               "opacity:75%}.o-100{opacity:100%}";
    content += ".w-100{width:100%!important}.btn{display:inline-block;font-weight:400;"
               "text-align:center;white-space:nowrap;vertical-align:middle;-webkit-user-"
               "select:none;-moz-user-select:none;-ms-user-select:none;user-select:none;"
               "border:1px solid transparent;padding:.375rem "
               ".75rem;font-size:1rem;line-height:1.5;border-radius:.25rem;transition:"
               "color .15s ease-in-out,background-color .15s ease-in-out,border-color "
               ".15s ease-in-out,box-shadow .15s "
               "ease-in-out}.m-0{margin:0!important}.p-0{padding:0!important}.h-100{"
               "height:100%!important}.text-center{text-align:center!important}.justify-"
               "content-center{-webkit-box-pack:center!important;-ms-flex-pack:center!"
               "important;justify-content:center!important}.d-flex{display:-webkit-box!"
               "important;display:-ms-flexbox!important;display:flex!important}.col{-ms-"
               "flex-preferred-size:0;flex-basis:0;-webkit-box-flex:1;-ms-flex-positive:"
               "1;flex-grow:1;max-width:100%}.container-fluid{width:100%;padding-right:"
               "15px;padding-left:15px;margin-right:auto;margin-left:auto}.row{display:-"
               "webkit-box;display:-ms-flexbox;display:flex;-ms-flex-wrap:wrap;flex-"
               "wrap:wrap;margin-right:-15px;margin-left:-15px}</style></head>";

    content += "<body id='bground' style='background: #71777b'>";

    content += "<div class='h-100 p-0 container-fluid'>";

    content += "<div class='row row-3rd p-0 m-0'>";
    content += "<div class='h-100 p-0 col d-flex justify-content-center text-center'>";
    content += "<input class='btn btn-green h-100 w-100 p-0 m-v-c' type='color' "
               "name='htmlcolor' value='#a7abad' id='colorWell'/>";
    content += "</div>";
    content += "</div>";

    content += "<div class='row row-6th p-0 m-0'>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "</div>";

    content += "<div class='row row-6th p-0 m-0'>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "<a class='h-100 col d-flex justify-content-center text-center "
               "colorBlock'></a>";
    content += "</div>";

    content += "<div class='row row-6th p-0 m-0'>";
    content += "<div class='h-100 p-0 col d-flex justify-content-center text-center'>";
    content += "<button id='randomButton' class='btn btn-gray h-100 w-100 m-v-c' "
               "onclick='makeRandomColor()' type='submit'></button>";
    content += "</div> </div>";

    content += "<div class='row row-6th p-0 m-0'>";
    content += "<div class='h-100 p-0 col d-flex justify-content-center text-center'>";
    content += "<button id='solidButton' class='btn btn-solid h-100 w-100 m-v-c' "
               "onclick='changeMode(1)' type='submit'></button>";
    content += "<button id='sparkleButton' class='btn btn-sparkle h-100 w-100 "
               "m-v-c' onclick='changeMode(2)' type='submit'></button>";
    content += "</div> </div>";

    content += "</div>";
    content += "</body>";

    content += "<script> var colorWell;var "
               "defaultColor='#353b3f';window.addEventListener('load',startup,!1);"
               "function "
               "startup(){colorWell=document.querySelector('#colorWell');colorWell."
               "value=defaultColor;colorWell.addEventListener('input',updateFirst,!1);"
               "colorWell.addEventListener('change',updateAll,!1);colorWell.select()}"
               "function updateFirst(event){var "
               "p=document.querySelector('div');if(p){p.style.color=event.target.value}}"
               "function updateAll(event){var "
               "color=colorWell.value.toString();sendColor(color)}function "
               "setCWcolor(new_color){colorWell.value=new_color}function "
               "changeMode(new_mode){sendMode(new_mode)}function makeRandomColor(){var "
               "color='#'+(Math.random()*0xFFFFFF<<0).toString(16);sendColor(color)}"
               "function "
               "make_new_next_color(){return'#'+(Math.random()*0xFFFFFF<<0).toString(16)"
               "}$(document).ready(function(){$('a.colorBlock').each(function(){this."
               "style.background=make_new_next_color()});$('a.colorBlock').click("
               "function(){sendColor(RGBToHex(this.style.background));replace_colors()})"
               "});function sendColor(new_color){var "
               "colorsliced=new_color.slice(1,7);var "
               "str='color?color='+colorsliced;setCWcolor(new_color);var xhttp=new "
               "XMLHttpRequest();xhttp.open('GET',str,!0);xhttp.send(str)}function "
               "sendMode(new_mode){var str='mode?mode='+new_mode;var xhttp=new "
               "XMLHttpRequest();xhttp.open('GET',str,!0);xhttp.send(str)}function "
               "RGBToHex(rgb){let sep=rgb.indexOf(',')>-1?',':' "
               "';rgb=rgb.substr(4).split(')')[0].split(sep);let "
               "r=(+rgb[0]).toString(16),g=(+rgb[1]).toString(16),b=(+rgb[2]).toString("
               "16);if(r.length==1)r='0'+r;if(g.length==1)g='0'+g;if(b.length==1)b='0'+"
               "b;return'#'+r+g+b}function "
               "replace_colors(){$('a.colorBlock').each(function(){this.style."
               "background=make_new_next_color()})}</script>";

    content += "</html>";

    server.send(200, "text/html", content);
}

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

void handleColorApiV1Basic()
{
    if (!checkIncomingRequest()) {
        return;
    }

    String const message{server.arg("plain")};

    Serial.println("/api/v1/basic got message: " + message);

    StaticJsonDocument<96> doc;

    DeserializationError error = deserializeJson(doc, message);

    if (error) {
        Serial.print(F("deserializeJson() failed: "));
        Serial.println(error.f_str());
        return;
    }

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
        target_brightness = doc["brightness"];
    }

    server.send(200, "text/plain", "Mode change OK.");
}

void handleColorApiV1Multi()
{
    if (!checkIncomingRequest()) {
        return;
    }

    String const message{server.arg("plain")};

    Serial.println("/api/v1/multi got message: " + message);

    StaticJsonDocument<1024> doc;

    DeserializationError error = deserializeJson(doc, message);

    if (error) {
        Serial.print(F("deserializeJson() failed: "));
        Serial.println(error.f_str());
    }

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
        target_brightness = doc["brightness"];
    }

    led_mode = LedMode::gradient_change;

    server.send(200, "text/plain", "Multi color change OK.");
}

void setup(void)
{
    const int DATA_PIN = 7;
    const int CLOCK_PIN = 5;

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
    server.on("/", handleRoot);
    server.on("/api/v1/basic", HTTP_POST, handleColorApiV1Basic);
    server.on("/api/v1/multi", HTTP_POST, handleColorApiV1Multi);
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
    static constexpr auto lerp_amount_8{UINT8_MAX / 20};
    static constexpr auto lerp_every_n_frames{2};
    current_color = current_color.lerp16(target_color, lerp_amount);
    current_brightness = target_brightness;

    static auto lerp_frame_counter{0};
    if (lerp_frame_counter >= lerp_every_n_frames) {
        //current_brightness = lerp8by8(current_brightness, target_brightness, lerp_amount);
        lerp_frame_counter = 0;
    }
    else {
        lerp_frame_counter++;
    }

    Serial.println(String(current_color.r) + ", " + String(current_color.g) + ", "
                   + String(current_color.b) + " | " + String(target_color.r) + ", "
                   + String(target_color.g) + ", " + String(target_color.b) + " || "
                   + current_brightness + " | " + target_brightness);

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

void loop(void)
{
    server.handleClient();

    // Caveman impl.
    if (led_mode == LedMode::off) {
        FastLED.clear(true);
    }
    else if ((millis() - prev_time) >= frame_time) {
        prev_time = millis();
        // Update LEDs
        updateLeds();
    }
}
