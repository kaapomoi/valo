import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool brightnessSliderVisible = false;
  late int brightness = 255;
  List<Color> generatedColors = <Color>[];
  int lightingMode = 1;
  String ip = "192.168.50.10:80";
  var mySystemTheme = SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor: const Color.fromARGB(0, 255, 255, 255));

  TimeOfDay _time = TimeOfDay(hour: 6, minute: 30);

  Color pickerColor = const Color(0xffffeedd);

  /// Text controller
  late TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    controller.text = ip;
    // Get brightness
    Uri ur = Uri.http(ip, "/api/v1/basic/");
    http.get(ur);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onHorizontalSwipe(SwipeDirection direction) {
    _updateColor();
  }

  void _toggleLightingMode() {
    if (lightingMode == 1) {
      setState(() {
        lightingMode = 2;
      });
    } else {
      setState(() {
        lightingMode = 1;
      });
    }
    Uri ur = Uri.http(ip, "/api/v1/basic");
    http.post(ur, body: "{ 'mode': ${lightingMode.toString()} }");
  }

  void _selectTime() async {
    final TimeOfDay? newTime =
        await showTimePicker(context: context, initialTime: _time);
    if (newTime != null) {
      setState(() {
        _time = newTime;
      });
    }
    sendAlarmApiRequest();
  }

  void sendAlarmApiRequest() async {
    Uri ur = Uri.http(ip, "/api/v1/alarm");
    final Response response = await http.post(ur,
        body:
            "{ 'alarm_hours': ${_time.hour.toString()}, 'alarm_minutes': ${_time.minute.toString()}, 'alarm_enabled': 1 }");
    showDialog(
        context: context,
        builder: (context) {
          Future.delayed(const Duration(seconds: 5), () {
            Navigator.of(context).pop(true);
          });
          return AlertDialog(
            title: Text(response.body),
          );
        });
  }

  Future<dynamic> fetchApiData(Uri ur) async {
    final response = await http.get(ur);

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      return jsonDecode(response.body);
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to get Api response');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: mySystemTheme,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: [
                0.1,
                0.2,
                0.35,
                0.55,
                0.8,
              ],
              colors: [
                Color.fromARGB(255, 182, 162, 161),
                Color.fromARGB(255, 209, 188, 125),
                Color.fromARGB(255, 179, 105, 124),
                Color.fromARGB(255, 141, 177, 196),
                Color.fromARGB(255, 44, 36, 88),
              ],
            ),
          ),
          child: SimpleGestureDetector(
            onHorizontalSwipe: _onHorizontalSwipe,
            swipeConfig: const SimpleSwipeConfig(
              verticalThreshold: 40.0,
              horizontalThreshold: 40.0,
              swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct,
            ),
            child: ShaderMask(
                shaderCallback: (Rect rect) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(172, 0, 0, 0),
                      Colors.transparent,
                      Colors.transparent,
                      Color.fromARGB(172, 0, 0, 0)
                    ],
                    stops: [0.0, 0.15, 0.85, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstOut,
                child: _showColors()),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(vertical: 21.9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Toggle blinking effect',
                onPressed: _toggleLightingMode,
                child: lightingMode == 1
                    ? const Icon(Icons.scatter_plot_sharp)
                    : const Icon(Icons.lightbulb),
              ),
              // FloatingActionButton(
              //   backgroundColor: Colors.white.withAlpha(100),
              //   tooltip: 'Change target IP address',
              //   onPressed: () async {
              //     final newIp = await openIpChangeDialog();
              //     if (newIp == null || newIp.isEmpty) return;
              //     setState(() => ip = newIp);
              //   },
              //   child: const Icon(Icons.wifi_sharp),
              // ),
              FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Open Color Picker Dialog',
                onPressed: openColorPickerDialog,
                child: const Icon(Icons.color_lens_sharp),
              ),
              FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Test Color API',
                onPressed: _selectTime,
                child: const Icon(Icons.api),
              ),
              FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Turn LEDs Off',
                onPressed: () {
                  Uri ur = Uri.http(ip, "/api/v1/basic");
                  http.post(ur, body: "{ \"mode\": 0 }");
                },
                child: const Icon(Icons.power_off_sharp),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Visibility(
                    visible: !brightnessSliderVisible,
                    child: FloatingActionButton(
                      backgroundColor: Colors.white.withAlpha(100),
                      tooltip: 'Change brightness',
                      onPressed: () {
                        // Spawn slider
                        setState(() {
                          brightnessSliderVisible = true;
                        });
                      },
                      child: const Icon(Icons.brightness_1),
                    ),
                  ),
                  Visibility(
                    visible: brightnessSliderVisible,
                    child: SizedBox(
                      width: 56.0,
                      height: MediaQuery.of(context).size.height / 3,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          activeColor: Colors.white.withAlpha(100),
                          thumbColor: Colors.white.withAlpha(200),
                          inactiveColor: Colors.white.withAlpha(50),
                          min: 0,
                          max: 255,
                          value: brightness.toDouble(),
                          onChanged: ((value) =>
                              setState(() => brightness = value.toInt())),
                          onChangeEnd: (newValue) => {
                            setState(() {
                              brightnessSliderVisible = false;

                              Uri ur = Uri.http(ip, "/api/v1/basic");
                              http.post(ur,
                                  body: "{ \"brightness\": $brightness }");
                            }),
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _showColors() {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) {
        Color color;

        if (generatedColors.length > index) {
          color = generatedColors[index];
        } else {
          Random random = Random();
          color = Color.fromRGBO(
              random.nextInt(255), random.nextInt(255), random.nextInt(255), 1);

          generatedColors.add(color);
        }

        return InkWell(
          onTap: () {
            var colorStr =
                color.value.toRadixString(16).substring(2).toUpperCase();
            Uri ur = Uri.http(ip, "/api/v1/basic");
            http.post(ur, body: "{ 'color': '$colorStr' }");
          },
          child: Card(
            color: color,
          ),
        );
      },
    );
  }

  void _updateColor() {
    setState(() {
      generatedColors.clear();
    });
  }

  void openColorPickerDialog() => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Pick a color"),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color value) {
                setState(() => pickerColor = value);
              },
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                var pickerColorStr = pickerColor.value
                    .toRadixString(16)
                    .substring(2)
                    .toUpperCase();
                Uri ur = Uri.http(ip, "/api/v1/basic");
                http.post(ur, body: "{ 'color': '$pickerColorStr' }");
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      );

  Future<String?> openIpChangeDialog() => showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Target IP address"),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "Insert IP and port"),
            controller: controller,
            onSubmitted: (_) => submitNewIpAddress(),
          ),
          actions: [
            TextButton(
                onPressed: submitNewIpAddress, child: const Text("Apply"))
          ],
        ),
      );

  void submitNewIpAddress() {
    Navigator.of(context).pop(controller.text);
  }
}
