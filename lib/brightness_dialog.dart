import 'package:flutter/material.dart';

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
      alignment: Alignment.lerp(Alignment.center, Alignment.bottomCenter, 0.5),
      child: SizedBox(
        width: MediaQuery.of(context).size.height / 3,
        height: 80.0,
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
