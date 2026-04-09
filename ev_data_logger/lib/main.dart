import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/config/app_info.dart';
import 'src/services/storage_path_service.dart';
import 'src/ui/screens/splash_screen.dart';

/// Appends [message] to `crash_log.txt` in the app documents directory.
/// Failures are silently swallowed so the error handler itself never throws.
Future<void> _writeCrashLog(String message) async {
  try {
    final String rootPath = AppStorage.isInitialized
        ? AppStorage.rootPath
        : Directory.systemTemp.path;
    final Directory dir = Directory(rootPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final File file = File('${dir.path}/crash_log.txt');
    final String stamp = DateTime.now().toUtc().toIso8601String();
    await file.writeAsString('[$stamp] $message\n', mode: FileMode.append);
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppStorage.initialize();
  } catch (_) {}

  // Catch Flutter framework errors (widget build, layout, etc.).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _writeCrashLog(
      'FlutterError: ${details.exceptionAsString()}\n${details.stack}',
    );
  };

  // Catch errors on the root isolate that escape the zone (platform channel).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _writeCrashLog('PlatformDispatcher: $error\n$stack');
    return false; // let the OS handler also run
  };

  // Catch uncaught async errors thrown inside runApp.
  runZonedGuarded<void>(
    () => runApp(const ProviderScope(child: EvDataLoggerApp())),
    (Object error, StackTrace stack) {
      _writeCrashLog('ZonedGuarded: $error\n$stack');
    },
  );
}

class EvDataLoggerApp extends StatelessWidget {
  const EvDataLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '$appDisplayName $appDisplayVersion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A6A)),
      ),
      home: const SplashScreen(),
    );
  }
}
