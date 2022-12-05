import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  var mySystemTheme = SystemUiOverlayStyle.light
      .copyWith(systemNavigationBarColor: Colors.deepPurple);

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
    Uri ur = Uri.http(ip, "/mode", {"mode": lightingMode.toString()});
    http.get(ur);
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
                0.5,
                0.7,
                0.9,
              ],
                  colors: [
                Colors.red,
                Colors.amber,
                Colors.lightGreen,
                Colors.blueGrey,
                Colors.deepPurple,
              ])),
          child: SimpleGestureDetector(
            onHorizontalSwipe: _onHorizontalSwipe,
            swipeConfig: const SimpleSwipeConfig(
              verticalThreshold: 40.0,
              horizontalThreshold: 40.0,
              swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct,
            ),
            child: _showColors(),
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
                  setState(() => this.ip = newIp);
                },
                child: const Icon(Icons.wifi_sharp),
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
            Uri ur = Uri.http(ip, "/color", {"color": colorStr});
            http.get(ur);
          },
          child: Card(
            color: color,
            // child: Container(
            //   margin: const EdgeInsets.all(8.0),
            //   child: Column(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     children: <Widget>[
            //       Container(
            //         alignment: Alignment.centerRight,
            //         child: Text(
            //           '#${color.value.toRadixString(16).toUpperCase().substring(2)}',
            //           style: Theme.of(context).textTheme.caption?.copyWith(
            //               color: getTextColor(),
            //               fontSize: 16.0,
            //               fontWeight: FontWeight.w300),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
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
          ));

  void submitNewIpAddress() {
    Navigator.of(context).pop(controller.text);
  }
}
