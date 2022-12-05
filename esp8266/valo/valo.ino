#include <ESP8266WiFi.h>
#include <WiFiClient.h>
#include <ESP8266WebServer.h>
#include <ESP8266mDNS.h>
#define FASTLED_ESP8266_NODEMCU_PIN_ORDER
#include "FastLED.h"




#include "secret.h"

#ifndef SSID
#define SSID "NOT_VALID"
#define PASS "NOT_VALID"
#endif

const char* ssid = SSID;
const char* password = PASS;

const double max_brightness = 256*3 - 1;
const double min_brightness = 80;

//data pin d7
//clock pin d5

#define NUM_LEDS 60
CRGB leds[NUM_LEDS];

#define FRAMES_PER_SECOND 30

unsigned long cur_time = 0;
unsigned long prev_time = 0;
unsigned long frame_time = ceil((float) 1000 / (float) FRAMES_PER_SECOND);

CRGB current_color;
int current_hue = 0;
uint8_t brightness = 255;
uint8_t led_mode = 1;

ESP8266WebServer server(80);

void handleRoot() {

  // Create a webpage
  String content;
  content.reserve(8192);

  content += "HTTP/1.1 200 OK\r\n";
  content += "Content-Type: text/html\r\n";
  content += "Connection: close\r\n";  // the connection will be closed after completion of the response
  content += "Refresh: 5\r\n";       // refresh the page automatically every 5 sec
  content += "\r\n";
  content += "<!DOCTYPE HTML><html><title>HOME-OHJAIN</title>";

  // Really lightweight impl. of bootstrap
  content += "<head> <meta charset='utf-8'> <meta name='viewport' content='width=device-width, initial-scale=1, shrink-to-fit=no'> <style>.h-0{height:0}.btn-green{background-color:#DDD;padding:4%!important}.btn-green:hover{background-color:#FFF}.btn{border-radius:0px!important}#randomButton{background-color:#151515;background-position:center 20%;background-size:contain;background-repeat:no-repeat;opacity:65%}#randomButton:hover{opacity:85%}#sparkleButton{background:url(http://eero.dclabra.fi/~ttv18skaapom/II_stars.png);background-color:#aaa;background-position:center;background-size:contain;background-repeat:no-repeat;opacity:65%}#sparkleButton:hover{opacity:85%}.row-3rd{height:33.3333vh}.row-6th{height:16.666666vh}.m-v-c{margin-top:auto;margin-bottom:auto}.o-0{opacity:0%}.o-25{opacity:25%}.o-50{opacity:50%}.o-75{opacity:75%}.o-100{opacity:100%}";
  content += ".w-100{width:100%!important}.btn{display:inline-block;font-weight:400;text-align:center;white-space:nowrap;vertical-align:middle;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none;border:1px solid transparent;padding:.375rem .75rem;font-size:1rem;line-height:1.5;border-radius:.25rem;transition:color .15s ease-in-out,background-color .15s ease-in-out,border-color .15s ease-in-out,box-shadow .15s ease-in-out}.m-0{margin:0!important}.p-0{padding:0!important}.h-100{height:100%!important}.text-center{text-align:center!important}.justify-content-center{-webkit-box-pack:center!important;-ms-flex-pack:center!important;justify-content:center!important}.d-flex{display:-webkit-box!important;display:-ms-flexbox!important;display:flex!important}.col{-ms-flex-preferred-size:0;flex-basis:0;-webkit-box-flex:1;-ms-flex-positive:1;flex-grow:1;max-width:100%}.container-fluid{width:100%;padding-right:15px;padding-left:15px;margin-right:auto;margin-left:auto}.row{display:-webkit-box;display:-ms-flexbox;display:flex;-ms-flex-wrap:wrap;flex-wrap:wrap;margin-right:-15px;margin-left:-15px}</style></head>";

  content += "<body id='bground' style='background: #71777b'>";

  content += "<div class='h-100 p-0 container-fluid'>";

  content += "<div class='row row-3rd p-0 m-0'>";
  content += "<div class='h-100 p-0 col d-flex justify-content-center text-center'>";
  content += "<input class='btn btn-green h-100 w-100 p-0 m-v-c' type='color' name='htmlcolor' value='#a7abad' id='colorWell'/>";
  content += "</div>";
  content += "</div>";
  
  content += "<div class='row row-6th p-0 m-0'>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "</div>";
  
  content += "<div class='row row-6th p-0 m-0'>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "<a class='h-100 col d-flex justify-content-center text-center colorBlock'></a>";
  content += "</div>";

  content += "<div class='row row-6th p-0 m-0'>";
  content += "<div class='h-100 p-0 col d-flex justify-content-center text-center'>";
  content += "<button id='randomButton' class='btn btn-gray h-100 w-100 m-v-c' onclick='makeRandomColor()' type='submit'></button>";
  content += "</div> </div>";

  content += "<div class='row row-6th p-0 m-0'>";
  content += "<div class='h-100 p-0 col d-flex justify-content-center text-center'>";
  content += "<button id='solidButton' class='btn btn-solid h-100 w-100 m-v-c' onclick='changeMode(1)' type='submit'></button>";
  content += "<button id='sparkleButton' class='btn btn-sparkle h-100 w-100 m-v-c' onclick='changeMode(2)' type='submit'></button>";
  content += "</div> </div>";

  content += "</div>";
  content += "</body>";

  content += "<script> var colorWell;var defaultColor='#353b3f';window.addEventListener('load',startup,!1);function startup(){colorWell=document.querySelector('#colorWell');colorWell.value=defaultColor;colorWell.addEventListener('input',updateFirst,!1);colorWell.addEventListener('change',updateAll,!1);colorWell.select()}function updateFirst(event){var p=document.querySelector('div');if(p){p.style.color=event.target.value}}function updateAll(event){var color=colorWell.value.toString();sendColor(color)}function setCWcolor(new_color){colorWell.value=new_color}function changeMode(new_mode){sendMode(new_mode)}function makeRandomColor(){var color='#'+(Math.random()*0xFFFFFF<<0).toString(16);sendColor(color)}function make_new_next_color(){return'#'+(Math.random()*0xFFFFFF<<0).toString(16)}$(document).ready(function(){$('a.colorBlock').each(function(){this.style.background=make_new_next_color()});$('a.colorBlock').click(function(){sendColor(RGBToHex(this.style.background));replace_colors()})});function sendColor(new_color){var colorsliced=new_color.slice(1,7);var str='color?color='+colorsliced;setCWcolor(new_color);var xhttp=new XMLHttpRequest();xhttp.open('GET',str,!0);xhttp.send(str)}function sendMode(new_mode){var str='mode?mode='+new_mode;var xhttp=new XMLHttpRequest();xhttp.open('GET',str,!0);xhttp.send(str)}function RGBToHex(rgb){let sep=rgb.indexOf(',')>-1?',':' ';rgb=rgb.substr(4).split(')')[0].split(sep);let r=(+rgb[0]).toString(16),g=(+rgb[1]).toString(16),b=(+rgb[2]).toString(16);if(r.length==1)r='0'+r;if(g.length==1)g='0'+g;if(b.length==1)b='0'+b;return'#'+r+g+b}function replace_colors(){$('a.colorBlock').each(function(){this.style.background=make_new_next_color()})}</script>";

  content += "</html>";

  server.send(200, "text/html", content);
}

void handleColorChange()
{
  Serial.println(server.arg("color"));
  
  // Receive color from webpage
  String col = server.arg("color");
  long number = (long) strtol( &col[0], NULL, 16);
  uint8_t red = (number >> 16 & 0xFF);
  uint8_t green = (number >> 8 & 0xFF);
  uint8_t blue = (number & 0xFF);

  // Calculate real percentual brightness
  double r_b = (red + green + blue) / max_brightness;
  
  Serial.println("real brightness: " + String(r_b));

  // Construct an RgbColor for the LEDs
  //RgbColor netcolor(red * r_b, green * r_b, blue * r_b);
  current_color = CRGB(red * r_b, green * r_b, blue * r_b);
  brightness = floor(r_b * 255);

  Serial.println(red);
  Serial.println(green);
  Serial.println(blue);
}

void handleModeChange(){

  String m = server.arg("mode");
  Serial.println("mode from handle mode change: " + String(m));
  led_mode = m.toInt();
}

void setup(void) {
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
  server.on("/color", HTTP_GET, handleColorChange);
  server.on("/mode", HTTP_GET, handleModeChange);

  if(MDNS.begin("valo")){
    Serial.println("MDNS Service started");
  }

  // Start the server
  const char * headerkeys[] = {"User-Agent", "Cookie"} ;
  size_t headerkeyssize = sizeof(headerkeys) / sizeof(char*);
  //ask server to track these headers
  server.collectHeaders(headerkeys, headerkeyssize);
  server.begin();
  Serial.println("HTTP server started");
  prev_time = millis();
}

void update_leds(){
  if(led_mode == 1){
    for( int i = 0; i < NUM_LEDS; i++) {
      leds[i] = current_color;
    }
  }
  else if(led_mode == 2){
    fadeToBlackBy( leds, NUM_LEDS, 10);
    int pos = random8(NUM_LEDS);
    leds[pos] += current_color + CRGB(random8(32),random8(32),random8(32));
  }
  
  Serial.println("leds[0]: " + String(leds[0].r) + "," + String(leds[0].g) + "," + String(leds[0].b));
  Serial.println("brightness: " + String(brightness));
  
  // If we dont want black, get atleast some color
  if((current_color.r + current_color.g + current_color.b) > 1) {
    FastLED.setBrightness(brightness + min_brightness);
  } else {
    FastLED.setBrightness(brightness);
  }
  
  FastLED.show();
}

void loop(void) {
  server.handleClient();
  // Debug

  // Async LED updates:
  EVERY_N_MILLISECONDS(frame_time){
    //update_leds();
  };
  
  // Caveman impl.
  if((millis() - prev_time) >= frame_time){
    prev_time = millis();
    // Update LEDs
    update_leds();
  }
  
}
