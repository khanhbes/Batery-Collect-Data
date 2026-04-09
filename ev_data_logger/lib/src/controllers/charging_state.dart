import '../models/charging_session_item.dart';

class ChargingState {
  const ChargingState({
    required this.activeChargingSession,
    required this.chargingHistory,
    required this.chargingLogCsvPath,
    required this.chargingErrorMessage,
    required this.isBusy,
  });

  factory ChargingState.initial() {
    return const ChargingState(
      activeChargingSession: null,
      chargingHistory: <ChargingSessionItem>[],
      chargingLogCsvPath: null,
      chargingErrorMessage: null,
      isBusy: false,
    );
  }

  final ChargingSessionItem? activeChargingSession;
  final List<ChargingSessionItem> chargingHistory;
  final String? chargingLogCsvPath;
  final String? chargingErrorMessage;
  final bool isBusy;

  ChargingState copyWith({
    ChargingSessionItem? activeChargingSession,
    List<ChargingSessionItem>? chargingHistory,
    String? chargingLogCsvPath,
    String? chargingErrorMessage,
    bool? isBusy,
    bool clearActiveChargingSession = false,
    bool clearChargingErrorMessage = false,
    bool clearChargingLogCsvPath = false,
  }) {
    return ChargingState(
      activeChargingSession: clearActiveChargingSession
          ? null
          : activeChargingSession ?? this.activeChargingSession,
      chargingHistory: chargingHistory ?? this.chargingHistory,
      chargingLogCsvPath: clearChargingLogCsvPath
          ? null
          : chargingLogCsvPath ?? this.chargingLogCsvPath,
      chargingErrorMessage: clearChargingErrorMessage
          ? null
          : chargingErrorMessage ?? this.chargingErrorMessage,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
