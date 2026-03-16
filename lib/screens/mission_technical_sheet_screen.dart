import 'package:flutter/material.dart';
import 'dart:convert';
import '../config/constants.dart';
import '../models/mission_model.dart';
import '../services/mission_service.dart';

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
  late TextEditingController _patientNameController;
  late TextEditingController _ageController;
  late TextEditingController _motifTransportController;
  late TextEditingController _taController;
  late TextEditingController _spo2Controller;
  late TextEditingController _fcController;
  late TextEditingController _frController;
  late TextEditingController _temperatureController;
  late TextEditingController _glucoseController;

  String _reportType = 'simple_transport';

  // Medical history checkboxes
  Map<String, bool> medicalHistory = {
    'diabetic': false,
    'hta': false,
    'douleur_thorasique': false,
    'dialysis': false,
    'distresse_respiratoire': false,
    'hypalepsie': false,
    'coronaria': false,
  };

  // Patient needs checkboxes with quantities
  Map<String, dynamic> patientNeeds = {
    'oxygen': {'selected': false, 'quantity': ''},
    'perfusion': {'selected': false, 'type': 'serum glucose', 'quantity': ''},
    'monitorage': {'selected': false, 'quantity': ''},
    'pensement': {'selected': false, 'quantity': ''},
    'immobilisation': {'selected': false, 'quantity': ''},
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Combine first and last name into one field
    String fullName = '';
    if (widget.mission.patientFirstName != null ||
        widget.mission.patientLastName != null) {
      fullName =
          '${widget.mission.patientFirstName ?? ''} ${widget.mission.patientLastName ?? ''}'
              .trim();
    }
    _patientNameController = TextEditingController(text: fullName);
    _ageController =
        TextEditingController(text: widget.mission.patientAge ?? '');
    _motifTransportController = TextEditingController();
    _taController = TextEditingController();
    _spo2Controller = TextEditingController();
    _fcController = TextEditingController();
    _frController = TextEditingController();
    _temperatureController = TextEditingController();
    _glucoseController = TextEditingController();

    _loadExistingData();
  }

  void _loadExistingData() {
    // Load existing vital signs if available
    if (widget.mission.vitalSigns != null &&
        widget.mission.vitalSigns!.isNotEmpty) {
      try {
        final vitalSignsData = widget.mission.vitalSigns!;
        _taController.text = vitalSignsData['ta']?.toString() ?? '';
        _spo2Controller.text = vitalSignsData['spo2']?.toString() ?? '';
        _fcController.text = vitalSignsData['fc']?.toString() ?? '';
        _frController.text = vitalSignsData['fr']?.toString() ?? '';
        _temperatureController.text =
            vitalSignsData['temperature']?.toString() ?? '';
        _glucoseController.text = vitalSignsData['glucose']?.toString() ?? '';
      } catch (e) {
        debugPrint('[MissionTechnicalSheet] Error loading vital signs: $e');
      }
    }

    // Load existing medical history
    if (widget.mission.medicalHistory != null &&
        widget.mission.medicalHistory!.isNotEmpty) {
      try {
        final historyData = widget.mission.medicalHistory!;
        for (var item in historyData) {
          if (medicalHistory.containsKey(item)) {
            medicalHistory[item] = true;
          }
        }
      } catch (e) {
        debugPrint('[MissionTechnicalSheet] Error loading medical history: $e');
      }
    }

    // Load existing patient needs
    if (widget.mission.patientNeeds != null &&
        widget.mission.patientNeeds!.isNotEmpty) {
      try {
        final needsData = widget.mission.patientNeeds!;
        for (var item in needsData) {
          if (patientNeeds.containsKey(item)) {
            patientNeeds[item]['selected'] = true;
          }
        }
      } catch (e) {
        debugPrint('[MissionTechnicalSheet] Error loading patient needs: $e');
      }
    }

    // Load existing motif de transport
    if (widget.mission.fracturesInjuries != null) {
      _motifTransportController.text = widget.mission.fracturesInjuries!;
    }

    // Load existing report type
    if (widget.mission.reportType != null) {
      _reportType = widget.mission.reportType!;
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _ageController.dispose();
    _motifTransportController.dispose();
    _taController.dispose();
    _spo2Controller.dispose();
    _fcController.dispose();
    _frController.dispose();
    _temperatureController.dispose();
    _glucoseController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    // Validate required fields
    if (_patientNameController.text.isEmpty || _ageController.text.isEmpty) {
      _showSnackbar('Veuillez remplir le nom et l\'âge du patient', Colors.red);
      return;
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
        'ta': _taController.text.isEmpty ? null : _taController.text,
        'spo2': _spo2Controller.text.isEmpty ? null : _spo2Controller.text,
        'fc': _fcController.text.isEmpty ? null : _fcController.text,
        'fr': _frController.text.isEmpty ? null : _frController.text,
        'temperature': _temperatureController.text.isEmpty
            ? null
            : _temperatureController.text,
        'glucose':
            _glucoseController.text.isEmpty ? null : _glucoseController.text,
      };

      // Prepare medical history
      List<String> medicalHistoryList = medicalHistory.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Prepare patient needs
      Map<String, dynamic> needsData = {};
      patientNeeds.forEach((key, value) {
        if (value['selected']) {
          // For perfusion, save both type and quantity
          if (key == 'perfusion') {
            needsData[key] = {
              'type': value['type'] ?? 'serum glucose',
              'quantity': value['quantity'] ?? '',
            };
          } else {
            // For other items, just save quantity
            needsData[key] = value['quantity'] ?? '';
          }
        }
      });

      // Update mission in Supabase
      await _missionService.updateMissionField(
          widget.mission.id, 'patient_first_name', firstName);
      await _missionService.updateMissionField(
          widget.mission.id, 'patient_last_name', lastName);
      await _missionService.updateMissionField(
          widget.mission.id, 'patient_age', _ageController.text);
      // Store motif de transport in fractures_injuries
      await _missionService.updateMissionField(
          widget.mission.id,
          'fractures_injuries',
          _motifTransportController.text.isEmpty
              ? null
              : _motifTransportController.text);
      await _missionService.updateMissionField(
          widget.mission.id, 'report_type', _reportType);

      // ALWAYS save vital signs (not conditional on report type)
      await _missionService.updateMissionField(
          widget.mission.id, 'vital_signs', jsonEncode(vitalSigns));

      if (_reportType == 'simple_transport') {
        await _missionService.updateMissionField(widget.mission.id,
            'medical_history', jsonEncode(medicalHistoryList));
        // Store patient needs as JSON: {"oxygen": "quantity", "perfusion": "quantity", ...}
        await _missionService.updateMissionField(
            widget.mission.id, 'patient_needs', jsonEncode(needsData));
      } else if (_reportType == 'deceased') {
        // For deceased, store empty patient needs
        await _missionService.updateMissionField(
            widget.mission.id, 'patient_needs', jsonEncode({}));
      }

      if (mounted) {
        _showSnackbar('Rapport enregistré avec succès!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Erreur lors de l\'enregistrement du rapport: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
        padding: const EdgeInsets.all(16.0),
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
            _buildTextField('Motif de Transport', _motifTransportController,
                'e.g. fracture - douleur torasique - avc - prearret'),
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
              Row(
                children: [
                  Expanded(
                    child: _buildVitalSignField(
                        'TA (MMHG)', _taController, '120/80'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField('FC (BPM)', _fcController, '72'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        _buildVitalSignField('SpO2 (%)', _spo2Controller, '98'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child:
                        _buildVitalSignField('FR (RES/MIN)', _frController, ''),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildVitalSignField(
                        'Temp (°C)', _temperatureController, ''),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        _buildVitalSignField('Glucose', _glucoseController, ''),
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
              _buildCheckboxGroup(medicalHistory, [
                ('Diabétique', 'diabetic'),
                ('HTA', 'hta'),
                ('Douleur Thoracique', 'douleur_thorasique'),
                ('Dialyse', 'dialysis'),
                ('Détresse Respiratoire', 'distresse_respiratoire'),
                ('Hypotension', 'hypalepsie'),
                ('Maladie Coronarienne', 'coronaria'),
              ]),
              const SizedBox(height: 24),

              // Patient Needs (Checkboxes with Quantities)
              _buildSectionHeader('🏥 Besoins du Patient'),
              const SizedBox(height: 12),
              _buildPatientNeedsGroup(),
              const SizedBox(height: 24),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitReport,
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
            hintText: hint,
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
            hintText: hint,
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
            hintText: hint,
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

  Widget _buildPatientNeedsGroup() {
    return Column(
      children: patientNeeds.keys.map((key) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: key == 'perfusion'
              ? _buildPerfusionNeedRow()
              : Row(
                  children: [
                    Checkbox(
                      value: patientNeeds[key]['selected'],
                      onChanged: (value) {
                        setState(() {
                          patientNeeds[key]['selected'] = value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(_formatLabel(key)),
                    ),
                    if (patientNeeds[key]['selected'])
                      SizedBox(
                        width: 100,
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              patientNeeds[key]['quantity'] = value;
                            });
                          },
                          decoration: InputDecoration(
                          hintText: 'Qté',
                            filled: true,
                            fillColor: AppColors.lightPink,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                  ],
                ),
        );
      }).toList(),
    );
  }

  Widget _buildPerfusionNeedRow() {
    return Row(
      children: [
        Checkbox(
          value: patientNeeds['perfusion']['selected'],
          onChanged: (value) {
            setState(() {
              patientNeeds['perfusion']['selected'] = value ?? false;
            });
          },
        ),
        Expanded(
          child: Text('Perfusion'),
        ),
        if (patientNeeds['perfusion']['selected'])
          Row(
            children: [
              SizedBox(
                width: 120,
                child: DropdownButton<String>(
                  value: patientNeeds['perfusion']['type'] ?? 'serum glucose',
                  onChanged: (value) {
                    setState(() {
                      patientNeeds['perfusion']['type'] =
                          value ?? 'serum glucose';
                    });
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'serum glucose',
                      child: Text('Sérum Glucose'),
                    ),
                    DropdownMenuItem(
                      value: 'serum fusé',
                      child: Text('Serum Fusé'),
                    ),
                  ],
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      patientNeeds['perfusion']['quantity'] = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Qty',
                    filled: true,
                    fillColor: AppColors.lightPink,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
      ],
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
}
