import 'package:flutter/foundation.dart';

class ResumeRefreshEvent {
  final String scope;
  final int activeTabIndex;
  final bool shouldRefreshVisibleImmediately;
  final Duration backgroundedFor;

  const ResumeRefreshEvent({
    required this.scope,
    required this.activeTabIndex,
    required this.shouldRefreshVisibleImmediately,
    required this.backgroundedFor,
  });
}

class ResumeRefreshService {
  static const shortResumeThreshold = Duration(minutes: 3);
  static final ValueNotifier<ResumeRefreshEvent?> events =
      ValueNotifier<ResumeRefreshEvent?>(null);

  static DateTime? _backgroundedAt;

  static void markBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  static ResumeRefreshEvent buildResumeEvent({
    required String scope,
    required int activeTabIndex,
  }) {
    final now = DateTime.now();
    final backgroundedFor = _backgroundedAt == null
        ? Duration.zero
        : now.difference(_backgroundedAt!);
    final event = ResumeRefreshEvent(
      scope: scope,
      activeTabIndex: activeTabIndex,
      shouldRefreshVisibleImmediately:
          backgroundedFor >= shortResumeThreshold || backgroundedFor.isNegative,
      backgroundedFor: backgroundedFor,
    );
    events.value = event;
    _backgroundedAt = null;
    return event;
  }
}
