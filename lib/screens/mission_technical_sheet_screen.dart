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

  const MissionTechnicalSheetScreen({Key? key, required this.mission})
    : super(key: key);

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
  String? _missionPhotoSignedUrl;
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
    ('Diabetique', 'diabetic'),
    ('HTA', 'hta'),
    ('Douleur Thoracique', 'douleur_thoracique'),
    ('Dialyse', 'dialysis'),
    ('Detresse Respiratoire', 'distresse_respiratoire'),
    ('Hypotension', 'hypalepsie'),
    ('Maladie Coronarienne', 'coronaria'),
    ('Cardiaque', 'cardiaque'),
    ('BPCO', 'bpco'),
    ('Asthme', 'asthme'),
    ('Epilepsie', 'epilepsie'),
  ];

  // Default options for patient needs
  final defaultPatientNeedsOptions = [
    ('Oxygene', 'oxygen'),
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
    'vni': ['pep', 'aide', 'FR', 'fie2+vc'],
    'vc': ['courant', 'FR', 'PEP'],
    'pse': ['norade', 'adre', 'sedation', 'heparine', 'rivotril'],
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
  Map<String, bool> patientNeedsToggleState = {
    'Monitorage': true,
    'Pansement': true,
    'Immobilisation': true,
  };

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
  List<Map<String, TextEditingController>> medicationControllers = [];

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
      text: _currentMission.patientAge?.toString() ?? '',
    );
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
      // Fetch operational data plus one private payload only when this PHI
      // screen is opened.
      final freshMission = await _missionService.getMissionByIdOperational(
        _currentMission.id,
      );
      final privatePayload = await _missionPrivateService.getMissionPrivateData(
        _currentMission.id,
      );
      debugPrint(
        '[MissionTechnicalSheet] Fresh mission fetched: ${freshMission?.id}',
      );
      if (freshMission != null && mounted) {
        final mergedMission = _mergeMissionWithPrivatePayload(
          freshMission,
          privatePayload,
        );
        setState(() {
          _currentMission = mergedMission;
          final missionPhotoPayload =
              privatePayload['mission_photo'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(
                    privatePayload['mission_photo'] as Map<String, dynamic>,
                  )
                : <String, dynamic>{};
          _missionPhotoSignedUrl =
              missionPhotoPayload['signed_url']?.toString();
          debugPrint(
            '[MissionTechnicalSheet] Vital Signs Raw: ${_currentMission.vitalSigns}',
          );
          debugPrint(
            '[MissionTechnicalSheet] Patient Needs Raw: ${_currentMission.patientNeeds}',
          );
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
      mergedJson['patient_name'] =
          contact['patient_name'] ?? mergedJson['patient_name'];
      mergedJson['patient_first_name'] =
          contact['patient_first_name'] ?? mergedJson['patient_first_name'];
      mergedJson['patient_last_name'] =
          contact['patient_last_name'] ?? mergedJson['patient_last_name'];
      mergedJson['patient_phone'] =
          contact['patient_phone'] ?? mergedJson['patient_phone'];
      mergedJson['patient_age'] =
          contact['patient_age'] ?? mergedJson['patient_age'];
      mergedJson['pickup_address'] =
          contact['pickup_address'] ?? mergedJson['pickup_address'];
      mergedJson['destination_address'] =
          contact['destination_address'] ?? mergedJson['destination_address'];
      mergedJson['pickup_lat'] =
          contact['pickup_lat'] ?? mergedJson['pickup_lat'];
      mergedJson['pickup_lng'] =
          contact['pickup_lng'] ?? mergedJson['pickup_lng'];
      mergedJson['destination_lat'] =
          contact['destination_lat'] ?? mergedJson['destination_lat'];
      mergedJson['destination_lng'] =
          contact['destination_lng'] ?? mergedJson['destination_lng'];
    }

    if (medical.isNotEmpty) {
      mergedJson['report_type'] =
          medical['report_type'] ?? mergedJson['report_type'];
      mergedJson['fractures_injuries'] =
          medical['fractures_injuries'] ?? mergedJson['fractures_injuries'];
      mergedJson['report_filled_at'] =
          medical['report_filled_at'] ?? mergedJson['report_filled_at'];
      mergedJson['medical_history'] =
          medical['medical_history'] ?? mergedJson['medical_history'];
      mergedJson['vital_signs'] =
          medical['vital_signs'] ?? mergedJson['vital_signs'];
      mergedJson['patient_needs'] =
          medical['patient_needs'] ?? mergedJson['patient_needs'];
      mergedJson['medications'] =
          medical['medications'] ?? mergedJson['medications'];
    }

    return Mission.fromJson(mergedJson);
  }

  Future<void> _loadLinkedClinics() async {
    try {
      final clinics = await _missionService
          .getLinkedClinicsForCurrentProvider();
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
      '[MissionTechnicalSheet] Patient Name: $fullName, Age: ${_currentMission.patientAge}',
    );

    // Load existing vital signs
    debugPrint(
      '[MissionTechnicalSheet] Vital Signs is null: ${_currentMission.vitalSigns == null}',
    );
    debugPrint(
      '[MissionTechnicalSheet] Vital Signs isEmpty: ${_currentMission.vitalSigns?.isEmpty}',
    );
    debugPrint(
      '[MissionTechnicalSheet] Vital Signs type: ${_currentMission.vitalSigns.runtimeType}',
    );
    if (_currentMission.vitalSigns != null &&
        _currentMission.vitalSigns!.isNotEmpty) {
      try {
        dynamic vitalSignsData = _currentMission.vitalSigns!;
        debugPrint('[MissionTechnicalSheet] Raw vital signs: $vitalSignsData');
        debugPrint(
          '[MissionTechnicalSheet] Vital signs is String: ${vitalSignsData is String}',
        );

        // If it's a string, decode it (JSON stored as string)
        if (vitalSignsData is String) {
          debugPrint('[MissionTechnicalSheet] Decoding vital signs string...');
          vitalSignsData = jsonDecode(vitalSignsData);
          debugPrint('[MissionTechnicalSheet] After decode: $vitalSignsData');
        }

        debugPrint(
          '[MissionTechnicalSheet] Vital signs is Map: ${vitalSignsData is Map<String, dynamic>}',
        );
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
            '[MissionTechnicalSheet] Vital signs loaded: TA_BEFORE=${_taBeforeController.text}, TA_AFTER=${_taAfterController.text}, FC_BEFORE=${_fcBeforeController.text}, FC_AFTER=${_fcAfterController.text}, FR_BEFORE=${_frBeforeController.text}, FR_AFTER=${_frAfterController.text}, TEMP_BEFORE=${_temperatureBeforeController.text}, TEMP_AFTER=${_temperatureAfterController.text}, GLUCOSE_BEFORE=${_glucoseBeforeController.text}, GLUCOSE_AFTER=${_glucoseAfterController.text}, SPO2_BEFORE=${_spo2BeforeController.text}, SPO2_AFTER=${_spo2AfterController.text}',
          );
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
            bool isDefault = defaultMedicalHistoryOptions.any(
              (opt) => opt.$1 == item,
            );
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
          nestedQuantities[needId]![nestedOption] = TextEditingController(
            text: '0',
          );
        }
      } else if (needId == 'pse') {
        // Initialize parent quantity for PSE
        patientNeedsState[label] = TextEditingController(text: '0');
        // Initialize nested vitesse controllers
        for (var nestedOption in nestedPatientNeedsOptions[needId] ?? []) {
          nestedQuantities[needId]![nestedOption] = TextEditingController(
            text: '0',
          );
        }
      } else {
        // Regular items with quantity
        patientNeedsState[label] = TextEditingController(text: '0');
      }
    }
    debugPrint(
      '[MissionTechnicalSheet] Patient needs state initialized: ${patientNeedsState.keys.toList()}',
    );

    // Load existing patient needs
    debugPrint(
      '[MissionTechnicalSheet] Patient needs is null: ${_currentMission.patientNeeds == null}',
    );
    debugPrint(
      '[MissionTechnicalSheet] Patient needs isEmpty: ${_currentMission.patientNeeds?.isEmpty}',
    );
    debugPrint(
      '[MissionTechnicalSheet] Patient needs type: ${_currentMission.patientNeeds.runtimeType}',
    );
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
              '[MissionTechnicalSheet] Decode attempt $decodeCount...',
            );
            needsData = jsonDecode(needsData);
            debugPrint(
              '[MissionTechnicalSheet] After decode $decodeCount: $needsData',
            );
          } catch (e) {
            // If decode fails, it's not JSON - break out
            debugPrint(
              '[MissionTechnicalSheet] Decode failed at attempt $decodeCount: $e',
            );
            break;
          }
        }
        debugPrint(
          '[MissionTechnicalSheet] Final patient needs data type: ${needsData.runtimeType}',
        );
        debugPrint('[MissionTechnicalSheet] Final patient needs: $needsData');

        if (needsData is List) {
          debugPrint(
            '[MissionTechnicalSheet] Processing patient needs as List with ${needsData.length} items',
          );
          for (var item in needsData) {
            if (item is Map<String, dynamic>) {
              final needName = item['name'] as String?;
              final quantity = item['quantity']?.toString() ?? '0';
              final children = item['children'] as List? ?? [];
              debugPrint(
                '[MissionTechnicalSheet] Processing need: $needName with quantity: $quantity, children: ${children.length}',
              );

              if (needName != null && needName.isNotEmpty) {
                bool isDefault = defaultPatientNeedsOptions.any(
                  (opt) => opt.$1 == needName,
                );

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
                              nestedQuantities[needId]!.containsKey(
                                childName,
                              )) {
                            nestedQuantities[needId]![childName]!.text =
                                childQty;
                          }
                        }
                      }
                    }
                  } else if (needId == 'pse') {
                    // Handle PSE: parent quantity + children with vitesse field
                    patientNeedsState[needName]!.text = quantity;
                    if (children.isNotEmpty) {
                      for (var child in children) {
                        if (child is Map<String, dynamic>) {
                          final childName = child['name'] as String?;
                          final childQty =
                              (child['vitesse'] ?? child['quantity'])
                                      ?.toString() ??
                                  '0';
                          if (childName != null) {
                            if (nestedQuantities[needId]!.containsKey(
                              childName,
                            )) {
                              nestedQuantities[needId]![childName]!.text =
                                  childQty;
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
                    '[MissionTechnicalSheet] Updated default need: $needName = $quantity',
                  );
                } else {
                  // Custom patient need item
                  if (!customPatientNeedsItems.contains(needName)) {
                    customPatientNeedsItems.add(needName);
                  }
                  patientNeedsState[needName] = TextEditingController(
                    text: quantity,
                  );
                  debugPrint(
                    '[MissionTechnicalSheet] Added custom need: $needName = $quantity',
                  );
                }
              }
            }
          }
        } else if (needsData is Map<String, dynamic>) {
          // Handle Map format: {need_name: {name, quantity, children}, ...}
          debugPrint('[MissionTechnicalSheet] Processing patient needs as Map');
          needsData.forEach((needName, value) {
            debugPrint(
              '[MissionTechnicalSheet] Processing (Map): $needName = $value',
            );

            if (needName is String) {
              bool isDefault = defaultPatientNeedsOptions.any(
                (opt) => opt.$1 == needName,
              );

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
                    '[MissionTechnicalSheet] Updated VNI/VC need (Map): $needName',
                  );
                } else if (needId == 'pse') {
                  // Handle PSE: parent quantity + children with vitesse field
                  patientNeedsState[needName]!.text = quantity;
                  if (children.isNotEmpty) {
                    for (var child in children) {
                      if (child is Map<String, dynamic>) {
                        final childName = child['name'] as String?;
                        final childQty =
                            (child['vitesse'] ?? child['quantity'])
                                    ?.toString() ??
                                '0';
                        if (childName != null) {
                          if (nestedQuantities[needId]!.containsKey(
                            childName,
                          )) {
                            nestedQuantities[needId]![childName]!.text =
                                childQty;
                          }
                        }
                      }
                    }
                  }
                  debugPrint(
                    '[MissionTechnicalSheet] Updated PSE need (Map): $needName = $quantity',
                  );
                } else {
                  // Regular items with quantity only
                  if (patientNeedsState[needName] != null) {
                    patientNeedsState[needName]!.text = quantity;
                  } else {
                    patientNeedsState[needName] = TextEditingController(
                      text: quantity,
                    );
                  }
                  debugPrint(
                    '[MissionTechnicalSheet] Updated default need (Map): $needName = $quantity',
                  );
                }
              } else if (!isDefault && quantity != '0') {
                // Custom patient need item
                if (!customPatientNeedsItems.contains(needName)) {
                  customPatientNeedsItems.add(needName);
                }
                if (!patientNeedsState.containsKey(needName)) {
                  patientNeedsState[needName] = TextEditingController(
                    text: quantity,
                  );
                }
                debugPrint(
                  '[MissionTechnicalSheet] Added custom need (Map): $needName = $quantity',
                );
              }
            }
          });
        } else {
          debugPrint(
            '[MissionTechnicalSheet] Patient needs not List or Map, type: ${needsData.runtimeType}',
          );
        }
      } catch (e) {
        debugPrint('[MissionTechnicalSheet] Error loading patient needs: $e');
      }
    } else {
      debugPrint('[MissionTechnicalSheet] Patient needs is null or empty');
    }

    if (_currentMission.patientNeeds != null &&
        _currentMission.patientNeeds!.isNotEmpty) {
      for (final needName in ['Monitorage', 'Pansement', 'Immobilisation']) {
        final currentValue = patientNeedsState[needName]?.text ?? '0';
        patientNeedsToggleState[needName] = currentValue != '0';
      }
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

    _loadMedications();

    // Final summary log
    debugPrint('[MissionTechnicalSheet] === FINAL STATE ===');
    debugPrint(
      '[MissionTechnicalSheet] Patient: ${_patientNameController.text}, Age: ${_ageController.text}',
    );
    debugPrint(
      '[MissionTechnicalSheet] Vital Signs - TA_BEFORE: ${_taBeforeController.text}, TA_AFTER: ${_taAfterController.text}, SPO2_BEFORE: ${_spo2BeforeController.text}, SPO2_AFTER: ${_spo2AfterController.text}, FC_BEFORE: ${_fcBeforeController.text}, FC_AFTER: ${_fcAfterController.text}, FR_BEFORE: ${_frBeforeController.text}, FR_AFTER: ${_frAfterController.text}, TEMP_BEFORE: ${_temperatureBeforeController.text}, TEMP_AFTER: ${_temperatureAfterController.text}, GLUCOSE_BEFORE: ${_glucoseBeforeController.text}, GLUCOSE_AFTER: ${_glucoseAfterController.text}',
    );
    debugPrint(
      '[MissionTechnicalSheet] Patient Needs State Keys: ${patientNeedsState.keys.toList()}',
    );
    debugPrint('[MissionTechnicalSheet] Patient Needs Values:');
    patientNeedsState.forEach((key, controller) {
      debugPrint('[MissionTechnicalSheet]   $key = ${controller.text}');
    });
    debugPrint(
      '[MissionTechnicalSheet] Custom Patient Needs: $customPatientNeedsItems',
    );
    debugPrint(
      '[MissionTechnicalSheet] Medications Loaded: ${medicationControllers.length}',
    );
    debugPrint('[MissionTechnicalSheet] === END FINAL STATE ===');
  }

  void _loadMedications() {
    for (final medication in medicationControllers) {
      for (final controller in medication.values) {
        controller.dispose();
      }
    }
    medicationControllers.clear();

    final medications = _currentMission.medications;
    if (medications == null || medications.isEmpty) {
      return;
    }

    for (final medication in medications) {
      medicationControllers.add({
        'name': TextEditingController(
          text: medication['name']?.toString() ?? '',
        ),
        'dosage': TextEditingController(
          text: medication['dosage']?.toString() ?? '',
        ),
        'frequency': TextEditingController(
          text: medication['frequency']?.toString() ?? '',
        ),
      });
    }
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

    for (final medication in medicationControllers) {
      for (final controller in medication.values) {
        controller.dispose();
      }
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
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      // ALWAYS prepare vital signs data (regardless of report type)
      Map<String, dynamic> vitalSigns = {
        'ta_before': _taBeforeController.text.isEmpty
            ? null
            : _taBeforeController.text,
        'ta_after': _taAfterController.text.isEmpty
            ? null
            : _taAfterController.text,
        'fc_before': _fcBeforeController.text.isEmpty
            ? null
            : _fcBeforeController.text,
        'fc_after': _fcAfterController.text.isEmpty
            ? null
            : _fcAfterController.text,
        'fr_before': _frBeforeController.text.isEmpty
            ? null
            : _frBeforeController.text,
        'fr_after': _frAfterController.text.isEmpty
            ? null
            : _frAfterController.text,
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
            '[MissionTechnicalSheet] Processing $needId ($needName)...',
          );
          List<Map<String, dynamic>> children = [];
          for (var nested in nestedPatientNeedsOptions[needId] ?? []) {
            final nestedQty = nestedQuantities[needId]![nested]?.text ?? '0';
            debugPrint(
              '[MissionTechnicalSheet]   $needId.$nested = $nestedQty',
            );
            if (nestedQty != '0') {
              children.add({'name': nested, 'quantity': nestedQty});
            }
          }
          // Only add VNI/VC if there are children with quantities
          if (children.isNotEmpty) {
            debugPrint(
              '[MissionTechnicalSheet] Saving $needId with ${children.length} children',
            );
            needsData.add({'name': needName, 'children': children});
          } else {
            debugPrint(
              '[MissionTechnicalSheet] $needId has no children to save',
            );
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
              if (nestedQty != '0' && nestedQty.isNotEmpty) {
                children.add({'name': nested, 'vitesse': nestedQty});
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
        else if ((needName == 'Monitorage' ||
                needName == 'Pansement' ||
                needName == 'Immobilisation') &&
            !(patientNeedsToggleState[needName] ?? true)) {
          return;
        } else if (quantity != '0') {
          needsData.add({'name': needName, 'quantity': quantity});
        }
      });

      debugPrint('[MissionTechnicalSheet] === Final Patient Needs Data ===');
      debugPrint('[MissionTechnicalSheet] $needsData');
      debugPrint('[MissionTechnicalSheet] === End Final Data ===');

      final medicalHistoryPayload = _reportType == 'simple_transport'
          ? medicalHistoryList
          : <String>[];
      final patientNeedsPayload = _reportType == 'simple_transport'
          ? needsData
          : <String, dynamic>{};
      final medicationsPayload = _buildMedicationsPayload();

      await _missionPrivateService.saveTechnicalSheet(
        mission: _currentMission,
        patientName: _patientNameController.text.trim().isEmpty
            ? null
            : _patientNameController.text.trim(),
        patientFirstName: firstName.isEmpty ? null : firstName,
        patientLastName: lastName.isEmpty ? null : lastName,
        patientAge: _ageController.text.isEmpty
            ? null
            : int.tryParse(_ageController.text),
        reportType: _reportType,
        fracturesInjuries: _selectedMotifTransport ?? '',
        vitalSigns: vitalSigns,
        medicalHistory: medicalHistoryPayload,
        patientNeeds: patientNeedsPayload,
        medications: medicationsPayload,
      );

      await _refreshMissionData();

      if (mounted) {
        _showSnackbar('Rapport enregistre avec succes!', Colors.green);
        if (popOnSuccess) {
          Navigator.pop(context);
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showSnackbar(
          'Erreur lors de l\'enregistrement du rapport: ${e.toString()}',
          Colors.red,
        );
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

  Widget _buildMissionPhotoSection() {
    final imageUrl = _missionPhotoSignedUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.orange[100]!),
        ),
        child: const Text(
          'La photo jointe existe, mais elle ne peut pas etre chargee pour le moment.',
          style: TextStyle(
            color: Colors.deepOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showMissionPhotoDialog(imageUrl),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blueGrey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.photo_camera_back_rounded,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photo jointe a la mission',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: Colors.grey[200],
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Touchez la photo pour l agrandir.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMissionPhotoDialog(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Photo de la mission',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: const Text(
                      'Impossible de charger cette photo.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fiche Technique Medicale',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
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
            _buildSectionHeader('Informations du Patient'),
            const SizedBox(height: 16),
            _buildTextField(
              'Nom Complet',
              _patientNameController,
              'ex: Jean Dupont',
            ),
            const SizedBox(height: 12),
            _buildTextField('Age', _ageController, 'Annees'),
            const SizedBox(height: 12),
            _buildMotifTransportDropdown(),
            if (_currentMission.hasMissionPhoto) ...[
              const SizedBox(height: 16),
              _buildMissionPhotoSection(),
            ],
            const SizedBox(height: 24),

            // Report Type Selection
            _buildSectionHeader('Type de Rapport'),
            const SizedBox(height: 12),
            RadioListTile<String>(
              title: const Text('Transport Simple'),
              subtitle: const Text('Patient avec details medicaux'),
              value: 'simple_transport',
              groupValue: _reportType,
              onChanged: (value) {
                setState(() {
                  _reportType = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Decede'),
              subtitle: const Text('Patient est decede'),
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
              _buildSectionHeader('Signes Vitaux'),
              const SizedBox(height: 12),
              _buildVitalSignsBeforeSection(),
              const SizedBox(height: 24),
            ],

            // Conditional Content Based on Report Type
            if (_reportType == 'simple_transport') ...[
              // Medical History
              _buildSectionHeader('Antecedents Medicaux'),
              const SizedBox(height: 12),
              _buildDynamicMedicalHistoryGroup(),
              const SizedBox(height: 24),

              // Patient Needs
              _buildSectionHeader('Besoins du Patient'),
              const SizedBox(height: 12),
              _buildDynamicPatientNeedsGroupSecure(),
              const SizedBox(height: 24),

              _buildSectionHeader('Medicaments administres'),
              const SizedBox(height: 12),
              _buildMedicationsSection(),
              const SizedBox(height: 24),
            ],

            if (_reportType != 'deceased') ...[
              _buildSectionHeader('Signes Vitaux Apres'),
              const SizedBox(height: 12),
              _buildVitalSignsAfterSection(),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
                onPressed:
                    _isLoading || _isSendingToClinic || _linkedClinics.isEmpty
                    ? null
                    : _sendToSelectedClinic,
                icon: const Icon(Icons.outbox),
                label: _isSendingToClinic
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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

  List<Map<String, String>> _buildMedicationsPayload() {
    final medications = <Map<String, String>>[];
    for (final medication in medicationControllers) {
      final name = medication['name']?.text.trim() ?? '';
      final dosage = medication['dosage']?.text.trim() ?? '';
      final frequency = medication['frequency']?.text.trim() ?? '';

      if (name.isEmpty && dosage.isEmpty && frequency.isEmpty) {
        continue;
      }

      medications.add({
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
      });
    }
    return medications;
  }

  Widget _buildMedicationsSection() {
    return Column(
      children: [
        ...medicationControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final medication = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Medicament ${index + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            for (final controller in medication.values) {
                              controller.dispose();
                            }
                            medicationControllers.removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    'Nom',
                    medication['name']!,
                    'Nom du medicament',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Dosage',
                          medication['dosage']!,
                          'ex: 500 mg',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          'Frequence',
                          medication['frequency']!,
                          'ex: 2x / jour',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _addMedication,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un medicament'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _addMedication() {
    setState(() {
      medicationControllers.add({
        'name': TextEditingController(),
        'dosage': TextEditingController(),
        'frequency': TextEditingController(),
      });
    });
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
    String label,
    TextEditingController controller,
    String hint,
  ) {
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalSignField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController controller,
    String hint,
  ) {
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxGroup(
    Map<String, bool> checkboxMap,
    List<(String, String)> options,
  ) {
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
        return 'Oxygene';
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
          label: const Text('Ajouter un antecedent'),
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
          final hasNestedOptions = nestedPatientNeedsOptions.containsKey(
            needId,
          );

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
                              '  - $nestedOption',
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
                            '  - $nestedOption',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: qtyController,
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: 'Qte',
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
                                    labelText: 'Duree',
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
                    child: Text(needName, style: const TextStyle(fontSize: 16)),
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
                  child: Text(needName, style: const TextStyle(fontSize: 16)),
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

  Widget _buildDynamicPatientNeedsGroupSecure() {
    final toggleNames = {'Monitorage', 'Pansement', 'Immobilisation'};

    Widget buildToggle(String needName, TextEditingController controller) {
      final isEnabled = patientNeedsToggleState[needName] ?? true;
      return Row(
        children: [
          Expanded(
            child: Text(needName, style: const TextStyle(fontSize: 16)),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      patientNeedsToggleState[needName] = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isEnabled ? Colors.green : Colors.grey[300],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        bottomLeft: Radius.circular(7),
                      ),
                    ),
                    child: Text(
                      'Oui',
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      patientNeedsToggleState[needName] = false;
                      controller.text = '0';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: !isEnabled ? Colors.red : Colors.grey[300],
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                    ),
                    child: Text(
                      'Non',
                      style: TextStyle(
                        color: !isEnabled ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ...defaultPatientNeedsOptions.map((option) {
          final needName = option.$1;
          final needId = option.$2;

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
                              '  - $nestedOption',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
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
                  }),
                ],
              ),
            );
          }

          if (needId == 'pse') {
            final parentController =
                patientNeedsState[needName] ?? TextEditingController(text: '0');
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  ...nestedPatientNeedsOptions[needId]!.map((nestedOption) {
                    final controller = nestedQuantities[needId]![nestedOption]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '  - $nestedOption',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: controller,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Vitesse',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }

          final controller =
              patientNeedsState[needName] ?? TextEditingController(text: '0');
          final hasToggle = toggleNames.contains(needName);
          final isPerfusion = needName == 'Perfusion';
          final isEnabled = patientNeedsToggleState[needName] ?? true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hasToggle
                    ? buildToggle(needName, controller)
                    : Text(needName, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: controller,
                  enabled: !hasToggle || isEnabled,
                  keyboardType:
                      isPerfusion ? TextInputType.text : TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    filled: hasToggle && !isEnabled,
                    fillColor: hasToggle && !isEnabled ? Colors.grey[200] : null,
                  ),
                ),
              ],
            ),
          );
        }),
        ...customPatientNeedsItems.asMap().entries.map((entry) {
          final index = entry.key;
          final needName = entry.value;
          final controller =
              patientNeedsState[needName] ?? TextEditingController(text: '0');
          final isTextInput = needName == 'Perfusion';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(needName, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    keyboardType:
                        isTextInput ? TextInputType.text : TextInputType.number,
                    decoration: InputDecoration(
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
                      patientNeedsToggleState.remove(needName);
                    });
                  },
                ),
              ],
            ),
          );
        }),
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
  Widget _buildVitalSignsBeforeSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildVitalSignField(
                'TA Avant (MMHG)',
                _taBeforeController,
                '120/80',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildVitalSignField(
                'FC Avant (BPM)',
                _fcBeforeController,
                '72',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildVitalSignField(
                'FR Avant (RES/MIN)',
                _frBeforeController,
                '16',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildVitalSignField(
                'Temp Avant (C)',
                _temperatureBeforeController,
                '37',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildVitalSignField(
                'Glucose Avant',
                _glucoseBeforeController,
                '',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildVitalSignField(
                'SpO2 Avant (%)',
                _spo2BeforeController,
                '98',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalSignsAfterSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildVitalSignField(
                'TA Apres (MMHG)',
                _taAfterController,
                '120/80',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildVitalSignField(
                'FC Apres (BPM)',
                _fcAfterController,
                '72',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildVitalSignField(
                'FR Apres (RES/MIN)',
                _frAfterController,
                '16',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildVitalSignField(
                'Temp Apres (C)',
                _temperatureAfterController,
                '37',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildVitalSignField(
                'Glucose Apres',
                _glucoseAfterController,
                '',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildVitalSignField(
                'SpO2 Apres (%)',
                _spo2AfterController,
                '98',
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddMedicalHistoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un antecedent'),
        content: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showAddPatientNeedDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                final quantity = quantityController.text.isEmpty ? '0' : quantityController.text;
                setState(() {
                  if (!customPatientNeedsItems.contains(itemName)) {
                    customPatientNeedsItems.add(itemName);
                  }
                  patientNeedsState[itemName] = TextEditingController(text: quantity);
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
    final customOptions = prefs.getStringList('custom_motif_transport_options') ?? [];
    if (!mounted) return;
    setState(() {
      customMotifTransportOptions = customOptions;
    });
  }

  Future<void> _saveCustomMotifTransportOptions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_motif_transport_options', customMotifTransportOptions);
  }

  Widget _buildMotifTransportDropdown() {
    final allOptions = [
      ...defaultMotifTransportOptions,
      ...customMotifTransportOptions,
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
          hint: const Text('Selectionner un motif'),
          items: allOptions
              .map((option) => DropdownMenuItem<String>(
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
        title: const Text('Ajouter un motif personnalise'),
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



