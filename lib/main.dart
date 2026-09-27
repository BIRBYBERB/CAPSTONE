import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'audio/oboe_engine.dart';
import 'pages/home_page.dart';

const supabaseURL = 'https://cahjzbzcdvotglbymdko.supabase.co';
const supabaseKey = 'sb_publishable_kSnntPVp1YgEVobV6jTZbg_HjBvVA_T';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  OboeEngine.init();

  await Supabase.initialize(
    url: supabaseURL,
    anonKey: supabaseKey, 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Instruments',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}