import 'package:flutter/material.dart';
import '../services/custom_clinic_service.dart';
import '../utils/responsive.dart';

/// Dialog for adding a custom clinic
class CustomClinicDialog extends StatefulWidget {
  final Function(String) onClinicAdded;
  final String? city;

  const CustomClinicDialog({
    required this.onClinicAdded,
    this.city,
    Key? key,
  }) : super(key: key);

  @override
  State<CustomClinicDialog> createState() => _CustomClinicDialogState();
}

class _CustomClinicDialogState extends State<CustomClinicDialog> {
  final TextEditingController _clinicController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _clinicController.dispose();
    super.dispose();
  }

  Future<void> _saveClinic() async {
    final clinicName = _clinicController.text.trim();

    if (clinicName.isEmpty) {
      setState(() {
        _errorMessage = 'Le nom de la clinique ne peut pas être vide';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await CustomClinicService()
          .addCustomClinic(clinicName, widget.city ?? 'Sfax');

      if (success) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onClinicAdded(clinicName);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clinique "$clinicName" ajoutée avec succès'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Clinique déjà existe ou erreur lors de l\'ajout';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive(context);
    final isMobile = responsive.isPhone;

    return AlertDialog(
      title: const Text('Ajouter une nouvelle clinique'),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _clinicController,
              decoration: InputDecoration(
                hintText: 'ex: Clinique Privée Sfax',
                labelText: 'Nom de la clinique',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _saveClinic(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveClinic,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ajouter'),
        ),
      ],
    );
  }
}
