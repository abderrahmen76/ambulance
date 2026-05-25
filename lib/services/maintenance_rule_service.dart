import '../config/constants.dart';
import '../models/maintenance_rule_model.dart';
import 'api_client.dart';
import 'app_memory_cache_service.dart';

class MaintenanceRuleService {
  static final MaintenanceRuleService _instance =
      MaintenanceRuleService._internal();
  final ApiClient _apiClient = ApiClient();

  factory MaintenanceRuleService() => _instance;

  MaintenanceRuleService._internal();

  Future<List<MaintenanceRule>> getRules(String tenantId) async {
    final cacheKey = 'rules:$tenantId';
    final rows = MaintenanceRulesCache.list.get(cacheKey) ??
        await _apiClient.get(
          SupabaseConfig.maintenanceRulesTable,
          filters: {'tenant_id': 'eq.$tenantId'},
          orderBy: 'maintenance_type.asc',
        );
    MaintenanceRulesCache.list.set(cacheKey, rows);
    return rows
        .map(
          (row) => MaintenanceRule.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<MaintenanceRule?> getRuleForType(
    String tenantId,
    String maintenanceType,
  ) async {
    final normalizedType = normalizeMaintenanceType(maintenanceType);
    if (tenantId.isEmpty || normalizedType.isEmpty) return null;
    final cacheKey = 'rule:$tenantId:$normalizedType';

    final cached = MaintenanceRulesCache.byType.get(cacheKey);
    if (cached != null) return MaintenanceRule.fromJson(cached);

    final rows = await _apiClient.get(
      SupabaseConfig.maintenanceRulesTable,
      filters: {
        'tenant_id': 'eq.$tenantId',
        'maintenance_type': 'eq.$normalizedType',
      },
      limit: 1,
    );

    if (rows.isEmpty) return null;
    MaintenanceRulesCache.byType.set(
      cacheKey,
      Map<String, dynamic>.from(rows.first as Map),
    );
    return MaintenanceRule.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<MaintenanceRule> saveRule({
    String? id,
    required String tenantId,
    required String maintenanceType,
    int? intervalKm,
    int? intervalDays,
    int? warningBeforeKm,
    int? warningBeforeDays,
    bool enabled = true,
  }) async {
    final normalizedType = normalizeMaintenanceType(maintenanceType);
    final body = <String, dynamic>{
      'tenant_id': tenantId,
      'maintenance_type': normalizedType,
      'interval_km': intervalKm,
      'interval_days': intervalDays,
      'warning_before_km': warningBeforeKm,
      'warning_before_days': warningBeforeDays,
      'enabled': enabled,
    };

    if (id != null && id.isNotEmpty) {
      await _apiClient.patch(
        '${SupabaseConfig.maintenanceRulesTable}?id=eq.$id',
        body,
      );
      _invalidateTenantRules(tenantId, normalizedType);
      return await getRuleForType(tenantId, normalizedType) ??
          MaintenanceRule.fromJson({'id': id, ...body});
    }

    final existing = await getRuleForType(tenantId, normalizedType);
    if (existing != null) {
      await _apiClient.patch(
        '${SupabaseConfig.maintenanceRulesTable}?id=eq.${existing.id}',
        body,
      );
      _invalidateTenantRules(tenantId, normalizedType);
      return await getRuleForType(tenantId, normalizedType) ??
          MaintenanceRule.fromJson({'id': existing.id, ...body});
    }

    await _apiClient.post(SupabaseConfig.maintenanceRulesTable, body);
    _invalidateTenantRules(tenantId, normalizedType);
    return await getRuleForType(tenantId, normalizedType) ??
        MaintenanceRule.fromJson(body);
  }

  Future<void> ensureRuleForType({
    required String tenantId,
    required String maintenanceType,
  }) async {
    final normalizedType = normalizeMaintenanceType(maintenanceType);
    if (tenantId.isEmpty || normalizedType.isEmpty) return;

    final existing = await getRuleForType(tenantId, normalizedType);
    if (existing != null) return;

    await saveRule(
      tenantId: tenantId,
      maintenanceType: normalizedType,
      enabled: true,
    );
  }

  Future<void> deleteRule(String id) async {
    await _apiClient.delete(SupabaseConfig.maintenanceRulesTable, id);
    MaintenanceRulesCache.list.clear();
    MaintenanceRulesCache.byType.clear();
  }

  void _invalidateTenantRules(String tenantId, String maintenanceType) {
    MaintenanceRulesCache.list.remove('rules:$tenantId');
    MaintenanceRulesCache.byType.remove('rule:$tenantId:$maintenanceType');
  }

  String normalizeMaintenanceType(String value) {
    final normalized = value.trim().toLowerCase();
    const aliases = {
      'vidange': 'oil change',
      'plaquettes de frein': 'brake pad replacement',
      'bougies': 'spark plugs',
      'pneus': 'tires',
      'liquide de frein': 'brake fluid',
      'urgent': 'urgent',
    };
    return aliases[normalized] ?? normalized;
  }
}
