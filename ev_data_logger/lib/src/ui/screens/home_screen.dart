import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_info.dart';
import '../../controllers/trip_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onTripStarted});

  final VoidCallback? onTripStarted;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _startSocController = TextEditingController();
  final TextEditingController _payloadKgController = TextEditingController();
  bool _isStarting = false;

  @override
  void dispose() {
    _startSocController.dispose();
    _payloadKgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripLiveProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Start a new trip with the initial parameters below.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _startSocController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Start SoC (%)',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                final int? parsed = int.tryParse(value ?? '');
                if (parsed == null || parsed < 0 || parsed > 100) {
                  return 'Start SoC must be between 0 and 100.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _payloadKgController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Payload (kg)',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                final double? parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed < 0) {
                  return 'Payload must be greater than or equal to 0.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                border: OutlineInputBorder(),
              ),
              child: const Text(evVehicleType),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(_isStarting ? 'Starting...' : 'Start Trip'),
                onPressed: state.isTracking || _isStarting
                    ? null
                    : () async {
                        if (_formKey.currentState?.validate() != true) {
                          return;
                        }

                        final int startSoc = int.parse(
                          _startSocController.text,
                        );
                        final double payloadKg = double.parse(
                          _payloadKgController.text,
                        );

                        setState(() {
                          _isStarting = true;
                        });

                        try {
                          await ref
                              .read(tripControllerProvider.notifier)
                              .startTrip(
                                startSoc: startSoc,
                                payloadKg: payloadKg,
                              );

                          if (context.mounted) {
                            widget.onTripStarted?.call();
                          }
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Unable to start trip: ${error.toString()}',
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isStarting = false;
                            });
                          }
                        }
                      },
              ),
            ),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
