import 'package:flutter/material.dart';
import '../../config/constants.dart';
import 'settings_provider.dart';
import 'optimized_widgets.dart';

/// System Rules Section
/// Handles dispatch logic and priority configurations
class SystemRulesSection extends StatelessWidget {
  final SettingsProvider settings;

  const SystemRulesSection({
    required this.settings,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTrackingAndMissionCard(context),
        const SizedBox(height: 20),
        _buildFleetSettingsCard(context),
        const SizedBox(height: 20),
        _buildDriverSettingsCard(context),
      ],
    );
  }

  Widget _buildTrackingAndMissionCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.track_changes,
      title: 'Tracking & Mission Settings',
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: settings.forceTracking,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Force Tracking',
              subtitle: 'GPS tracking is mandatory',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.forceTracking, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.autoAssignMissions,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Auto-Assign Missions',
              subtitle: 'Automatically assign calls to available units',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.autoAssignMissions, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<String>(
          valueListenable: settings.priorityRule,
          builder: (context, value, _) {
            return OptimizedWidgets.dropdownRow(
              context,
              label: 'DISPATCH PRIORITY RULE',
              value: value,
              items: ['fastest', 'nearest', 'specific_unit'],
              onChanged: (v) {
                if (v != null) settings.updateSetting(settings.priorityRule, v);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFleetSettingsCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.directions_car,
      title: 'Fleet Settings',
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: settings.maintenanceMode,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Maintenance Mode',
              subtitle: 'Disable units that are under maintenance',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.maintenanceMode, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.fuelTracking,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Fuel Tracking',
              subtitle: 'Track fuel consumption per unit',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.fuelTracking, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.kilometrageTracking,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Kilometrage Tracking',
              subtitle: 'Monitor vehicle mileage and maintenance intervals',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.kilometrageTracking, v),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDriverSettingsCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.people,
      title: 'Driver Settings',
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: settings.shiftSystem,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Shift System',
              subtitle: 'Enable shift-based driver scheduling',
              value: value,
              onChanged: (v) => settings.updateSetting(settings.shiftSystem, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<int>(
          valueListenable: settings.autoLogoutMinutes,
          builder: (context, value, _) {
            return OptimizedWidgets.sliderRow(
              context,
              label: 'AUTO-LOGOUT IDLE TIME',
              value: value.toDouble(),
              min: 5,
              max: 120,
              suffix: 'MIN',
              onChanged: (v) =>
                  settings.updateSetting(settings.autoLogoutMinutes, v.toInt()),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.geoFencing,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Geo-Fencing',
              subtitle: 'Restrict driver movement to defined zones',
              value: value,
              onChanged: (v) => settings.updateSetting(settings.geoFencing, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.driverAvailabilityRules,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Driver Availability Rules',
              subtitle: 'Enforce mandatory breaks and rest periods',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.driverAvailabilityRules, v),
            );
          },
        ),
      ],
    );
  }
}

/// Reusable section card
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final String? actionButton;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (actionButton != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      actionButton!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
