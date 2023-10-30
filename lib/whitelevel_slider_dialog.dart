import 'package:flutter/material.dart';
import 'package:valo/light.dart';

class SpecialChangeDialog extends StatefulWidget {
  final double initialFirst;
  final double initialSecond;
  final List<Light> lights;

  const SpecialChangeDialog(
      {super.key,
      required this.initialFirst,
      required this.initialSecond,
      required this.lights});

  @override
  State<SpecialChangeDialog> createState() => _SpecialChangeDialogState();
}

class _SpecialChangeDialogState extends State<SpecialChangeDialog> {
  late double first;
  late double second;
  late List<Light> lights;

  @override
  void initState() {
    super.initState();
    first = widget.initialFirst;
    second = widget.initialSecond;
    lights = widget.lights;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.lerp(Alignment.center, Alignment.bottomCenter, 0.5),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: 128.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Slider(
              min: 0,
              max: 255,
              value: first,
              onChanged: ((value) => setState(() => first = value)),
              onChangeEnd: (value) => {
                setState(() {
                  first = value;
                  for (final light in lights) {
                    light.post("/api/v1/special", "{ \"first\": $first }");
                  }
                }),
              },
            ),
            Slider(
              min: 0,
              max: 255,
              value: second,
              onChanged: ((value) => setState(() => second = value)),
              onChangeEnd: (value) => {
                setState(() {
                  second = value;
                  for (final light in lights) {
                    light.post("/api/v1/special", "{ \"second\": $second }");
                  }
                }),
              },
            ),
          ],
        ),
      ),
    );
  }
}
