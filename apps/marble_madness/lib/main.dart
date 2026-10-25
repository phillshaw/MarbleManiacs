import 'package:flutter/material.dart';

import 'src/game_controller.dart';
import 'src/game_screen.dart';

void main() => runApp(const MarbleMadnessApp());

class MarbleMadnessApp extends StatelessWidget {
  const MarbleMadnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1E6FD9);
    return MaterialApp(
      title: 'Marble Madness',
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: const SetupScreen(),
    );
  }
}

/// Pick how many computer players to face, then start.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _opponents = 3;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Marble Madness', style: text.headlineMedium),
                const SizedBox(height: 32),
                Text('Computer opponents', style: text.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [
                    for (var n = 1; n <= 4; n++)
                      ButtonSegment(value: n, label: Text('$n')),
                  ],
                  selected: {_opponents},
                  onSelectionChanged: (s) =>
                      setState(() => _opponents = s.single),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GameScreen(
                        controller: GameController(opponents: _opponents),
                      ),
                    ),
                  ),
                  child: const Text('Start game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
