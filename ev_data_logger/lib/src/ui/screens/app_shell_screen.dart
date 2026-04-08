import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/trip_providers.dart';
import '../widgets/app_logo.dart';
import '../widgets/end_trip_dialog.dart';
import 'active_trip_screen.dart';
import 'export_screen.dart';
import 'home_screen.dart';
import 'trip_history_screen.dart';

class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRecovery();
    });
  }

  Future<void> _checkRecovery() async {
    final controller = ref.read(tripControllerProvider.notifier);
    final recoverable = await controller.getRecoverableTrip();
    if (recoverable == null || !mounted) {
      return;
    }

    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unfinished Trip Detected'),
          content: const Text('Do you want to resume this trip or end it now?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop('end'),
              child: const Text('End Trip'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('resume'),
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'resume') {
      await controller.resumeTrip();
      if (!mounted) {
        return;
      }
      setState(() {
        _index = 1;
      });
      return;
    }

    final int? endSoc = await showDialog<int>(
      context: context,
      builder: (_) => const EndTripDialog(title: 'End Recovered Trip'),
    );

    if (endSoc == null) {
      return;
    }

    await controller.endRecoveredTrip(endSoc: endSoc);
    ref.invalidate(tripHistoryProvider);
    if (!mounted) {
      return;
    }

    setState(() {
      _index = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      HomeScreen(onTripStarted: () => setState(() => _index = 1)),
      ActiveTripScreen(onTripEnded: () => setState(() => _index = 2)),
      const TripHistoryScreen(),
      const ExportScreen(),
    ];

    const List<String> titles = <String>['Start', 'Live', 'History', 'Export'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const AppLogo(size: 28),
            const SizedBox(width: 8),
            Text('EV Data Logger - ${titles[_index]}'),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() {
            _index = value;
          });
          if (value == 2) {
            ref.invalidate(tripHistoryProvider);
          }
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.play_circle), label: 'Start'),
          NavigationDestination(icon: Icon(Icons.speed), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.file_upload), label: 'Export'),
        ],
      ),
    );
  }
}
