import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/ui/screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: EvDataLoggerApp()));
}

class EvDataLoggerApp extends StatelessWidget {
  const EvDataLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EV Data Logger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A6A)),
      ),
      home: const SplashScreen(),
    );
  }
}
