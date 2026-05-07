import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../models/ambulance_model.dart';
import '../../models/maintenance_rule_model.dart';
import '../../models/user_model.dart';
import '../../services/api_client.dart';
import '../../services/company_staff_service.dart';
import '../../services/maintenance_rule_service.dart';
import '../../services/manager_onboarding_service.dart';

class ManagerSettingsScreenOptimized extends StatefulWidget {
  final User user;

  const ManagerSettingsScreenOptimized({required this.user, super.key});

  @override
  State<ManagerSettingsScreenOptimized> createState() =>
      _ManagerSettingsScreenOptimizedState();
}

class _ManagerSettingsScreenOptimizedState
    extends State<ManagerSettingsScreenOptimized> {
  final CompanyStaffService _companyStaffService = CompanyStaffService();
  final ManagerOnboardingService _managerOnboardingService =
      ManagerOnboardingService();
  final MaintenanceRuleService _maintenanceRuleService =
      MaintenanceRuleService();
  final ApiClient _apiClient = ApiClient();

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyDescriptionController =
      TextEditingController();
  final TextEditingController _companyPhonesController =
      TextEditingController();
  final TextEditingController _companyCityController = TextEditingController();
  final TextEditingController _companyAddressController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSavingCompany = false;
  bool _isBusy = false;

  List<User> _drivers = const [];
  List<Ambulance> _ambulances = const [];
  List<MaintenanceRule> _maintenanceRules = const [];

  String get _tenantId => widget.user.tenantId ?? '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyDescriptionController.dispose();
    _companyPhonesController.dispose();
    _companyCityController.dispose();
    _companyAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_tenantId.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final results = await Future.wait([
        _managerOnboardingService.getOnboardingState(),
        _companyStaffService.getCompanyDrivers(_tenantId),
        _apiClient.get(
          SupabaseConfig.ambulancesTable,
          filters: {'tenant_id': 'eq.$_tenantId'},
        ),
        _maintenanceRuleService.getRules(_tenantId),
      ]);

      final onboardingState = results[0] as Map<String, dynamic>;
      final drivers = results[1] as List<User>;
      final ambulanceRows = results[2] as List<Map<String, dynamic>>;
      final maintenanceRules = results[3] as List<MaintenanceRule>;

      final tenant = onboardingState['tenant'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              onboardingState['tenant'] as Map<String, dynamic>,
            )
          : onboardingState['tenant'] is Map
          ? Map<String, dynamic>.from(onboardingState['tenant'] as Map)
          : null;
      final ambulances = ambulanceRows.map(Ambulance.fromJson).toList();

      _drivers = drivers;
      _ambulances = ambulances;
      _maintenanceRules = maintenanceRules;
      _hydrateCompanyControllers(tenant);
    } catch (e) {
      _showSnackBar('Erreur lors du chargement des paramètres: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _hydrateCompanyControllers(Map<String, dynamic>? tenant) {
    final metadata = _readMetadata(tenant?['metadata']);
    final phoneNumbers = _readMetadataStringList(
      metadata,
      'company_phone_numbers',
    );
    final fallbackPhone = _readMetadataString(metadata, 'company_phone');

    _companyNameController.text = tenant?['name']?.toString() ?? '';
    _companyDescriptionController.text =
        tenant?['description']?.toString() ?? '';
    _companyPhonesController.text = phoneNumbers.isNotEmpty
        ? phoneNumbers.join('\n')
        : fallbackPhone;
    _companyCityController.text = _readMetadataString(metadata, 'company_city');
    _companyAddressController.text = _readMetadataString(
      metadata,
      'company_address',
    );
  }

  Map<String, dynamic> _readMetadata(dynamic rawMetadata) {
    if (rawMetadata is Map<String, dynamic>) {
      return Map<String, dynamic>.from(rawMetadata);
    }
    if (rawMetadata is Map) {
      return Map<String, dynamic>.from(rawMetadata);
    }
    if (rawMetadata is String && rawMetadata.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMetadata);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  List<String> _readMetadataStringList(
    Map<String, dynamic> metadata,
    String key,
  ) {
    final raw = metadata[key];
    if (raw is List) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[\n,;]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _readMetadataString(Map<String, dynamic> metadata, String key) {
    final value = metadata[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  List<String> _parsePhoneNumbers(String rawValue) {
    return rawValue
        .split(RegExp(r'[\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _saveCompanyValues() async {
    if (_tenantId.isEmpty) {
      _showSnackBar('Aucun tenant trouvé pour ce manager.');
      return;
    }

    final name = _companyNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Le nom de la société est obligatoire.');
      return;
    }

    setState(() => _isSavingCompany = true);

    try {
      final phones = _parsePhoneNumbers(_companyPhonesController.text);

      await _managerOnboardingService.updateCompanyValues(
        companyName: name,
        companyDescription: _companyDescriptionController.text.trim(),
        companyPhones: phones,
        companyCity: _companyCityController.text.trim(),
        companyAddress: _companyAddressController.text.trim(),
      );

      await _loadData();
      _showSnackBar('Valeurs de la société mises à jour.');
    } catch (e) {
      _showSnackBar('Erreur lors de la sauvegarde: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingCompany = false);
      }
    }
  }

  Future<void> _showDriverDialog({User? driver}) async {
    final isEdit = driver != null;
    final nameController = TextEditingController(text: driver?.name ?? '');
    final emailController = TextEditingController(text: driver?.email ?? '');
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEdit ? 'Modifier le chauffeur' : 'Ajouter un chauffeur',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: isEdit
                            ? 'Nouveau mot de passe'
                            : 'Mot de passe',
                        hintText: isEdit
                            ? 'Laisser vide pour garder le mot de passe actuel'
                            : null,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();
                    final password = passwordController.text.trim();

                    if (name.isEmpty || email.isEmpty) {
                      _showSnackBar('Nom et email sont obligatoires.');
                      return;
                    }

                    if (!isEdit && password.isEmpty) {
                      _showSnackBar('Le mot de passe est obligatoire.');
                      return;
                    }

                    Navigator.of(context).pop();

                    try {
                      setState(() => _isBusy = true);
                      if (isEdit) {
                        await _managerOnboardingService.updateDriver(
                          driverId: driver.id,
                          driverName: name,
                          driverEmail: email,
                        );
                        if (password.isNotEmpty) {
                          await _managerOnboardingService.updateDriverPassword(
                            driverId: driver.id,
                            newPassword: password,
                          );
                        }
                      } else {
                        await _managerOnboardingService.addDriver(
                          driverName: name,
                          driverEmail: email,
                          driverPassword: password,
                        );
                      }

                      await _loadData();
                      _showSnackBar(
                        isEdit
                            ? 'Chauffeur mis à jour.'
                            : 'Chauffeur créé avec succès.',
                      );
                    } catch (e) {
                      _showSnackBar('Erreur chauffeur: $e');
                    } finally {
                      if (mounted) {
                        setState(() => _isBusy = false);
                      }
                    }
                  },
                  child: Text(isEdit ? 'Enregistrer' : 'Créer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteDriver(User driver) async {
    final confirmed = await _showDeleteConfirmation(
      title: 'Supprimer ce chauffeur ?',
      message: driver.name,
    );
    if (!confirmed) return;

    try {
      setState(() => _isBusy = true);
      await _managerOnboardingService.deleteDriver(driverId: driver.id);
      await _loadData();
      _showSnackBar('Chauffeur supprimé.');
    } catch (e) {
      _showSnackBar('Erreur suppression chauffeur: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showAmbulanceDialog({Ambulance? ambulance}) async {
    final isEdit = ambulance != null;
    final numberController = TextEditingController(
      text: ambulance?.ambulanceNumber ?? '',
    );
    final phoneController = TextEditingController(
      text: ambulance?.telephone ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Modifier l’ambulance' : 'Ajouter une ambulance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Numéro ambulance',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ambulanceNumber = numberController.text.trim();
              final telephone = phoneController.text.trim();

              if (ambulanceNumber.isEmpty) {
                _showSnackBar('Le numéro de l’ambulance est obligatoire.');
                return;
              }

              Navigator.of(context).pop();

              try {
                setState(() => _isBusy = true);
                if (isEdit) {
                  await _managerOnboardingService.updateAmbulance(
                    ambulanceId: ambulance.id,
                    ambulanceNumber: ambulanceNumber,
                    telephone: telephone,
                  );
                } else {
                  await _managerOnboardingService.addAmbulance(
                    ambulanceNumber: ambulanceNumber,
                    telephone: telephone,
                  );
                }

                await _loadData();
                _showSnackBar(
                  isEdit
                      ? 'Ambulance mise à jour.'
                      : 'Ambulance créée avec succès.',
                );
              } catch (e) {
                _showSnackBar('Erreur ambulance: $e');
              } finally {
                if (mounted) {
                  setState(() => _isBusy = false);
                }
              }
            },
            child: Text(isEdit ? 'Enregistrer' : 'Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAmbulance(Ambulance ambulance) async {
    final confirmed = await _showDeleteConfirmation(
      title: 'Supprimer cette ambulance ?',
      message: ambulance.ambulanceNumber,
    );
    if (!confirmed) return;

    try {
      setState(() => _isBusy = true);
      await _managerOnboardingService.deleteAmbulance(
        ambulanceId: ambulance.id,
      );
      await _loadData();
      _showSnackBar('Ambulance supprimée.');
    } catch (e) {
      _showSnackBar('Erreur suppression ambulance: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showMaintenanceRuleDialog({MaintenanceRule? rule}) async {
    final isEdit = rule != null;
    const maintenanceTypes = [
      'Vidange',
      'Plaquettes de Frein',
      'Bougies',
      'Pneus',
      'Liquide de Frein',
      'Urgent',
      'Autre',
    ];
    const storedTypeToFrench = {
      'oil change': 'Vidange',
      'brake pad replacement': 'Plaquettes de Frein',
      'spark plugs': 'Bougies',
      'tires': 'Pneus',
      'brake fluid': 'Liquide de Frein',
      'urgent': 'Urgent',
    };
    const frenchTypeToStored = {
      'Vidange': 'oil change',
      'Plaquettes de Frein': 'brake pad replacement',
      'Bougies': 'spark plugs',
      'Pneus': 'tires',
      'Liquide de Frein': 'brake fluid',
      'Urgent': 'urgent',
    };
    final existingType = rule?.maintenanceType.trim().toLowerCase() ?? '';
    String selectedType =
        storedTypeToFrench[existingType] ??
        (maintenanceTypes.contains(rule?.maintenanceType)
            ? rule!.maintenanceType
            : 'Autre');
    final customTypeController = TextEditingController(
      text: selectedType == 'Autre' ? rule?.maintenanceType ?? '' : '',
    );
    final intervalKmController = TextEditingController(
      text: rule?.intervalKm?.toString() ?? '',
    );
    final intervalDaysController = TextEditingController(
      text: rule?.intervalDays?.toString() ?? '',
    );
    final warningKmController = TextEditingController(
      text: rule?.warningBeforeKm?.toString() ?? '',
    );
    final warningDaysController = TextEditingController(
      text: rule?.warningBeforeDays?.toString() ?? '',
    );
    bool enabled = rule?.enabled ?? true;

    int? parseOptionalInt(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Modifier la règle' : 'Ajouter une règle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'entretien',
                    border: OutlineInputBorder(),
                  ),
                  items: maintenanceTypes
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedType = value);
                  },
                ),
                if (selectedType == 'Autre') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Type personnalisé',
                      hintText: 'Ex: courroie, batterie...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: intervalKmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Intervalle km',
                    hintText: 'Ex: 10000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: intervalDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Intervalle jours',
                    hintText: 'Laisser vide si non utilisé',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: warningKmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Alerte avant km',
                    hintText: 'Ex: 1000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: warningDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Alerte avant jours',
                    hintText: 'Ex: 15',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Règle active'),
                  value: enabled,
                  onChanged: (value) {
                    setDialogState(() => enabled = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final type = selectedType == 'Autre'
                    ? customTypeController.text.trim()
                    : frenchTypeToStored[selectedType] ?? selectedType;
                if (type.isEmpty) {
                  _showSnackBar('Le type d\'entretien est obligatoire.');
                  return;
                }

                Navigator.of(context).pop();
                try {
                  setState(() => _isBusy = true);
                  await _maintenanceRuleService.saveRule(
                    id: rule?.id,
                    tenantId: _tenantId,
                    maintenanceType: type,
                    intervalKm: parseOptionalInt(intervalKmController.text),
                    intervalDays: parseOptionalInt(intervalDaysController.text),
                    warningBeforeKm: parseOptionalInt(warningKmController.text),
                    warningBeforeDays: parseOptionalInt(
                      warningDaysController.text,
                    ),
                    enabled: enabled,
                  );
                  await _loadData();
                  _showSnackBar('Règle d\'entretien enregistrée.');
                } catch (e) {
                  _showSnackBar('Erreur règle d\'entretien: $e');
                } finally {
                  if (mounted) {
                    setState(() => _isBusy = false);
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMaintenanceRule(MaintenanceRule rule) async {
    final confirmed = await _showDeleteConfirmation(
      title: 'Supprimer cette règle ?',
      message: rule.maintenanceType,
    );
    if (!confirmed) return;

    try {
      setState(() => _isBusy = true);
      await _maintenanceRuleService.deleteRule(rule.id);
      await _loadData();
      _showSnackBar('Règle supprimée.');
    } catch (e) {
      _showSnackBar('Erreur suppression règle: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  String _formatMaintenanceRuleType(String type) {
    const labels = {
      'oil change': 'Vidange',
      'brake pad replacement': 'Plaquettes de Frein',
      'spark plugs': 'Bougies',
      'tires': 'Pneus',
      'brake fluid': 'Liquide de Frein',
      'urgent': 'Urgent',
    };
    return labels[type.trim().toLowerCase()] ?? type;
  }

  String _formatRoleLabel(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'driver':
        return 'Chauffeur';
      case 'manager':
        return 'Manager';
      case 'admin':
        return 'Administrateur';
      default:
        return role?.trim().isNotEmpty == true ? role!.trim() : 'Chauffeur';
    }
  }

  Future<bool> _showDeleteConfirmation({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_tenantId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paramètres')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Ce manager n’est lié à aucune société.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCompanySection(),
                const SizedBox(height: 16),
                _buildDriversSection(),
                const SizedBox(height: 16),
                _buildAmbulancesSection(),
                const SizedBox(height: 16),
                _buildMaintenanceRulesSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          if (_isBusy)
            Container(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCompanySection() {
    return _buildSectionCard(
      title: 'Informations de la société',
      subtitle: 'Modifiez les informations principales de la société.',
      trailing: ElevatedButton.icon(
        onPressed: _isSavingCompany ? null : _saveCompanyValues,
        icon: _isSavingCompany
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: const Text('Enregistrer'),
      ),
      child: Column(
        children: [
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Nom de la société',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyDescriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyPhonesController,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphones',
              hintText: 'Un numéro par ligne',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyCityController,
            decoration: const InputDecoration(
              labelText: 'Ville',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyAddressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Adresse',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversSection() {
    return _buildSectionCard(
      title: 'Gestion des chauffeurs',
      subtitle: 'Ajoutez, modifiez et supprimez les profils chauffeurs.',
      trailing: ElevatedButton.icon(
        onPressed: () => _showDriverDialog(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Ajouter'),
      ),
      child: _drivers.isEmpty
          ? const _EmptySectionMessage(message: 'Aucun chauffeur trouvé.')
          : Column(
              children: _drivers
                  .map(
                    (driver) => _SimpleListTileCard(
                      title: driver.name,
                      subtitle: driver.email,
                      extra: _formatRoleLabel(driver.roleLabel ?? driver.role),
                      onEdit: () => _showDriverDialog(driver: driver),
                      onDelete: () => _deleteDriver(driver),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildAmbulancesSection() {
    return _buildSectionCard(
      title: 'Gestion des ambulances',
      subtitle: 'Ajoutez, modifiez et supprimez les ambulances.',
      trailing: ElevatedButton.icon(
        onPressed: () => _showAmbulanceDialog(),
        icon: const Icon(Icons.add_road_outlined),
        label: const Text('Ajouter'),
      ),
      child: _ambulances.isEmpty
          ? const _EmptySectionMessage(message: 'Aucune ambulance trouvée.')
          : Column(
              children: _ambulances
                  .map(
                    (ambulance) => _SimpleListTileCard(
                      title: ambulance.ambulanceNumber,
                      subtitle: ambulance.telephone?.trim().isNotEmpty == true
                          ? ambulance.telephone!
                          : 'Téléphone non renseigné',
                      extra: ambulance.kilometrage != null
                          ? '${ambulance.kilometrage!.toStringAsFixed(0)} km'
                          : null,
                      onEdit: () => _showAmbulanceDialog(ambulance: ambulance),
                      onDelete: () => _deleteAmbulance(ambulance),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildMaintenanceRulesSection() {
    return _buildSectionCard(
      title: 'Règles d\'entretien',
      subtitle:
          'Définissez les prévisions par type: km, jours et seuils d\'alerte.',
      trailing: ElevatedButton.icon(
        onPressed: () => _showMaintenanceRuleDialog(),
        icon: const Icon(Icons.rule_folder_outlined),
        label: const Text('Ajouter'),
      ),
      child: _maintenanceRules.isEmpty
          ? const _EmptySectionMessage(
              message:
                  'Aucune règle définie. Un type sans règle n\'a pas de condition.',
            )
          : Column(
              children: _maintenanceRules.map((rule) {
                final intervals = <String>[
                  if (rule.intervalKm != null) '${rule.intervalKm} km',
                  if (rule.intervalDays != null) '${rule.intervalDays} jours',
                ];
                final warnings = <String>[
                  if (rule.warningBeforeKm != null)
                    'alerte ${rule.warningBeforeKm} km',
                  if (rule.warningBeforeDays != null)
                    'alerte ${rule.warningBeforeDays} jours',
                ];
                final subtitle = intervals.isEmpty
                    ? 'Aucune condition'
                    : intervals.join(' / ');
                final extra = [
                  if (warnings.isNotEmpty) warnings.join(' / '),
                  rule.enabled ? 'Active' : 'Inactive',
                ].join(' • ');

                return _SimpleListTileCard(
                  title: _formatMaintenanceRuleType(rule.maintenanceType),
                  subtitle: subtitle,
                  extra: extra,
                  onEdit: () => _showMaintenanceRuleDialog(rule: rule),
                  onDelete: () => _deleteMaintenanceRule(rule),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SimpleListTileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? extra;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SimpleListTileCard({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (extra != null && extra!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    extra!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  final String message;

  const _EmptySectionMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }
}
