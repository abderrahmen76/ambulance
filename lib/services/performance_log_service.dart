import 'package:flutter/foundation.dart';

class PerformanceLog {
  PerformanceLog._();

  static PerfTrace start(String label, {Map<String, Object?>? meta}) {
    final trace = PerfTrace._(label, meta);
    debugPrint('[PERF] START $label${_formatMeta(meta)}');
    return trace;
  }

  static void mark(String label, {Map<String, Object?>? meta}) {
    debugPrint('[PERF] MARK $label${_formatMeta(meta)}');
  }

  static String _formatMeta(Map<String, Object?>? meta) {
    if (meta == null || meta.isEmpty) return '';
    final entries = meta.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    return ' {$entries}';
  }
}

class PerfTrace {
  PerfTrace._(this.label, this.meta) : _stopwatch = Stopwatch()..start();

  final String label;
  final Map<String, Object?>? meta;
  final Stopwatch _stopwatch;

  void checkpoint(String name, {Map<String, Object?>? meta}) {
    debugPrint(
      '[PERF] STEP $label.$name ${_stopwatch.elapsedMilliseconds}ms'
      '${PerformanceLog._formatMeta(meta)}',
    );
  }

  void end({Map<String, Object?>? meta}) {
    _stopwatch.stop();
    debugPrint(
      '[PERF] END $label ${_stopwatch.elapsedMilliseconds}ms'
      '${PerformanceLog._formatMeta(meta)}',
    );
  }
}
