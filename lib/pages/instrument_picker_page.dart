import 'package:flutter/material.dart';

import '../widgets/menu_card.dart';
import 'piano_page.dart';
import 'sasando_page.dart';

/// Lets the user choose between the Sasando and the Piano.
class InstrumentPickerPage extends StatelessWidget {
  const InstrumentPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instrument Virtual')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Choose an instrument to play',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              MenuCard(
                title: 'Sasando',
                subtitle: 'Plucked-string instrument from Rote Island, NTT',
                icon: Icons.graphic_eq,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SasandoPage()),
                ),
              ),
              const SizedBox(height: 20),
              MenuCard(
                title: 'Piano',
                subtitle: 'Classic keyboard, one octave and a bit',
                icon: Icons.piano,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PianoPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}