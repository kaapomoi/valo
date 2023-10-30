# valo

An app to control LEDs over Wi-Fi

Swipe left or right to get new colors, or just scroll down endlessly.


### Setup
Currently only works with static SSID, password and IP configurations.


### ESP8266 LED API

The [ESP8266](esp8266/valo/valo.ino) hosts a JSON-based API that can be used without the front-end Flutter app.

An example of external usage is located here: [wakeup-light](https://github.com/kaapomoi/wakeup-light).

#### API Endpoints

```
/api/v1/basic:
{
    "mode": 1,            /// 0 = off, 1 = solid color, 2 = twinkle effect
    "color": "FDFDFD",    /// RGB values from 0-255 in hex.
    "brightness": 255     /// LED brightness (causes flickering if used too often/fast.)
}

/api/v1/multi:
{
    "colors": [           /// An array of 4 colors to cycle between gradually.
        "FDFDFD",
        "ABABAB",
        "00FF00",
        "ABCDEF"
    ],
    "speed": 123          /// Unused, will not have an effect.
}

/api/v1/wakeup:
{
    "time_seconds": 1800  /// Ramp up white light from zero to full brightness in 30 minutes.
}

/api/v1/alarm:
{
    "alarm_enabled": 1,  /// Enable/disable the alarm (1|0)
    "alarm_hours": 6,    /// Set which hour to ring the alarm at (0-23) 
    "alarm_minutes": 15  /// Set which minute to ring the alarm at (0-59) 
}

/api/v1/white:
{
    "cold": 128,         /// 0-255
    "warm": 64           /// 0-255
}

```
