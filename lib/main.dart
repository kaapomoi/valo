import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'light.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:lan_scanner/lan_scanner.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemNavigationBarColor: Color(0xff121212)));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'valo',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: "valo"),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late double brightness = 255;
  late String myIP;
  List<Color> generatedColors = <Color>[];
  int lightingMode = 1;
  List<Light> lights = [];

  TimeOfDay _time = const TimeOfDay(hour: 6, minute: 30);

  Color pickerColor = const Color(0xffffeedd);

  void startup() async {
    if (await Permission.locationWhenInUse.request().isGranted) {
      stdout.writeln("We are in!");
    }

    var res = await NetworkInfo().getWifiIP();
    myIP = res.toString();
    stdout.writeln(myIP);

    String subnet = ipToCSubnet(myIP);
    final scanner = LanScanner();

    final List<Host> hosts = await scanner.quickIcmpScanAsync(subnet);

    /// For every IP in subnet, ping.
    for (var i = 0; i < hosts.length; i++) {
      String ipToPing = hosts[i].internetAddress.address;
      if (ipToPing == myIP) {
        continue;
      }
      stdout.writeln("Pinging $ipToPing");
      Uri ur = Uri.http(ipToPing, "/api/v1/ping");
      try {
        final http.Response response =
            await http.get(ur).timeout(const Duration(seconds: 3));
        if (response.body.startsWith("valo@")) {
          stdout.writeln("Found ${response.body}");
          setState(() {
            lights.add(Light(ipToPing));
          });
        } else {
          stdout.writeln("No resp from $ipToPing");
        }
      } catch (e) {
        stdout.writeln("Exception $e from $ipToPing");
      }
    }
  }

  /// Text controller
  late TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    startup();
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
    for (final light in lights) {
      light.post("/api/v1/basic", "{ 'mode': ${lightingMode.toString()} }");
    }
  }

  void _selectTime() async {
    final TimeOfDay? newTime =
        await showTimePicker(context: context, initialTime: _time);
    if (newTime != null) {
      setState(() {
        _time = newTime;
      });
      sendAlarmApiRequest();
    }
  }

  void sendAlarmApiRequest() async {
    for (final light in lights) {
      final http.Response response = await light.post("/api/v1/alarm",
          "{ 'alarm_hours': ${_time.hour.toString()}, 'alarm_minutes': ${_time.minute.toString()}, 'alarm_enabled': 1 }");

      /// TODO: Fix this dialog
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

  Icon getIcon() {
    switch (lightingMode) {
      case 1:
        return const Icon(Icons.scatter_plot_sharp);
      case 2:
        return const Icon(Icons.lightbulb);
      default:
        return const Icon(Icons.lightbulb);
    }
  }

  List<Widget> createLightActivationListItems() {
    List<Widget> lightWidgets = [
      const DrawerHeader(
        child: Text('Lights'),
      ),
    ];

    for (final light in lights) {
      stdout.writeln("Created a list item");
      lightWidgets.add(ListTile(
          title: light.isActive()
              ? Text("${light.id()} ACTIVE")
              : Text("${light.id()} INACTIVE"),
          selected: light.isActive(),
          onTap: () {
            setState(() {
              light.toggleActive();
            });
          }));
    }

    return lightWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showColors(),
      drawerEdgeDragWidth: MediaQuery.of(context).size.width,
      drawer: Drawer(
          child: ListView(
        padding: EdgeInsets.zero,
        children: createLightActivationListItems(),
      )),
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            ElevatedButton(
              onPressed: _toggleLightingMode,
              child: getIcon(),
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
            ElevatedButton(
              onPressed: openLightActivationDialog,
              child: const Icon(Icons.color_lens_sharp),
            ),
            ElevatedButton(
              onPressed: _selectTime,
              child: const Icon(Icons.api),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  lightingMode = 0;
                });

                for (final light in lights) {
                  light.post("/api/v1/basic", "{ 'mode': 0 }");
                }
              },
              child: const Icon(Icons.power_off_sharp),
            ),
            ElevatedButton(
              onPressed: () async {
                openBrightnessSliderDialog();
              },
              child: const Icon(Icons.brightness_1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _showColors() {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
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

        var colorStr = color.value.toRadixString(16).substring(2).toUpperCase();

        return Container(
          padding: const EdgeInsets.all(4.0),
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                return color;
              }),
            ),
            onPressed: () {
              for (final light in lights) {
                String body = "{'color': '$colorStr'";
                if (lightingMode == 0) {
                  setState(() {
                    lightingMode = 1;
                  });
                  body += ", 'mode': ${lightingMode.toString()}";
                }
                body += "}";
                light.post("/api/v1/basic", body);
              }
            },
            child: Text(
                style: TextStyle(
                    color: Colors.black.withOpacity(0.80),
                    fontSize: 7,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w200),
                "#$colorStr"),
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

  List<Widget> createLightActivationButtons() {
    List<Widget> lightWidgets = [];

    for (final light in lights) {
      lightWidgets.add(ElevatedButton(
          onPressed: () {
            setState(() {
              light.toggleActive();
            });
          },
          child: light.isActive() ? const Text("ON") : const Text("OFF")));
    }

    return lightWidgets;
  }

  void openLightActivationDialog() => showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text(""), actions: createLightActivationButtons()),
      );

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
                for (final light in lights) {
                  light.post("/api/v1/basic", "{ 'color': '$pickerColorStr' }");
                }
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      );

  void openBrightnessSliderDialog() async {
    final newBrightness = await showDialog(
        context: context,
        builder: (context) =>
            BrightnessChangeDialog(initialBrightness: brightness));
    if (newBrightness != null) {
      setState(() {
        brightness = newBrightness;
        for (final light in lights) {
          light.post("/api/v1/basic", "{ \"brightness\": $brightness }");
        }
      });
    }
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
        ),
      );

  void submitNewIpAddress() {
    Navigator.of(context).pop(controller.text);
  }
}

class BrightnessChangeDialog extends StatefulWidget {
  final double initialBrightness;

  const BrightnessChangeDialog({super.key, required this.initialBrightness});

  @override
  State<BrightnessChangeDialog> createState() => _BrightnessChangeDialogState();
}

class _BrightnessChangeDialogState extends State<BrightnessChangeDialog> {
  late double brightness;

  @override
  void initState() {
    super.initState();
    brightness = widget.initialBrightness;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: MediaQuery.of(context).size.height / 3,
        height: 72.0,
        child: Slider(
          min: 0,
          max: 255,
          value: brightness,
          onChanged: ((value) => setState(() => brightness = value)),
          onChangeEnd: (newValue) => {Navigator.pop(context, newValue)},
        ),
      ),
    );
  }
}
