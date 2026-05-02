import 'package:flutter/material.dart';
import '../../config/constants.dart';
import 'settings_provider.dart';
import 'optimized_widgets.dart';

/// Fleet & Driver Configuration Section
/// Extracted into separate stateless widget to prevent full-screen rebuilds
class FleetDriverConfigurationSection extends StatelessWidget {
  final SettingsProvider settings;

  const FleetDriverConfigurationSection({
    required this.settings,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ambulance Types - with lazy loading support
        _buildAmbulanceTypesCard(context),
        const SizedBox(height: 20),

        // Maintenance Rules
        _buildMaintenanceRulesCard(context),
        const SizedBox(height: 20),

        // Logistics Toggles
        _buildLogisticsCard(context),
        const SizedBox(height: 20),

        // Shift Architecture
        _buildShiftArchitectureCard(context),
        const SizedBox(height: 20),

        // Security Protocols
        _buildSecurityProtocolsCard(context),
        const SizedBox(height: 20),

        // Geo-Fencing
        _buildGeoFencingCard(context),
      ],
    );
  }

  Widget _buildAmbulanceTypesCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.medical_services,
      title: 'Ambulance Types Management',
      actionButton: 'ADD TYPE',
      children: [
        ValueListenableBuilder<List<String>>(
          valueListenable: settings.ambulanceTypes,
          builder: (context, types, _) {
            return Column(
              children: types
                  .asMap()
                  .entries
                  .map((e) => _buildAmbulanceTypeCard(e.key, e.value))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAmbulanceTypeCard(int index, String type) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Type $index',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  type,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceRulesCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.build,
      title: 'Maintenance Rules',
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: settings.autoFlagForService,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Auto-Flag for Service',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.autoFlagForService, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.preventDispatch,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Prevent Dispatch > 3k mi',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.preventDispatch, v),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogisticsCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.inventory_2,
      title: 'Logistics Toggles',
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: settings.fuelConsumptionAPI,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Fuel Consumption API',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.fuelConsumptionAPI, v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.odometrySync,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Odometer Sync',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.odometrySync, v),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShiftArchitectureCard(BuildContext context) {
    return _DarkCard(
      icon: Icons.schedule,
      title: 'Shift Architecture',
      children: [
        ValueListenableBuilder<int>(
          valueListenable: settings.maxContinuousHours,
          builder: (context, value, _) {
            return OptimizedWidgets.infoRow(
              label: 'MAX CONTINUOUS HOURS',
              value: '${value}h',
              isDark: true,
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<String>(
          valueListenable: settings.shiftRotationMode,
          builder: (context, value, _) {
            return OptimizedWidgets.dropdownRow(
              context,
              label: 'SHIFT ROTATION MODE',
              value: value,
              items: ['24/48 Rotation', '12/12 Rotation', 'Variable'],
              onChanged: (v) {
                if (v != null)
                  settings.updateSetting(settings.shiftRotationMode, v);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSecurityProtocolsCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.security,
      title: 'Security Protocols',
      children: [
        ValueListenableBuilder<int>(
          valueListenable: settings.inactivityTimeout,
          builder: (context, value, _) {
            return OptimizedWidgets.sliderRow(
              context,
              label: 'INACTIVITY TIMEOUT (MIN)',
              value: value.toDouble(),
              min: 5,
              max: 60,
              onChanged: (v) =>
                  settings.updateSetting(settings.inactivityTimeout, v.toInt()),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: settings.forceEncryptedLogs,
          builder: (context, value, _) {
            return OptimizedWidgets.toggleWithSubtitle(
              context,
              label: 'Force Encrypted Logs',
              subtitle: 'HIPAA compliant logging',
              value: value,
              onChanged: (v) =>
                  settings.updateSetting(settings.forceEncryptedLogs, v),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGeoFencingCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.place,
      title: 'Geo-Fencing Boundaries',
      children: [
        Text(
          'Establish virtual operational perimeters for active units. Fleet vehicles will trigger an alert if the primary jurisdiction radius is breached.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<double>(
          valueListenable: settings.geoFencingRadius,
          builder: (context, value, _) {
            return OptimizedWidgets.sliderRow(
              context,
              label: 'OPERATIONAL RADIUS',
              value: value,
              min: 5,
              max: 50,
              suffix: 'KM',
              onChanged: (v) =>
                  settings.updateSetting(settings.geoFencingRadius, v),
            );
          },
        ),
        const SizedBox(height: 20),
        // Map placeholder (lazy loaded)
        _buildMapPlaceholder(context),
      ],
    );
  }

  Widget _buildMapPlaceholder(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: settings.geoFencingRadius,
      builder: (context, radius, _) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.blue[50],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Map View (${radius.toStringAsFixed(1)} KM)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable section card widget
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

/// Reusable dark card widget
class _DarkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _DarkCard({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null) ...[
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[300],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Column(children: children),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
