import 'package:flutter/material.dart';

class WhiteLevelChangeDialog extends StatefulWidget {
  final double initialCold;
  final double initialWarm;

  const WhiteLevelChangeDialog(
      {super.key, required this.initialCold, required this.initialWarm});

  @override
  State<WhiteLevelChangeDialog> createState() => _WhiteLevelChangeDialogState();
}

class _WhiteLevelChangeDialogState extends State<WhiteLevelChangeDialog> {
  late double cold;
  late double warm;

  @override
  void initState() {
    super.initState();
    cold = widget.initialCold;
    warm = widget.initialWarm;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        height: 144.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Slider(
              min: 0,
              max: 255,
              value: cold,
              onChanged: ((value) => setState(() => cold = value)),
              onChangeEnd: (value) => {
                setState(() => cold = value),
              },
            ),
            Slider(
              min: 0,
              max: 255,
              value: warm,
              onChanged: ((value) => setState(() => warm = value)),
              onChangeEnd: (value) => {
                setState(() => warm = value),
              },
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, {'cold': cold, 'warm': warm});
              },
              child: const Icon(Icons.done),
            ),
          ],
        ),
      ),
    );
  }
}
