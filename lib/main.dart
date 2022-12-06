import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

void main() => runApp(const MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Color> generatedColors = <Color>[];
  int lightingMode = 1;
  String ip = "192.168.50.10:80";
  var mySystemTheme = SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor: const Color.fromARGB(0, 255, 255, 255));

  Color pickerColor = const Color(0xffffeedd);

  /// Text controller
  late TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    controller.text = ip;
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

  void sendTestApiRequest() {
    Uri ur = Uri.http(ip, "/api/v1/multi");
    http.post(ur,
        body: "{ \"colors\": [\"aa00bb\", \"00ffff\", \"dddd00\", \"00ffff\","
            " \"aa00bb\"], \"mode\": 3, \"brightness\": 55 }");
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
                0.3,
                0.4,
                0.6,
                0.8,
              ],
              colors: [
                Color.fromARGB(255, 255, 131, 122),
                Color.fromARGB(255, 184, 156, 72),
                Color.fromARGB(255, 154, 199, 103),
                Color.fromARGB(255, 89, 141, 167),
                Color.fromARGB(255, 13, 6, 53),
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
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Toggle blinking effect',
                onPressed: _toggleLightingMode,
                child: lightingMode == 1
                    ? const Icon(Icons.scatter_plot_sharp)
                    : const Icon(Icons.lightbulb),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Change target IP address',
                onPressed: () async {
                  final newIp = await openIpChangeDialog();
                  if (newIp == null || newIp.isEmpty) return;
                  setState(() => ip = newIp);
                },
                child: const Icon(Icons.wifi_sharp),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Open Color Picker Dialog',
                onPressed: openColorPickerDialog,
                child: const Icon(Icons.color_lens_sharp),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: FloatingActionButton(
                backgroundColor: Colors.white.withAlpha(100),
                tooltip: 'Test Color API',
                onPressed: sendTestApiRequest,
                child: const Icon(Icons.api),
              ),
            ),
          ],
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
