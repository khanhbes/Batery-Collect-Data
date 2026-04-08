import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/app_logo.dart';
import 'app_shell_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  Timer? _routeTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _logoScale = Tween<double>(
      begin: 0.78,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _logoOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _routeTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AppShellScreen()),
      );
    });
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF031C1A), Color(0xFF0B5147)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              return Opacity(
                opacity: _logoOpacity.value,
                child: Transform.scale(scale: _logoScale.value, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                AppLogo(size: 112),
                SizedBox(height: 18),
                Text(
                  'EV DATA LOGGER',
                  style: TextStyle(
                    color: Color(0xFFD5F7E3),
                    fontSize: 26,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Track every second. Drive by data.',
                  style: TextStyle(color: Color(0xFFB9E7CE), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
