import 'package:flutter/material.dart';

import '../widgets/menu_card.dart';
import 'instrument_picker_page.dart';
import 'profile_page.dart';
import 'upload_scoring_page.dart';

/// Main menu: three sections the user can navigate to.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Selamat datang',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              MenuCard(
                title: 'Instrument Virtual',
                subtitle: 'Mainkan Piano atau Sasando',
                icon: Icons.music_note,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InstrumentPickerPage()),
                ),
              ),
              const SizedBox(height: 20),
              MenuCard(
                title: 'Upload and Scoring Songs',
                subtitle: 'Segera hadir',
                icon: Icons.upload_file,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UploadScoringPage()),
                ),
              ),
              const SizedBox(height: 20),
              MenuCard(
                title: 'Profil',
                subtitle: 'Segera hadir',
                icon: Icons.person,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}