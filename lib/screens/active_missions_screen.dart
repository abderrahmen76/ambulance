import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../models/mission_model.dart';
import '../models/user_model.dart';
import '../services/mission_service.dart';
import '../services/pdf_service.dart';
import 'mission_technical_sheet_screen.dart';

class ActiveMissionsScreen extends StatefulWidget {
  final User user;
  final String ambulanceId;

  const ActiveMissionsScreen({
    Key? key,
    required this.user,
    required this.ambulanceId,
  }) : super(key: key);

  @override
  State<ActiveMissionsScreen> createState() => _ActiveMissionsScreenState();
}

class _ActiveMissionsScreenState extends State<ActiveMissionsScreen> {
  final MissionService _missionService = MissionService();
  late Future<List<Mission>> _allMissionsFuture;
  String _selectedStatus = 'active'; // active, completed, cancelled

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  void _loadMissions() {
    if (mounted) {
      setState(() {
        _allMissionsFuture =
            _missionService.getMissionsForAmbulance(widget.ambulanceId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Status Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildStatusTab('Actif', 'active'),
                const SizedBox(width: 8),
                _buildStatusTab('Complétée', 'completed'),
                const SizedBox(width: 8),
                _buildStatusTab('Annulée', 'cancelled'),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
          // Missions List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                _loadMissions();
                return _allMissionsFuture;
              },
              child: FutureBuilder<List<Mission>>(
                future: _allMissionsFuture,
                        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            debugPrint('Mission loading error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[300],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur lors du chargement des missions',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red[600],
                          ),
                    ),
                  ),
                ],
              ),
            );
          }

          final allMissions = snapshot.data ?? [];
          final filteredMissions = allMissions
              .where((mission) => mission.status == _selectedStatus)
              .toList();

          if (filteredMissions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedStatus == 'active'
                        ? Icons.assignment_turned_in
                        : _selectedStatus == 'completed'
                            ? Icons.check_circle
                            : Icons.cancel,
                    color: Colors.grey[400],
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune mission ${_selectedStatus == 'active' ? 'active' : _selectedStatus == 'completed' ? 'complétée' : 'annulée'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return _buildMissionsList(context, filteredMissions);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String status) {
    final isSelected = _selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatus = status;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionsList(BuildContext context, List<Mission> missions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: missions.asMap().entries.map((entry) {
          final mission = entry.value;
          final isActive = _selectedStatus == 'active';
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildMissionCardCompact(context, mission, isActive),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMissionCardCompact(BuildContext context, Mission mission, bool isActive) {
    final isPriority = (mission.priority ?? '').toUpperCase() == 'CRITICAL';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MISSION #${mission.missionNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mission.missionDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPriority ? Colors.orange : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPriority ? 'CRITICAL' : 'NORMAL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Locations
          Row(
            children: [
              Icon(Icons.location_on,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.fromLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mission.toLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Patient and Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Infirmier',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    mission.infirmierName ?? 'Non assigné',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (mission.patientPhone != null)
                ElevatedButton.icon(
                  onPressed: !kIsWeb ? () => _makePhoneCall(mission.patientPhone!) : null,
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Appeler'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Payment Status
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paiement: ${mission.isPaid == true ? 'PAYÉ' : 'NON PAYÉ'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mission.isPaid == true ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                    mission.paymentType ?? 'Non spécifié',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons (only for active missions)
          if (isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showActionConfirmation(
                        context, 'COMPLETE', 'completed', mission),
                    icon: const Icon(Icons.check, size: 16),
                  label: const Text('Compléter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showActionConfirmation(
                        context, 'CANCEL', 'cancelled', mission),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Annuler'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MissionTechnicalSheetScreen(mission: mission),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Détails'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            // Print Button (if report_type is filled)
            if (mission.reportType != null && mission.reportType!.isNotEmpty && mission.reportType != 'not_filled') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateMissionPDF(context, mission),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Imprimer la Fiche'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MissionTechnicalSheetScreen(mission: mission),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Voir Détails'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                // Print Button for completed/cancelled missions
                if (mission.reportType != null && mission.reportType!.isNotEmpty && mission.reportType != 'not_filled') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _generateMissionPDF(context, mission),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Imprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showActionConfirmation(
      BuildContext context, String action, String newStatus, Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer l\'Action'),
        content: Text('Êtes-vous sûr de vouloir ${action.toLowerCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _missionService.updateMissionStatus(mission.id, newStatus);
                
                // Reload missions after successful update
                if (mounted) {
                  _loadMissions();
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${action} réussie!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de lancer l\'appel téléphonique: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditDialog(BuildContext context, String title, String initialValue,
      String fieldKey, Mission mission) {
    final controller = TextEditingController(text: initialValue);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Modifier $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Entrez $title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _updateMissionField(mission, fieldKey, controller.text);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMissionField(
      Mission mission, String fieldKey, String newValue) async {
    try {
      await _missionService.updateMissionField(mission.id, fieldKey, newValue);
      
      // Reload missions after successful update
      if (mounted) {
        _loadMissions();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mis à jour avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePaymentStatus(Mission mission) async {
    try {
      final newStatus = !(mission.isPaid ?? false);
      await _missionService.updateMissionField(
        mission.id,
        'is_paid',
        newStatus,
      );
      
      // Reload missions after successful update
      if (mounted) {
        _loadMissions();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut du paiement mis à jour en ${newStatus ? 'PAYÉ' : 'NON PAYÉ'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPaymentStatusDialog(BuildContext context, Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le Statut de Paiement'),
        content: const Text('Sélectionner le statut de paiement:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updatePaymentStatus(mission, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Marquer comme PAYÉ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updatePaymentStatus(mission, false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Marquer comme NON PAYÉ'),
          ),
        ],
      ),
    );
  }

  void _showPaymentTypeDialog(BuildContext context, Mission mission) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sélectionner le Type de Paiement'),
        content: const Text('Choisir comment le patient paiera:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updatePaymentType(mission, 'cash');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Liquide'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updatePaymentType(mission, 'sur charge');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Sur Charge'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePaymentStatus(Mission mission, bool isPaid) async {
    try {
      await _missionService.updateMissionField(
        mission.id,
        'payment_status',
        isPaid,
      );
      
      // Reload missions after successful update
      _loadMissions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut du paiement mis à jour en ${isPaid ? 'PAYÉ' : 'NON PAYÉ'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePaymentType(Mission mission, String paymentType) async {
    try {
      await _missionService.updateMissionField(
        mission.id,
        'payment_type',
        paymentType,
      );
      
      // Reload missions after successful update
      if (mounted) {
        _loadMissions();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Type de paiement mis à jour en $paymentType'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateMissionPDF(BuildContext context, Mission mission) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Génération du PDF...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Generate and download PDF
      await PdfService.generateMissionReportPdf(mission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF généré avec succès!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ActiveMissionsScreen] PDF generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

