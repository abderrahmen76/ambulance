import 'package:flutter/material.dart';
import '../services/custom_clinic_service.dart';
import 'custom_clinic_dialog.dart';
import '../config/constants.dart';

/// Reusable clinic selection dropdown with custom clinic support
class ClinicDropdownField extends StatefulWidget {
  final String value;
  final Function(String) onChanged;
  final String? selectedCity;

  const ClinicDropdownField({
    required this.value,
    required this.onChanged,
    this.selectedCity,
    Key? key,
  }) : super(key: key);

  @override
  State<ClinicDropdownField> createState() => _ClinicDropdownFieldState();
}

class _ClinicDropdownFieldState extends State<ClinicDropdownField> {
  late List<String> _clinics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  @override
  void didUpdateWidget(ClinicDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload clinics when the selected city changes
    if (oldWidget.selectedCity != widget.selectedCity) {
      setState(() => _isLoading = true);
      _loadClinics();
    }
  }

  /// Filter out reserved option names to prevent dropdown duplicates
  List<String> _filterClinics(List<String> clinics) {
    return clinics
        .where(
            (c) => c != 'Autre (Ajouter une nouvelle)' && c.trim().isNotEmpty)
        .toList();
  }

  Future<void> _loadClinics() async {
    try {
      final clinics = await CustomClinicService()
          .getClinicsByCity(widget.selectedCity ?? 'Sfax');
      setState(() {
        _clinics = clinics;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading clinics for city ${widget.selectedCity}: $e');
      setState(() {
        _isLoading = false;
        // Fallback to empty list on error
        _clinics = [];
      });
    }
  }

  void _showCustomClinicDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomClinicDialog(
        city: widget.selectedCity ?? 'Sfax',
        onClinicAdded: (clinicName) {
          // Update the parent's selected value
          widget.onChanged(clinicName);
          // Reload clinics list
          _loadClinics();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return DropdownButtonFormField<String>(
        value: widget.value,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        items: [
          DropdownMenuItem(
            value: widget.value,
            child: const Text('Chargement...'),
          ),
        ],
        onChanged: null,
      );
    }

    // Show only custom clinics + Autre option, filtering out duplicates
    final filteredClinics = _filterClinics(_clinics);
    final displayClinics = [
      '',
      ...filteredClinics,
      'Autre (Ajouter une nouvelle)'
    ];

    // Determine the value - must be in displayClinics
    String dropdownValue = widget.value;
    if (!displayClinics.contains(widget.value)) {
      // If the passed value is not in the list, keep it empty
      dropdownValue = '';
    }

    return DropdownButtonFormField<String>(
      value: dropdownValue,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      selectedItemBuilder: (context) {
        return displayClinics.map((clinic) {
          return Text(
            clinic.isEmpty ? '-- Sélectionner une clinique --' : clinic,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        }).toList();
      },
      items: displayClinics.map<DropdownMenuItem<String>>((clinic) {
        // Empty option
        if (clinic.isEmpty) {
          return DropdownMenuItem<String>(
            value: '',
            child: const Text('-- Sélectionner une clinique --'),
          );
        }

        final isCustom = clinic != 'Autre (Ajouter une nouvelle)';

        return DropdownMenuItem<String>(
          value: clinic,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    clinic,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCustom)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        Navigator.pop(context);
                        // Show confirmation dialog
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer la clinique'),
                            content: Text(
                                'Êtes-vous sûr de vouloir supprimer "$clinic"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final success = await CustomClinicService()
                              .deleteCustomClinic(
                                  clinic, widget.selectedCity ?? 'Sfax');
                          if (success && mounted) {
                            _loadClinics();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Clinique "$clinic" supprimée'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          if (value == 'Autre (Ajouter une nouvelle)') {
            _showCustomClinicDialog();
          } else {
            widget.onChanged(value);
          }
        }
      },
    );
  }
}
