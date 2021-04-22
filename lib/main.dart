import 'package:flutter/material.dart';
import 'package:random_color/random_color.dart';
import 'package:http/http.dart' as http;
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

void main() => runApp(MaterialApp(home: MyApp()));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Color> generatedColors = <Color>[];
  int lightingMode = 1;
  final List<ColorHue> _hueType = <ColorHue>[
    ColorHue.green,
    ColorHue.red,
    ColorHue.pink,
    ColorHue.purple,
    ColorHue.blue,
    ColorHue.yellow,
    ColorHue.orange
  ];
  ColorBrightness _colorLuminosity = ColorBrightness.random;
  ColorSaturation _colorSaturation = ColorSaturation.random;

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
    Uri ur =
        Uri.http("192.168.1.10:80", "/mode", {"mode": lightingMode.toString()});
    http.get(ur);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: SimpleGestureDetector(
          child: _showColors(),
          onHorizontalSwipe: _onHorizontalSwipe,
          swipeConfig: SimpleSwipeConfig(
            verticalThreshold: 40.0,
            horizontalThreshold: 40.0,
            swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct,
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: FloatingActionButton(
              tooltip: 'Toggle blinking effect',
              child: lightingMode == 1
                  ? new Icon(Icons.scatter_plot)
                  : new Icon(Icons.lightbulb),
              onPressed: _toggleLightingMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _showColors() {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) {
        Color _color;

        if (generatedColors.length > index) {
          _color = generatedColors[index];
        } else {
          _color = RandomColor().randomColor(
              colorHue: ColorHue.multiple(colorHues: _hueType),
              colorSaturation: _colorSaturation,
              colorBrightness: _colorLuminosity);

          generatedColors.add(_color);
        }

        Color getTextColor() {
          if (_color.computeLuminance() > 0.3) {
            return Colors.black;
          } else {
            return Colors.white;
          }
        }

        return InkWell(
          onTap: () {
            var colorStr =
                _color.value.toRadixString(16).substring(2).toUpperCase();
            Uri ur = Uri.http("192.168.1.10:80", "/color", {"color": colorStr});
            http.get(ur);
            print("${_color.red}, "
                "${_color.blue}, "
                "${_color.green}");
          },
          child: Card(
            color: _color,
            child: Container(
              margin: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      getColorNameFromColor(_color).getName,
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          ?.copyWith(fontSize: 13.0, color: getTextColor()),
                    ),
                  ),
                  Container(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '#${_color.value.toRadixString(16).toUpperCase().substring(2)}',
                      style: Theme.of(context).textTheme.caption?.copyWith(
                          color: getTextColor(),
                          fontSize: 16.0,
                          fontWeight: FontWeight.w300),
                    ),
                  ),
                ],
              ),
            ),
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
}

typedef HueTypeChange = void Function(List<ColorHue> colorHues);
typedef SaturationTypeChange = void Function(ColorSaturation colorSaturation);
typedef LuminosityTypeChange = void Function(ColorBrightness colorBrightness);
