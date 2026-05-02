import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/mission_model.dart';
import '../models/user_model.dart';
import '../services/mission_service.dart';
import '../utils/responsive.dart';

class MissionDetailsScreen extends StatefulWidget {
  final Mission mission;
  final User user;

  const MissionDetailsScreen({
    Key? key,
    required this.mission,
    required this.user,
  }) : super(key: key);

  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen> {
  final MissionService _missionService = MissionService();
  late Mission _mission;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mission = widget.mission;
  }

  Future<void> _updateMissionStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      print(
          '[MissionDetails] Updating mission ${_mission.id} to status: $newStatus');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('⏳ Mise à jour en cours (${newStatus.toUpperCase()})...'),
          duration: const Duration(seconds: 2),
        ),
      );

      await _missionService.updateMissionStatus(_mission.id, newStatus);

      // Add delay to ensure backend sync
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _mission = Mission(
            id: _mission.id,
            missionNumber: _mission.missionNumber,
            missionDate: _mission.missionDate,
            fromLocation: _mission.fromLocation,
            toLocation: _mission.toLocation,
            patientPhone: _mission.patientPhone,
            status: newStatus,
            priority: _mission.priority,
            ambulanceId: _mission.ambulanceId,
          );
        });

        print('[MissionDetails] Mission status updated successfully');

        // Get emoji for status
        String emoji = '✅';
        if (newStatus == 'cancelled') emoji = '❌';
        if (newStatus == 'active') emoji = '🚀';
        if (newStatus == 'arrived') emoji = '📍';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$emoji Mission ${newStatus.toUpperCase()} avec succès!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // For completed/cancelled missions, go back after a brief delay to allow new mission acceptance
        if (newStatus == 'completed' || newStatus == 'cancelled') {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      }
    } catch (e) {
      print('[MissionDetails] ERROR: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getPriorityColor() {
    switch (_mission.priority.toLowerCase()) {
      case 'critical':
        return AppColors.primary;
      case 'high':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getPriorityLabel() {
    return _mission.priority.toUpperCase();
  }

  String _getStatusLabel() {
    switch (_mission.status.toLowerCase()) {
      case 'active':
        return 'ACTIVE';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mission Control'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPriorityColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.responsive.paddingValueLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mission Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPriorityColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MISSION #${_mission.missionNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'PRIORITY: ${_getPriorityLabel()}',
                          style: TextStyle(
                            color: _getPriorityColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Patient Contact
                  if (_mission.patientPhone != null) ...[
                    Text(
                      'PATIENT CONTACT',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _mission.patientPhone!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.call,
                            color: _getPriorityColor(),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Locations
            Row(
              children: [
                Icon(Icons.location_on, color: _getPriorityColor(), size: 20),
                const SizedBox(width: 8),
                Text(
                  'FROM',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _mission.fromLocation ?? 'No location',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'TO',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _mission.toLocation ?? 'No location',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),

            // Map Placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Map Integration',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Technical Sheet
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: Colors.grey[700]),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mission Technical Sheet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Vitals: Stable | Equipment: Gurney, O2',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (_mission.status.toLowerCase() == 'pending')
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _updateMissionStatus('active'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle),
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
                        : const Text('ACCEPT MISSION'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _updateMissionStatus('cancelled'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('DECLINE'),
                  ),
                ],
              )
            else if (_mission.status.toLowerCase() == 'active')
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _updateMissionStatus('arrived'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('MARK ARRIVED: ${12.5}%'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _updateMissionStatus('completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('COMPLETE'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _updateMissionStatus('cancelled'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('CANCEL'),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Mission is ${_mission.status}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
