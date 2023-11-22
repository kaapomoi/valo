import 'dart:math';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'light.dart';
import 'brightness_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
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
  TextStyle textStyle = const TextStyle(
    letterSpacing: 2,
    fontWeight: FontWeight.w100,
  );

  void scanForLights() async {
    if (await Permission.locationWhenInUse.request().isGranted) {
      stdout.writeln("Location permission granted!");
    }

    var res = await NetworkInfo().getWifiIP();
    myIP = res.toString();
    stdout.writeln(myIP);

    final List<Host> hosts =
        await LanScanner().quickIcmpScanAsync(ipToCSubnet(myIP));

    Future.forEach<Host>(hosts, (host) async {
      String ipToPing = host.internetAddress.address;
      if (ipToPing == myIP) {
        return;
      }
      stdout.writeln("Pinging $ipToPing");
      Uri ur = Uri.http(ipToPing, "/api/v1/ping");
      try {
        final http.Response response =
            await http.get(ur).timeout(const Duration(seconds: 3));
        if (response.body.startsWith("valo@")) {
          stdout.writeln("Found ${response.body}");
          setState(() {
            /// Don't add duplicate lights
            if (lights.every((light) => light.ip != ipToPing)) {
              lights.add(Light(ipToPing));
            }
          });
        } else {
          stdout.writeln("No resp from $ipToPing");
        }
      } catch (e) {
        stdout.writeln("Exception $e from $ipToPing");
      }
    });
  }

  /// Text controller
  late TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    loadLightsFromPersistency();
    scanForLights();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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

  void saveLightsToPersistency() async {
    if (lights.isNotEmpty) {
      List<String> serializedStrings = [];

      for (final light in lights) {
        serializedStrings.add(light.getSerializedString());
        stdout.writeln("Save lights.${serializedStrings.last}");
      }

      stdout.writeln("Save lights.${serializedStrings.length}");

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setStringList('lights', serializedStrings);
    }
  }

  Future<void> loadLightsFromPersistency() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    List<Light> newLights = [];

    final List<String>? serializedStrings = prefs.getStringList('lights');

    for (final serializedString in serializedStrings!) {
      stdout.writeln("Load lights. str: $serializedString");
      newLights.add(Light.complete(serializedString));
    }

    stdout.writeln("Load lights.${newLights.length}");
    lights = newLights;
  }

  void resetPersistentStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('lights');
  }

  Future showSuccessDialog(Light light, String resp) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "${light.id()} >> $resp",
            style: textStyle.copyWith(fontSize: 16),
          ),
        );
      },
    );
  }

  void sendAlarmApiRequest() async {
    /// TODO: Remove this when reprogramming Nodes.
    int adjustedHours = _time.hour < 23 ? _time.hour + 1 : 0;

    for (final light in lights) {
      final http.Response response = await light.post("/api/v1/alarm",
          "{ 'alarm_hours': ${adjustedHours.toString()}, 'alarm_minutes': ${_time.minute.toString()}, 'alarm_enabled': 1 }");

      showSuccessDialog(light, response.body);
    }
  }

  Icon getIcon() {
    switch (lightingMode) {
      case 1:
        return const Icon(Icons.scatter_plot_sharp);
      default:
        return const Icon(Icons.lightbulb);
    }
  }

  List<Widget> createLightActivationListItems() {
    List<Widget> lightWidgets = [
      DrawerHeader(
        child: Text(
          'valo',
          style: TextStyle(
            color: Colors.white.withAlpha(128),
            fontSize: 80.0,
            letterSpacing: 4,
            fontWeight: FontWeight.w100,
          ),
        ),
      ),
    ];

    for (final light in lights) {
      stdout.writeln("Created a list item");

      lightWidgets.add(
        ListTile(
          title: Text(light.id(),
              style: textStyle.copyWith(
                  color: Colors.white.withAlpha(128), fontSize: 14)),
          leading: SizedBox(
              width: 48,
              child: light.isActive()
                  ? Text("mod", style: textStyle.copyWith(fontSize: 12))
                  : Text("const", style: textStyle)),
          trailing: SizedBox(
            width: 32,
            height: 32,
            child: ElevatedButton(
              style: ButtonStyle(
                fixedSize: const MaterialStatePropertyAll(Size(24, 24)),
                iconSize: const MaterialStatePropertyAll(16),
                iconColor: const MaterialStatePropertyAll(Color(0xff121212)),
                padding: const MaterialStatePropertyAll(EdgeInsets.zero),
                backgroundColor: MaterialStatePropertyAll(light.color),
              ),
              onPressed: () {
                setState(() {
                  light.toggleOnOff();
                });
              },
              child: Icon(light.lightingMode != LightingMode.off
                  ? Icons.power_off_outlined
                  : Icons.lightbulb),
            ),
          ),
          selected: light.isActive(),
          onTap: () {
            setState(() {
              light.toggleActive();
            });
          },
          onLongPress: () async {
            var newName = await showTextInputDialog(context, light);
            if (newName != null) {
              setState(() {
                light.name = newName;
              });
            }
          },
        ),
      );
    }

    saveLightsToPersistency();

    return lightWidgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showColors(),
      drawerEdgeDragWidth: MediaQuery.of(context).size.width,
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
          children: createLightActivationListItems(),
        ),
      ),
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _toggleLightingMode,
              child: getIcon(),
            ),
            ElevatedButton(
              onPressed: _selectTime,
              child: const Icon(Icons.alarm),
            ),
            ElevatedButton(
              onPressed: resetPersistentStorage,
              child: const Icon(Icons.storage),
            ),
            ElevatedButton(
              onPressed: () {
                for (final light in lights) {
                  setState(() {
                    light.turnOff();
                  });
                }
              },
              child: const Icon(Icons.power_off_sharp),
            ),
            ElevatedButton(
              onPressed: () async {
                openBrightnessSliderDialog();
              },
              child: const Icon(Icons.sunny),
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
                setState(() {
                  String body = "{'color': '$colorStr'";
                  if (light.lightingMode == LightingMode.off) {
                    light.lightingMode = LightingMode.solid;
                    body += ", 'mode': ${light.lightingMode.index.toString()}";
                  }
                  body += "}";

                  light.setColorIfActive(color);
                  light.post("/api/v1/basic", body);
                });
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

  Future<String?> showTextInputDialog(BuildContext context, Light light) async {
    final textFieldController = TextEditingController();
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'set a name',
              style: textStyle,
            ),
            content: TextField(
              controller: textFieldController,
              decoration: InputDecoration(
                hintText: light.id(),
                hintStyle: textStyle,
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: const Text("cancel"),
                onPressed: () => setState(() {
                  Navigator.pop(context);
                }),
              ),
              ElevatedButton(
                child: const Text('ok'),
                onPressed: () => setState(() {
                  Navigator.pop(context, textFieldController.text);
                }),
              ),
            ],
          );
        });
  }

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
}
