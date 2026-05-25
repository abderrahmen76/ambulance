import 'package:flutter/foundation.dart';

class MemoryCacheEntry<T> {
  MemoryCacheEntry({
    required this.value,
    required this.expiresAt,
  });

  final T value;
  final DateTime expiresAt;

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}

class TimedMemoryCache<T> {
  TimedMemoryCache(this.name, this.ttl);

  final String name;
  final Duration ttl;
  final Map<String, MemoryCacheEntry<T>> _entries = {};

  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;

    if (!entry.isFresh) {
      _entries.remove(key);
      debugPrint('[CACHE] $name expired key=$key');
      return null;
    }

    debugPrint('[CACHE] $name hit key=$key');
    return entry.value;
  }

  void set(String key, T value) {
    _entries[key] = MemoryCacheEntry<T>(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
    debugPrint('[CACHE] $name set key=$key ttl=${ttl.inSeconds}s');
  }

  void remove(String key) {
    _entries.remove(key);
  }

  void clear() {
    _entries.clear();
    debugPrint('[CACHE] $name cleared');
  }
}

class MissionListCache {
  static final TimedMemoryCache<List<dynamic>> instance =
      TimedMemoryCache<List<dynamic>>(
    'MissionListCache',
    const Duration(seconds: 45),
  );
}

class AmbulanceCache {
  static final TimedMemoryCache<List<dynamic>> list =
      TimedMemoryCache<List<dynamic>>(
    'AmbulanceCache',
    const Duration(seconds: 90),
  );

  static final TimedMemoryCache<Map<String, dynamic>> byId =
      TimedMemoryCache<Map<String, dynamic>>(
    'AmbulanceByIdCache',
    const Duration(seconds: 90),
  );
}

class CustomClinicsCache {
  static final TimedMemoryCache<List<String>> instance =
      TimedMemoryCache<List<String>>(
    'CustomClinicsCache',
    const Duration(minutes: 10),
  );
}

class TenantHeaderCache {
  static final TimedMemoryCache<Map<String, dynamic>> instance =
      TimedMemoryCache<Map<String, dynamic>>(
    'TenantHeaderCache',
    const Duration(minutes: 20),
  );
}

class MaintenanceRulesCache {
  static final TimedMemoryCache<List<dynamic>> list =
      TimedMemoryCache<List<dynamic>>(
    'MaintenanceRulesCache',
    const Duration(minutes: 20),
  );

  static final TimedMemoryCache<Map<String, dynamic>> byType =
      TimedMemoryCache<Map<String, dynamic>>(
    'MaintenanceRuleByTypeCache',
    const Duration(minutes: 20),
  );
}

class CompanyStaffCache {
  static final TimedMemoryCache<List<dynamic>> list =
      TimedMemoryCache<List<dynamic>>(
    'CompanyStaffCache',
    const Duration(minutes: 5),
  );
}

class MissionPhiMemoryCache {
  static final TimedMemoryCache<Map<String, dynamic>> single =
      TimedMemoryCache<Map<String, dynamic>>(
    'MissionPhiMemoryCache',
    const Duration(seconds: 30),
  );
}

class AppMemoryCacheService {
  static void clearOperationalCaches() {
    MissionListCache.instance.clear();
    AmbulanceCache.list.clear();
    AmbulanceCache.byId.clear();
    CustomClinicsCache.instance.clear();
    TenantHeaderCache.instance.clear();
    MaintenanceRulesCache.list.clear();
    MaintenanceRulesCache.byType.clear();
    CompanyStaffCache.list.clear();
  }

  static void clearPhiCache() {
    MissionPhiMemoryCache.single.clear();
  }

  static void clearAll() {
    clearOperationalCaches();
    clearPhiCache();
  }
}
