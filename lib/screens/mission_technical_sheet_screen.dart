import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/mission_model.dart';
import '../services/mission_private_service.dart';
import '../services/mission_service.dart';
import '../services/screen_protection_service.dart';
import '../utils/responsive.dart';

class MissionTechnicalSheetScreen extends StatefulWidget {
  final Mission mission;

  const MissionTechnicalSheetScreen({
    Key? key,
    required this.mission,
  }) : super(key: key);

  @override
  State<MissionTechnicalSheetScreen> createState() =>
      _MissionTechnicalSheetScreenState();
}

class _MissionTechnicalSheetScreenState
    extends State<MissionTechnicalSheetScreen> {
  final MissionService _missionService = MissionService();
  final MissionPrivateService _missionPrivateService = MissionPrivateService();
  final ScreenProtectionService _screenProtectionService =
      ScreenProtectionService();
  late TextEditingController _patientNameController;
  late TextEditingController _ageController;
  String? _selectedMotifTransport;
  List<String> defaultMotifTransportOptions = [
    'urgence',
    'IRM',
    'scanner',
    'coro',
    'alerte thrombolyse',
    'transfert',
    'dialyse',
    'deces',
    'scintigraphie',
    'oxygenotherapie',
    'autre',
  ];
  List<String> customMotifTransportOptions = [];
  late TextEditingController _taBeforeController;
  late TextEditingController _taAfterController;
  late TextEditingController _fcBeforeController;
  late TextEditingController _fcAfterController;
  late TextEditingController _frBeforeController;
  late TextEditingController _frAfterController;
  late TextEditingController _temperatureBeforeController;
  late TextEditingController _temperatureAfterController;
  late TextEditingController _glucoseBeforeController;
  late TextEditingController _glucoseAfterController;
  late TextEditingController _spo2BeforeController;
  late TextEditingController _spo2AfterController;

  String _reportType = 'simple_transport';

  // Default options for medical history
  final defaultMedicalHistoryOptions = [
    ('Diabétique', 'diabetic'),
    ('HTA', 'hta'),
    ('Douleur Thoracique', 'douleur_thoracique'),
    ('Dialyse', 'dialysis'),
    ('Détresse Respiratoire', 'distresse_respiratoire'),
    ('Hypotension', 'hypalepsie'),
    ('Maladie Coronarienne', 'coronaria'),
    ('Cardiaque', 'cardiaque'),
    ('BPCO', 'bpco'),
    ('Asthme', 'asthme'),
    ('Épilepsie', 'epilepsie'),
  ];

  // Default options for patient needs
  final defaultPatientNeedsOptions = [
    ('Oxygène', 'oxygen'),
    ('Perfusion', 'perfusion'),
    ('Monitorage', 'monitorage'),
    ('Pansement', 'pensement'),
    ('Immobilisation', 'immobilisation'),
    ('F.C (bh/mm)', 'fc_bh'),
    ('PAS/PAD (mmhg)', 'pas_pad'),
    ('SaO2 (%)', 'sao2'),
    ('Dextro (g/l)', 'destro'),
    ('VNI', 'vni'),
    ('VC', 'vc'),
    ('PSE', 'pse'),
  ];

  // Nested options for special patient needs
  final Map<String, List<String>> nestedPatientNeedsOptions = {
    'vni': ['pep', 'aide', 'FR', 'VCC'],
    'vc': ['courant', 'FR', 'PEP'],
    'pse': ['noradé', 'adré', 'sedation', 'heparine', 'rivotril'],
  };

  // Map to store selected sub-options: key=needId, value=subOption
  Map<String, String?> selectedNestedOptions = {
    'vni': null,
    'vc': null,
    'pse': null,
  };

  // Checkbox states - key is item label, value is checked
  Map<String, bool> medicalHistoryChecked = {};
  Map<String, TextEditingController> patientNeedsState = {};

  // Nested quantities for VNI and VC (no parent quantity)
  // Key=needId (vni/vc), Value=Map<optionName, TextEditingController>
  Map<String, Map<String, TextEditingController>> nestedQuantities = {
    'vni': {},
    'vc': {},
    'pse': {},
  };

  // Time inputs for PSE sub-options only
  // Key=optionName, Value=TextEditingController (time in format "48 hours", "2 days", etc)
  Map<String, TextEditingController> pseTimeInputs = {};

  // Custom items added by user (persisted)
  List<String> customMedicalHistoryItems = [];
  List<String> customPatientNeedsItems = [];

  bool _isLoading = false;
  bool _isSendingToClinic = false;
  List<Map<String, String>> _linkedClinics = [];
  String? _selectedClinicTenantId;

  late Mission _currentMission;

  @override
  void initState() {
    super.initState();
    _currentMission = widget.mission;
    _initializeControllers();
    _refreshMissionData();
    _loadLinkedClinics();
    _screenProtectionService.enable();
  }

  void _initializeControllers() {
    // Combine first and last name into one field, with fallback to patient_name
    String fullName = '';
    if ((_currentMission.patientFirstName != null &&
            _currentMission.patientFirstName!.isNotEmpty) ||
        (_currentMission.patientLastName != null &&
            _currentMission.patientLastName!.isNotEmpty)) {
      fullName =
          '${_currentMission.patientFirstName ?? ''} ${_currentMission.patientLastName ?? ''}'
              .trim();
    } else if (_currentMission.patientName != null) {
      fullName = _currentMission.patientName!;
    }
    _patientNameController = TextEditingController(text: fullName);
    _ageController = TextEditingController(
        text: _currentMission.patientAge?.toString() ?? '');
    _taBeforeController = TextEditingController();
    _taAfterController = TextEditingController();
    _fcBeforeController = TextEditingController();
    _fcAfterController = TextEditingController();
    _frBeforeController = TextEditingController();
    _frAfterController = TextEditingController();
    _temperatureBeforeController = TextEditingController();
    _temperatureAfterController = TextEditingController();
    _glucoseBeforeController = TextEditingController();
    _glucoseAfterController = TextEditingController();
    _spo2BeforeController = TextEditingController();
    _spo2AfterController = TextEditingController();

    _loadExistingData();
    _loadCustomMotifTransportOptions();
  }

  Future<void> _refreshMissionData() async {
    try {
      debugPrint('[MissionTechnicalSheet] Refreshing mission data...');
      // Fetch fresh mission data from Supabase
      final freshMission =
          await _missionService.getMissionById(_currentMission.id);
      final privatePayload =
          await _missionPrivateService.getMissionPrivateData(_currentMission.id);
      debugPrint(
          '[MissionTechnicalSheet] Fresh mission fetched: ${freshMission?.id}');
      if (freshMission != null && mounted) {
        final mergedMission =
            _mergeMissionWithPrivatePayload(freshMission, privatePayload);
        setState(() {
          _currentMission = mergedMission;
          debugPrint(
              '[MissionTechnicalSheet] Vital Signs Raw: ${_currentMission.vitalSigns}');
          debugPrint(
              '[MissionTechnicalSheet] Patient Needs Raw: ${_currentMission.patientNeeds}');
          // Clear existing controllers and reload
          _patientNameController.clear();
          _ageController.clear();
          _selectedMotifTransport = null;
          _taBeforeController.clear();
          _taAfterController.clear();
          _spo2BeforeController.clear();
          _spo2AfterController.clear();
          _fcBeforeController.clear();
          _fcAfterController.clear();
          _frBeforeController.clear();
          _frAfterController.clear();
          _temperatureBeforeController.clear();
          _temperatureAfterController.clear();
          _glucoseBeforeController.clear();
          _glucoseAfterController.clear();
          medicalHistoryChecked.clear();
          patientNeedsState.clear();
          customMedicalHistoryItems.clear();
          customPatientNeedsItems.clear();
          customMotifTransportOptions.clear();

          _loadExistingData();
          _loadCustomMotifTransportOptions();
        });
      }
    } catch (e) {
      debugPrint('[MissionTechnicalSheet] Error refreshing mission data: $e');
    }
  }

  Mission _mergeMissionWithPrivatePayload(
    Mission mission,
    Map<String, dynamic> payload,
  ) {
    final contact = payload['contact'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['contact'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final medical = payload['medical'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['medical'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final mergedJson = mission.toJson();

    if (contact.isNotEmpty) {
      mergedJson['patient_name'] = contact['patient_name'] ?? mergedJson['patient_name'];
      mergedJson['patient_first_name'] =
          contact['patient_first_name'] ?? mergedJson['patient_first_name'];
      mergedJson['patient_last_name'] =
          contact['patient_last_name'] ?? mergedJson['patient_last_name'];
      mergedJson['patient_phone'] = contact['patient_phone'] ?? mergedJson['patient_phone'];
      mergedJson['patient_age'] = contact['patient_age'] ?? mergedJson['patient_age'];
      mergedJson['pickup_address'] = contact['pickup_address'] ?? mergedJson['pickup_address'];
      mergedJson['destination_address'] =
          contact['destination_address'] ?? mergedJson['destination_address'];
      mergedJson['pickup_lat'] = contact['pickup_lat'] ?? mergedJson['pickup_lat'];
      mergedJson['pickup_lng'] = contact['pickup_lng'] ?? mergedJson['pickup_lng'];
      mergedJson['destination_lat'] =
          contact['destination_lat'] ?? mergedJson['destination_lat'];
      mergedJson['destination_lng'] =
          contact['destination_lng'] ?? mergedJson['destination_lng'];
    }

    if (medical.isNotEmpty) {
      mergedJson['report_type'] = medical['report_type'] ?? mergedJson['report_type'];
      mergedJson['fractures_injuries'] =
          medical['fractures_injuries'] ?? mergedJson['fractures_injuries'];
      mergedJson['report_filled_at'] =
          medical['report_filled_at'] ?? mergedJson['report_filled_at'];
      mergedJson['medical_history'] =
          medical['medical_history'] ?? mergedJson['medical_history'];
      mergedJson['vital_signs'] = medical['vital_signs'] ?? mergedJson['vital_signs'];
      mergedJson['patient_needs'] = medical['patient_needs'] ?? mergedJson['patient_needs'];
    }

    return Mission.fromJson(mergedJson);
  }

  Future<void> _loadLinkedClinics() async {
    try {
      final clinics = await _missionService.getLinkedClinicsForCurrentProvider();
      if (!mounted) {
        return;
      }
      setState(() {
        _linkedClinics = clinics;
        if (_selectedClinicTenantId == null && clinics.isNotEmpty) {
          _selectedClinicTenantId = clinics.first['tenant_id'];
        }
      });
    } catch (e) {
      debugPrint('[MissionTechnicalSheet] Error loading linked clinics: $e');
    }
  }

  void _loadExistingData() {
    debugPrint('[MissionTechnicalSheet] === Starting _loadExistingData ===');
    // Load patient name and age
    String fullName = '';
    if ((_currentMission.patientFirstName != null &&
            _currentMission.patientFirstName!.isNotEmpty) ||
        (_currentMission.patientLastName != null &&
            _currentMission.patientLastName!.isNotEmpty)) {
      fullName =
          '${_currentMission.patientFirstName ?? ''} ${_currentMission.patientLastName ?? ''}'
              .trim();
    } else if (_currentMission.patientName != null) {
      fullName = _currentMission.patientName!;
    }
    _patientNameController.text = fullName;
    _ageController.text = _currentMission.patientAge?.toString() ?? '';
    debugPrint(
        '[MissionTechnicalSheet] Patient Name: $fullName, Age: ${_currentMission.patientAge}');

    // Load existing vital signs
    debugPrint(
        '[MissionTechnicalSheet] Vital Signs is null: ${_currentMission.vitalSigns == null}');
    debugPrint(
        '[MissionTechnicalSheet] Vital Signs isEmpty: ${_currentMission.vitalSigns?.isEmpty}');
    debugPrint(
        '[MissionTechnicalSheet] Vital Signs type: ${_currentMission.vitalSigns.runtimeType}');
    if (_currentMission.vitalSigns != null &&
        _currentMission.vitalSigns!.isNotEmpty) {
      try {
        dynamic vitalSignsData = _currentMission.vitalSigns!;
        debugPrint('[MissionTechnicalSheet] Raw vital signs: $vitalSignsData');
        debugPrint(
            '[MissionTechnicalSheet] Vital signs is String: ${vitalSignsData is String}');

        // If it's a string, decode it (JSON stored as string)
        if (vitalSignsData is String) {
          debugPrint('[MissionTechnicalSheet] Decoding vital signs string...');
          vitalSignsData = jsonDecode(vitalSignsData);
          debugPrint('[MissionTechnicalSheet] After decode: $vitalSignsData');
        }

        debugPrint(
            '[MissionTechnicalSheet] Vital signs is Map: ${vitalSignsData is Map<String, dynamic>}');
        if (vitalSignsData is Map<String, dynamic>) {
          _taBeforeController.text =
              vitalSignsData['ta_before']?.toString() ?? '';
          _taAfterController.text =
              vitalSignsData['ta_after']?.toString() ?? '';
          _fcBeforeController.text =
              vitalSignsData['fc_before']?.toString() ?? '';
          _fcAfterController.text =
              vitalSignsData['fc_after']?.toString() ?? '';
          _frBeforeController.text =
              vitalSignsData['fr_before']?.toString() ?? '';
          _frAfterController.text =
              vitalSignsData['fr_after']?.toString() ?? '';
          _temperatureBeforeController.text =
              vitalSignsData['temperature_before']?.toString() ?? '';
          _temperatureAfterController.text =
              vitalSignsData['temperature_after']?.toString() ?? '';
          _glucoseBeforeController.text =
              vitalSignsData['glucose_before']?.toString() ?? '';
          _glucoseAfterController.text =
              vitalSignsData['glucose_after']?.toString() ?? '';
          _spo2BeforeController.text =
              vitalSignsData['spo2_before']?.toString() ?? '';
          _spo2AfterController.text =
              vitalSignsData['spo2_after']?.toString() ?? '';
          debugPrint(
              '[MissionTechnicalSheet] Vital signs loaded: TA_BEFORE=${_taBeforeController.text}, TA_AFTER=${_taAfterController.text}, FC_BEFORE=${_fcBeforeController.text}, FC_AFTER=${_fcAfterController.text}, FR_BEFORE=${_frBeforeController.text}, FR_AFTER=${_frAfterController.text}, TEMP_BEFORE=${_temperatureBeforeController.text}, TEMP_AFTER=${_temperatureAfterController.text}, GLUCOSE_BEFORE=${_glucoseBeforeController.text}, GLUCOSE_AFTER=${_glucoseAfterController.text}, SPO2_BEFORE=${_spo2BeforeController.text}, SPO2_AFTER=${_spo2AfterController.text}');
        }
      } catch (e) {
        debugPrint('[MissionTechnicalSheet] Error loading vital signs: $e');
      }
    } else {
      debugPrint('[MissionTechnicalSheet] Vital signs is null or empty');
    }

    // Initialize medical history checkboxes (all unchecked)
    for (var option in defaultMedicalHistoryOptions) {
      medicalHistoryChecked[option.$1] = false;
    }

    // Load existing medical history from database
    if (_currentMission.medicalHistory != null &&
        _currentMission.medicalHistory!.isNotEmpty) {
      try {
        dynamic historyData = _currentMission.medicalHistory!;

        // If it's a string, decode it (JSON stored as string)
        if (historyData is String) {
          historyData = jsonDecode(historyData);
        }

        if (historyData is List) {
          final historyList = List<String>.from(historyData as List<dynamic>);

          // Mark checked items from database
          for (var item in historyList) {
            bool isDefault =
                defaultMedicalHistoryOptions.any((opt) => opt.$1 == item);
            if (isDefault) {
              medicalHistoryChecked[item] = true;
            } else {
              // Custom medical history item
              if (!customMedicalHistoryItems.contains(item)) {
                customMedicalHistoryItems.add(item);
              }
              medicalHistoryChecked[item] = true;
            }
          }
        }
      } catch (e) {
        debugPrint('[MissionTechnicalSheet] Error loading medical history: $e');
      }
    }

    // Initialize patient needs checkboxes (all with quantity 0)
    debugPrint('[MissionTechnicalSheet] Initializing default patient needs...');
    for (var option in defaultPatientNeedsOptions) {
      final label = option.$1;
      final needId = option.$2;

      // For VNI and VC: don't initialize parent, only nested
      if (needId == 'vni' || needId == 'vc') {
        // Initialize nested quantity controllers
        for (var nestedOption in nestedPatientNeedsOptions[needId] ?? []) {
          nestedQuantities[needId]![nestedOption] =
              TextEditingController(text: '0');
        }
      } else if (needId == 'pse') {
        // Initialize parent quantity for PSE
        patientNeedsState[label] = TextEditingController(text: '0');
        // Initialize nested quantity and time controllers
        for (var nestedOption in nestedPatientNeedsOptions[needId] ?? []) {
          nestedQuantities[needId]![nestedOption] =
              TextEditingController(text: '0');
          pseTimeInputs[nestedOption] = TextEditingController(text: '');
        }
      } else {
        // Regular items with quantity
        patientNeedsState[label] = TextEditingController(text: '0');
      }
    }
    debugPrint(
        '[MissionTechnicalSheet] Patient needs state initialized: ${patientNeedsState.keys.toList()}');

    // Load existing patient needs
    debugPrint(
        '[MissionTechnicalSheet] Patient needs is null: ${_currentMission.patientNeeds == null}');
    debugPrint(
        '[MissionTechnicalSheet] Patient needs isEmpty: ${_currentMission.patientNeeds?.isEmpty}');
    debugPrint(
        '[MissionTechnicalSheet] Patient needs type: ${_currentMission.patientNeeds.runtimeType}');
    if (_currentMission.patientNeeds != null &&
        _currentMission.patientNeeds!.isNotEmpty) {
      try {
        dynamic needsData = _currentMission.patientNeeds!;
        debugPrint('[MissionTechnicalSheet] Raw patient needs: $needsData');

        // Handle double-encoded JSON strings
        // Keep decoding until we get the actual data structure
        int decodeCount = 0;
        while (needsData is String && needsData.isNotEmpty) {
          try {
            decodeCount++;
            debugPrint(
                '[MissionTechnicalSheet] Decode attempt $decodeCount...');
            needsData = jsonDecode(needsData);
            debugPrint(
                '[MissionTechnicalSheet] After decode $decodeCount: $needsData');
          } catch (e) {
            // If decode fails, it's not JSON - break out
            debugPrint(
                '[MissionTechnicalSheet] Decode failed at attempt $decodeCount: $e');
            break;
          }
        }
        debugPrint(
            '[MissionTechnicalSheet] Final patient needs data type: ${needsData.runtimeType}');
        debugPrint('[MissionTechnicalSheet] Final patient needs: $needsData');

        if (needsData is List) {
          debugPrint(
              '[MissionTechnicalSheet] Processing patient needs as List with ${needsData.length} items');
          for (var item in needsData) {
            if (item is Map<String, dynamic>) {
              final needName = item['name'] as String?;
              final quantity = item['quantity']?.toString() ?? '0';
              final children = item['children'] as List? ?? [];
              debugPrint(
                  '[MissionTechnicalSheet] Processing need: $needName with quantity: $quantity, children: ${children.length}');

              if (needName != null && needName.isNotEmpty) {
                bool isDefault =
                    defaultPatientNeedsOptions.any((opt) => opt.$1 == needName);

                if (isDefault) {
                  final option = defaultPatientNeedsOptions.firstWhere(
                    (opt) => opt.$1 == needName,
                    orElse: () => ('', ''),
                  );
                  final needId = option.$2;

                  // Handle VNI and VC: only children, no parent quantity
                  if (needId == 'vni' || needId == 'vc') {
                    // Process children with quantities only
                    if (children.isNotEmpty) {
                      for (var child in children) {
                        if (child is Map<String, dynamic>) {
                          final childName = child['name'] as String?;
                          final childQty = child['quantity']?.toString() ?? '0';
                          if (childName != null &&
                              nestedQuantities[needId]!
                                  .containsKey(childName)) {
                            nestedQuantities[needId]![childName]!.text =
                                childQty;
                          }
                        }
                      }
                    }
                  } else if (needId == 'pse') {
                    // Handle PSE: parent quantity + children with quantity and time
                    patientNeedsState[needName]!.text = quantity;
                    if (children.isNotEmpty) {
                      for (var child in children) {
                        if (child is Map<String, dynamic>) {
                          final childName = child['name'] as String?;
                          final childQty = child['quantity']?.toString() ?? '0';
                          final childTime = child['time']?.toString() ?? '';
                          if (childName != null) {
                            if (nestedQuantities[needId]!
                                .containsKey(childName)) {
                              nestedQuantities[needId]![childName]!.text =
                                  childQty;
                            }
                            if (pseTimeInputs.containsKey(childName)) {
                              pseTimeInputs[childName]!.text = childTime;
                            }
                          }
                        }
                      }
                    }
                  } else {
                    // Regular items with quantity only
                    patientNeedsState[needName]!.text = quantity;
                  }

                  debugPrint(
                      '[MissionTechnicalSheet] Updated default need: $needName = $quantity');
                } else {
                  // Custom patient need item
                  if (!customPatientNeedsItems.contains(needName)) {
                    customPatientNeedsItems.add(needName);
                  }
                  patientNeedsState[needName] =
                      TextEditingController(text: quantity);
                  debugPrint(
                      '[MissionTechnicalSheet] Added custom need: $needName = $quantity');
                }
              }
            }
          }
        } else if (needsData is Map<String, dynamic>) {
          // Handle Map format: {need_name: {name, quantity, children}, ...}
          debugPrint('[MissionTechnicalSheet] Processing patient needs as Map');
          needsData.forEach((needName, value) {
            debugPrint(
                '[MissionTechnicalSheet] Processing (Map): $needName = $value');

            if (needName is String) {
              bool isDefault =
                  defaultPatientNeedsOptions.any((opt) => opt.$1 == needName);

              // Extract data from value if it's a Map
              String quantity = '0';
              List<dynamic> children = [];

              if (value is Map<String, dynamic>) {
                quantity = value['quantity']?.toString() ?? '0';
                children = value['children'] as List? ?? [];
              } else if (value is String) {
                quantity = value;
              } else if (value is int) {
                quantity = value.toString();
              }

              // For VNI/VC: check if they have children (no parent quantity)
              // For others: check if quantity != '0'
              bool shouldProcess = false;
              if (isDefault) {
                final option = defaultPatientNeedsOptions.firstWhere(
                  (opt) => opt.$1 == needName,
                  orElse: () => ('', ''),
                );
                final needId = option.$2;

                if ((needId == 'vni' || needId == 'vc') &&
                    children.isNotEmpty) {
                  shouldProcess = true;
                } else if (quantity != '0') {
                  shouldProcess = true;
                }
              }

              if (isDefault && shouldProcess) {
                final option = defaultPatientNeedsOptions.firstWhere(
                  (opt) => opt.$1 == needName,
                  orElse: () => ('', ''),
                );
                final needId = option.$2;

                // Handle VNI and VC: only children, no parent quantity
                if (needId == 'vni' || needId == 'vc') {
                  if (children.isNotEmpty) {
                    for (var child in children) {
                      if (child is Map<String, dynamic>) {
                        final childName = child['name'] as String?;
                        final childQty = child['quantity']?.toString() ?? '0';
                        if (childName != null &&
                            nestedQuantities[needId]!.containsKey(childName)) {
                          nestedQuantities[needId]![childName]!.text = childQty;
                        }
                      }
                    }
                  }
                  debugPrint(
                      '[MissionTechnicalSheet] Updated VNI/VC need (Map): $needName');
                } else if (needId == 'pse') {
                  // Handle PSE: parent quantity + children with quantity and time
                  patientNeedsState[needName]!.text = quantity;
                  if (children.isNotEmpty) {
                    for (var child in children) {
                      if (child is Map<String, dynamic>) {
                        final childName = child['name'] as String?;
                        final childQty = child['quantity']?.toString() ?? '0';
                        final childTime = child['time']?.toString() ?? '';
                        if (childName != null) {
                          if (nestedQuantities[needId]!
                              .containsKey(childName)) {
                            nestedQuantities[needId]![childName]!.text =
                                childQty;
                          }
                          if (pseTimeInputs.containsKey(childName)) {
                            pseTimeInputs[childName]!.text = childTime;
                          }
                        }
                      }
                    }
                  }
                  debugPrint(
                      '[MissionTechnicalSheet] Updated PSE need (Map): $needName = $quantity');
                } else {
                  // Regular items with quantity only
                  if (patientNeedsState[needName] != null) {
                    patientNeedsState[needName]!.text = quantity;
                  } else {
                    patientNeedsState[needName] =
                        TextEditingController(text: quantity);
                  }
                  debugPrint(
                      '[MissionTechnicalSheet] Updated default need (Map): $needName = $quantity');
                }
              } else if (!isDefault && quantity != '0') {
                // Custom patient need item
                if (!customPatientNeedsItems.contains(needName)) {
                  customPatientNeedsItems.add(needName);
                }
                if (!patientNeedsState.containsKey(needName)) {
                  patientNeedsState[needName] =
                      TextEditingController(text: quantity);
                }
                debugPrint(
                    '[MissionTechnicalSheet] Added custom need (Map): $needName = $quantity');
              }
            }
          });
        } else {
          debugPrint(
              '[MissionTechnicalSheet] Patient needs not List or Map, type: ${needsData.runtimeType}');
        }
      } catch (e) {
        debugPrint('[MissionTechnicalSheet] Error loading patient needs: $e');
      }
    } else {
      debugPrint('[MissionTechnicalSheet] Patient needs is null or empty');
    }

    // Load existing motif de transport
    if (_currentMission.fracturesInjuries != null &&
        _currentMission.fracturesInjuries!.isNotEmpty) {
      setState(() {
        _selectedMotifTransport = _currentMission.fracturesInjuries;
      });
    }

    // Load existing report type
    if (_currentMission.reportType != null) {
      _reportType = _currentMission.reportType!;
    }

    // Final summary log
    debugPrint('[MissionTechnicalSheet] === FINAL STATE ===');
    debugPrint(
        '[MissionTechnicalSheet] Patient: ${_patientNameController.text}, Age: ${_ageController.text}');
    debugPrint(
        '[MissionTechnicalSheet] Vital Signs - TA_BEFORE: ${_taBeforeController.text}, TA_AFTER: ${_taAfterController.text}, SPO2_BEFORE: ${_spo2BeforeController.text}, SPO2_AFTER: ${_spo2AfterController.text}, FC_BEFORE: ${_fcBeforeController.text}, FC_AFTER: ${_fcAfterController.text}, FR_BEFORE: ${_frBeforeController.text}, FR_AFTER: ${_frAfterController.text}, TEMP_BEFORE: ${_temperatureBeforeController.text}, TEMP_AFTER: ${_temperatureAfterController.text}, GLUCOSE_BEFORE: ${_glucoseBeforeController.text}, GLUCOSE_AFTER: ${_glucoseAfterController.text}');
    debugPrint(
        '[MissionTechnicalSheet] Patient Needs State Keys: ${patientNeedsState.keys.toList()}');
    debugPrint('[MissionTechnicalSheet] Patient Needs Values:');
    patientNeedsState.forEach((key, controller) {
      debugPrint('[MissionTechnicalSheet]   $key = ${controller.text}');
    });
    debugPrint(
        '[MissionTechnicalSheet] Custom Patient Needs: $customPatientNeedsItems');
    debugPrint('[MissionTechnicalSheet] === END FINAL STATE ===');
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _ageController.dispose();
    _taBeforeController.dispose();
    _taAfterController.dispose();
    _fcBeforeController.dispose();
    _fcAfterController.dispose();
    _frBeforeController.dispose();
    _frAfterController.dispose();
    _temperatureBeforeController.dispose();
    _temperatureAfterController.dispose();
    _glucoseBeforeController.dispose();
    _glucoseAfterController.dispose();
    _spo2BeforeController.dispose();
    _spo2AfterController.dispose();

    // Dispose all patient needs quantity controllers
    for (var controller in patientNeedsState.values) {
      controller.dispose();
    }

    _screenProtectionService.disable();
    super.dispose();
  }

  Future<bool> _submitReport({bool popOnSuccess = true}) async {
    // Validate required fields (age is optional)
    if (_patientNameController.text.isEmpty) {
      _showSnackbar('Veuillez remplir le nom du patient', Colors.red);
      return false;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Split full name into first and last name
      final nameParts = _patientNameController.text.trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // ALWAYS prepare vital signs data (regardless of report type)
      Map<String, dynamic> vitalSigns = {
        'ta_before':
            _taBeforeController.text.isEmpty ? null : _taBeforeController.text,
        'ta_after':
            _taAfterController.text.isEmpty ? null : _taAfterController.text,
        'fc_before':
            _fcBeforeController.text.isEmpty ? null : _fcBeforeController.text,
        'fc_after':
            _fcAfterController.text.isEmpty ? null : _fcAfterController.text,
        'fr_before':
            _frBeforeController.text.isEmpty ? null : _frBeforeController.text,
        'fr_after':
            _frAfterController.text.isEmpty ? null : _frAfterController.text,
        'temperature_before': _temperatureBeforeController.text.isEmpty
            ? null
            : _temperatureBeforeController.text,
        'temperature_after': _temperatureAfterController.text.isEmpty
            ? null
            : _temperatureAfterController.text,
        'glucose_before': _glucoseBeforeController.text.isEmpty
            ? null
            : _glucoseBeforeController.text,
        'glucose_after': _glucoseAfterController.text.isEmpty
            ? null
            : _glucoseAfterController.text,
        'spo2_before': _spo2BeforeController.text.isEmpty
            ? null
            : _spo2BeforeController.text,
        'spo2_after': _spo2AfterController.text.isEmpty
            ? null
            : _spo2AfterController.text,
      };

      // Prepare medical history from checked items
      List<String> medicalHistoryList = [];
      medicalHistoryChecked.forEach((item, isChecked) {
        if (isChecked) {
          medicalHistoryList.add(item);
        }
      });

      // Prepare patient needs from state (only include items with quantity > 0)
      List<Map<String, dynamic>> needsData = [];

      debugPrint('[MissionTechnicalSheet] === Saving Patient Needs ===');

      // Handle VNI and VC first (they only have nested quantities, no parent quantity)
      for (var option in defaultPatientNeedsOptions) {
        final needName = option.$1;
        final needId = option.$2;

        if (needId == 'vni' || needId == 'vc') {
          debugPrint(
              '[MissionTechnicalSheet] Processing $needId ($needName)...');
          List<Map<String, dynamic>> children = [];
          for (var nested in nestedPatientNeedsOptions[needId] ?? []) {
            final nestedQty = nestedQuantities[needId]![nested]?.text ?? '0';
            debugPrint(
                '[MissionTechnicalSheet]   $needId.$nested = $nestedQty');
            if (nestedQty != '0') {
              children.add({
                'name': nested,
                'quantity': nestedQty,
              });
            }
          }
          // Only add VNI/VC if there are children with quantities
          if (children.isNotEmpty) {
            debugPrint(
                '[MissionTechnicalSheet] Saving $needId with ${children.length} children');
            needsData.add({
              'name': needName,
              'children': children,
            });
          } else {
            debugPrint(
                '[MissionTechnicalSheet] $needId has no children to save');
          }
        }
      }

      // Handle regular items and PSE from patientNeedsState
      patientNeedsState.forEach((needName, controller) {
        final quantity = controller.text.isEmpty ? '0' : controller.text;

        // Find the needId from defaultPatientNeedsOptions
        String? needId;
        for (var option in defaultPatientNeedsOptions) {
          if (option.$1 == needName) {
            needId = option.$2;
            break;
          }
        }

        // Skip VNI and VC (already handled above)
        if (needId == 'vni' || needId == 'vc') {
          return;
        }
        // Handle PSE: parent quantity + nested with quantity and time
        else if (needId == 'pse') {
          if (quantity != '0') {
            List<Map<String, dynamic>> children = [];
            for (var nested in nestedPatientNeedsOptions[needId] ?? []) {
              final nestedQty = nestedQuantities[needId]![nested]?.text ?? '0';
              final nestedTime = pseTimeInputs[nested]?.text ?? '';
              if (nestedQty != '0' || nestedTime.isNotEmpty) {
                children.add({
                  'name': nested,
                  'quantity': nestedQty,
                  'time': nestedTime,
                });
              }
            }
            needsData.add({
              'name': needName,
              'quantity': quantity,
              'children': children,
            });
          }
        }
        // Regular items with quantity only
        else if (quantity != '0') {
          needsData.add({
            'name': needName,
            'quantity': quantity,
          });
        }
      });

      debugPrint('[MissionTechnicalSheet] === Final Patient Needs Data ===');
      debugPrint('[MissionTechnicalSheet] $needsData');
      debugPrint('[MissionTechnicalSheet] === End Final Data ===');

      final medicalHistoryPayload =
          _reportType == 'simple_transport' ? medicalHistoryList : <String>[];
      final patientNeedsPayload =
          _reportType == 'simple_transport' ? needsData : <String, dynamic>{};

      await _missionPrivateService.saveTechnicalSheet(
        mission: _currentMission,
        patientName:
            _patientNameController.text.trim().isEmpty ? null : _patientNameController.text.trim(),
        patientFirstName: firstName.isEmpty ? null : firstName,
        patientLastName: lastName.isEmpty ? null : lastName,
        patientAge:
            _ageController.text.isEmpty ? null : int.tryParse(_ageController.text),
        reportType: _reportType,
        fracturesInjuries: _selectedMotifTransport ?? '',
        vitalSigns: vitalSigns,
        medicalHistory: medicalHistoryPayload,
        patientNeeds: patientNeedsPayload,
      );

      await _refreshMissionData();

      if (mounted) {
        _showSnackbar('Rapport enregistré avec succès!', Colors.green);
        if (popOnSuccess) {
          Navigator.pop(context);
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showSnackbar(
            'Erreur lors de l\'enregistrement du rapport: ${e.toString()}',
            Colors.red);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendToSelectedClinic() async {
    if (_selectedClinicTenantId == null || _selectedClinicTenantId!.isEmpty) {
      _showSnackbar('Choisissez une clinique avant l\'envoi.', Colors.orange);
      return;
    }

    final selectedClinic = _linkedClinics.firstWhere(
      (clinic) => clinic['tenant_id'] == _selectedClinicTenantId,
      orElse: () => <String, String>{},
    );

    final clinicName = selectedClinic['name'] ?? '';
    if (clinicName.isEmpty) {
      _showSnackbar('Clinique invalide.', Colors.red);
      return;
    }

    final saved = await _submitReport(popOnSuccess: false);
    if (!saved) {
      return;
    }

    setState(() {
      _isSendingToClinic = true;
    });

      try {
        await _missionService.sendTechnicalSheetToClinic(
          mission: _currentMission,
          clinicTenantId: _selectedClinicTenantId!,
          clinicName: clinicName,
        );
        await _refreshMissionData();

        if (mounted) {
          _showSnackbar('Fiche technique envoyee a $clinicName', Colors.green);
        }
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Erreur lors de l\\\'envoi a la clinique: ${e.toString()}',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingToClinic = false;
        });
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Fiche Technique Médicale',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.responsive.paddingValueLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Information Section
            _buildSectionHeader('👤 Informations du Patient'),
            const SizedBox(height: 16),
            _buildTextField(
                'Nom Complet', _patientNameController, 'ex: Jean Dupont'),
            const SizedBox(height: 12),
            _buildTextField('Âge', _ageController, 'Années'),
            const SizedBox(height: 12),
            _buildMotifTransportDropdown(),
            const SizedBox(height: 24),

            // Report Type Selection
            _buildSectionHeader('📋 Type de Rapport'),
            const SizedBox(height: 12),
            RadioListTile<String>(
              title: const Text('Transport Simple'),
              subtitle: const Text('Patient avec détails médicaux'),
              value: 'simple_transport',
              groupValue: _reportType,
              onChanged: (value) {
                setState(() {
                  _reportType = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Décédé'),
              subtitle: const Text('Patient est décédé'),
              value: 'deceased',
              groupValue: _reportType,
              onChanged: (value) {
                setState(() {
                  _reportType = value!;
                });
              },
            ),
            const SizedBox(height: 24),

            // Vital Signs (hidden when deceased)
            if (_reportType != 'deceased') ...[
              _buildSectionHeader('📊 Signes Vitaux'),
              const SizedBox(height: 12),
              // Row 1: TA Before | TA After
              Row(
                children: [
                  Expanded(
                    child: _buildVitalSignField(
                        'TA Avant (MMHG)', _taBeforeController, '120/80'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField(
                        'TA Après (MMHG)', _taAfterController, '120/80'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: FC Before | FC After
              Row(
                children: [
                  Expanded(
                    child: _buildVitalSignField(
                        'FC Avant (BPM)', _fcBeforeController, '72'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField(
                        'FC Après (BPM)', _fcAfterController, '72'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 3: FR Before | FR After
              Row(
                children: [
                  Expanded(
                    child: _buildVitalSignField(
                        'FR Avant (RES/MIN)', _frBeforeController, '16'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField(
                        'FR Après (RES/MIN)', _frAfterController, '16'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 4: Temp Before | Temp After
              Row(
                children: [
                  Expanded(
                    child: _buildVitalSignField(
                        'Temp Avant (°C)', _temperatureBeforeController, '37'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField(
                        'Temp Après (°C)', _temperatureAfterController, '37'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 5: Glucose Before | Glucose After
              Row(
                children: [
                  Expanded(
                    child: _buildVitalSignField(
                        'Glucose Avant', _glucoseBeforeController, ''),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField(
                        'Glucose Après', _glucoseAfterController, ''),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 6: SpO2 Before | SpO2 After
              Row(
                children: [
                  Expanded(
                    child: _buildVitalSignField(
                        'SpO2 Avant (%)', _spo2BeforeController, '98'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField(
                        'SpO2 Après (%)', _spo2AfterController, '98'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Conditional Content Based on Report Type
            if (_reportType == 'simple_transport') ...[
              // Medical History
              _buildSectionHeader('💊 Antécédents Médicaux'),
              const SizedBox(height: 12),
              _buildDynamicMedicalHistoryGroup(),
              const SizedBox(height: 24),

              // Patient Needs
              _buildSectionHeader('🏥 Besoins du Patient'),
              const SizedBox(height: 12),
              _buildDynamicPatientNeedsGroup(),
              const SizedBox(height: 24),
            ],

            _buildSectionHeader('Clinique destinataire'),
            const SizedBox(height: 12),
            if (_linkedClinics.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'Aucune clinique n\\\'est disponible dans Supabase pour recevoir cette fiche.',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedClinicTenantId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.lightPink,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _linkedClinics
                    .map(
                      (clinic) => DropdownMenuItem<String>(
                        value: clinic['tenant_id'],
                        child: Text(clinic['name'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClinicTenantId = value;
                  });
                },
              ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _submitReport(),
                icon: const Icon(Icons.save),
                label: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Enregistrer le Rapport'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _isSendingToClinic || _linkedClinics.isEmpty
                    ? null
                    : _sendToSelectedClinic,
                icon: const Icon(Icons.outbox),
                label: _isSendingToClinic
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Envoyer la Fiche a la Clinique'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightPink,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalSignField(
      String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightPink,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(
      String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.lightPink,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxGroup(
      Map<String, bool> checkboxMap, List<(String, String)> options) {
    return Column(
      children: options.map((option) {
        final (label, key) = option;
        return CheckboxListTile(
          title: Text(label),
          value: checkboxMap[key] ?? false,
          onChanged: (value) {
            setState(() {
              checkboxMap[key] = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }

  String _formatLabel(String key) {
    switch (key) {
      case 'oxygen':
        return 'Oxygène';
      case 'perfusion':
        return 'Perfusion';
      case 'monitorage':
        return 'Monitorage';
      case 'pensement':
        return 'Pansement';
      case 'immobilisation':
        return 'Immobilisation';
      default:
        return key;
    }
  }

  // Dynamic Medical History Section with Add/Remove buttons
  Widget _buildDynamicMedicalHistoryGroup() {
    return Column(
      children: [
        // Default medical history options with checkboxes
        ...defaultMedicalHistoryOptions.map((option) {
          final label = option.$1;
          final isChecked = medicalHistoryChecked[label] ?? false;
          return CheckboxListTile(
            title: Text(label),
            value: isChecked,
            onChanged: (bool? value) {
              setState(() {
                medicalHistoryChecked[label] = value ?? false;
              });
            },
          );
        }).toList(),

        // Custom medical history items
        ...customMedicalHistoryItems.asMap().entries.map((entry) {
          int index = entry.key;
          String item = entry.value;
          final isChecked = medicalHistoryChecked[item] ?? false;
          return CheckboxListTile(
            title: Text(item),
            value: isChecked,
            onChanged: (bool? value) {
              setState(() {
                medicalHistoryChecked[item] = value ?? false;
              });
            },
            secondary: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  customMedicalHistoryItems.removeAt(index);
                  medicalHistoryChecked.remove(item);
                });
              },
            ),
          );
        }).toList(),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showAddMedicalHistoryDialog,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un antécédent'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Dynamic Patient Needs Section with Quantity Fields
  Widget _buildDynamicPatientNeedsGroup() {
    return Column(
      children: [
        // Default patient needs options with quantity fields
        ...defaultPatientNeedsOptions.map((option) {
          final needName = option.$1;
          final needId = option.$2;
          final hasNestedOptions =
              nestedPatientNeedsOptions.containsKey(needId);

          // VNI and VC: only show nested options with quantities (no parent)
          if (needId == 'vni' || needId == 'vc') {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    needName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...nestedPatientNeedsOptions[needId]!.map((nestedOption) {
                    final controller = nestedQuantities[needId]![nestedOption]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              '  • $nestedOption',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                // hintText removed
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }
          // PSE: parent quantity + nested with quantity + time
          else if (needId == 'pse') {
            final parentController =
                patientNeedsState[needName] ?? TextEditingController(text: '0');
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent quantity
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          needName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: parentController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            // hintText removed
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Nested options with quantity and time
                  ...nestedPatientNeedsOptions[needId]!.map((nestedOption) {
                    final qtyController =
                        nestedQuantities[needId]![nestedOption]!;
                    final timeController = pseTimeInputs[nestedOption]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '  • $nestedOption',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Qté',
                                    // hintText removed
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: timeController,
                                  decoration: InputDecoration(
                                    labelText: 'Durée',
                                    // hintText removed
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }
          // Regular items with quantity only
          else {
            final controller =
                patientNeedsState[needName] ?? TextEditingController(text: '0');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      needName,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        // hintText removed
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }).toList(),

        // Custom patient needs items
        ...customPatientNeedsItems.asMap().entries.map((entry) {
          int index = entry.key;
          String needName = entry.value;
          final controller =
              patientNeedsState[needName] ?? TextEditingController(text: '0');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    needName,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      // hintText removed
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      customPatientNeedsItems.removeAt(index);
                      patientNeedsState.remove(needName);
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _showAddPatientNeedDialog,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un besoin'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Dialog to add medical history
  void _showAddMedicalHistoryDialog() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un antécédent'),
        content: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            // hintText removed
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final itemName = controller.text;
                setState(() {
                  if (!customMedicalHistoryItems.contains(itemName)) {
                    customMedicalHistoryItems.add(itemName);
                  }
                  // Initialize as checked when adding
                  medicalHistoryChecked[itemName] = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  // Dialog to add patient need
  void _showAddPatientNeedDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController quantityController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un besoin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                // hintText removed
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                // hintText removed
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final itemName = nameController.text;
                final quantity = quantityController.text.isEmpty
                    ? '0'
                    : quantityController.text;
                setState(() {
                  if (!customPatientNeedsItems.contains(itemName)) {
                    customPatientNeedsItems.add(itemName);
                  }
                  // Initialize/update quantity
                  patientNeedsState[itemName] =
                      TextEditingController(text: quantity);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCustomMotifTransportOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final customOptions =
        prefs.getStringList('custom_motif_transport_options') ?? [];
    setState(() {
      customMotifTransportOptions = customOptions;
    });
  }

  Future<void> _saveCustomMotifTransportOptions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'custom_motif_transport_options', customMotifTransportOptions);
  }

  Widget _buildMotifTransportDropdown() {
    final allOptions = [
      ...defaultMotifTransportOptions,
      ...customMotifTransportOptions
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Motif de Transport',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedMotifTransport,
          hint: const Text('Sélectionner un motif'),
          items: allOptions
              .map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: (value) {
            if (value == 'autre') {
              _showAddCustomMotifDialog();
            } else {
              setState(() {
                _selectedMotifTransport = value;
              });
            }
          },
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.local_hospital),
          ),
        ),
      ],
    );
  }

  void _showAddCustomMotifDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un motif personnalisé'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            // hintText removed
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final newMotif = controller.text;
                setState(() {
                  if (!customMotifTransportOptions.contains(newMotif)) {
                    customMotifTransportOptions.add(newMotif);
                    _saveCustomMotifTransportOptions();
                  }
                  _selectedMotifTransport = newMotif;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}
