import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ambulance_model.dart';
import '../models/mission_model.dart';

enum RealtimeEventType {
  missionInserted,
  missionUpdated,
  missionDeleted,
  missionRefreshRequested,
  ambulanceUpdated,
}

class RealtimeAppEvent {
  const RealtimeAppEvent._({
    required this.type,
    this.mission,
    this.ambulance,
    this.recordId,
  });

  final RealtimeEventType type;
  final Mission? mission;
  final Ambulance? ambulance;
  final String? recordId;

  factory RealtimeAppEvent.missionInserted(Mission mission) =>
      RealtimeAppEvent._(
        type: RealtimeEventType.missionInserted,
        mission: mission,
        recordId: mission.id,
      );

  factory RealtimeAppEvent.missionUpdated(Mission mission) =>
      RealtimeAppEvent._(
        type: RealtimeEventType.missionUpdated,
        mission: mission,
        recordId: mission.id,
      );

  factory RealtimeAppEvent.missionDeleted(String missionId) =>
      RealtimeAppEvent._(
        type: RealtimeEventType.missionDeleted,
        recordId: missionId,
      );

  factory RealtimeAppEvent.missionRefreshRequested([String? reason]) =>
      RealtimeAppEvent._(
        type: RealtimeEventType.missionRefreshRequested,
        recordId: reason,
      );

  factory RealtimeAppEvent.ambulanceUpdated(Ambulance ambulance) =>
      RealtimeAppEvent._(
        type: RealtimeEventType.ambulanceUpdated,
        ambulance: ambulance,
        recordId: ambulance.id,
      );
}

class RealtimeEventBusService {
  RealtimeEventBusService._();

  static final RealtimeEventBusService instance = RealtimeEventBusService._();

  final StreamController<RealtimeAppEvent> _controller =
      StreamController<RealtimeAppEvent>.broadcast();

  Stream<RealtimeAppEvent> get stream => _controller.stream;

  void emit(RealtimeAppEvent event) {
    if (_controller.isClosed) return;
    debugPrint(
      '[RealtimeEventBus] ${event.type.name} id=${event.recordId ?? '-'}',
    );
    _controller.add(event);
  }
}
