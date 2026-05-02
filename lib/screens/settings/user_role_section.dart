import 'package:flutter/material.dart';
import '../../config/constants.dart';
import 'settings_provider.dart';

/// User & Role Setup Section
/// Handles role templates and permissions with optimized DataTable
class UserRoleSetupSection extends StatefulWidget {
  final SettingsProvider settings;

  const UserRoleSetupSection({
    required this.settings,
    Key? key,
  }) : super(key: key);

  @override
  State<UserRoleSetupSection> createState() => _UserRoleSetupSectionState();
}

class _UserRoleSetupSectionState extends State<UserRoleSetupSection> {
  late Map<String, Map<String, bool>> permissions;

  @override
  void initState() {
    super.initState();
    // Initialize with default permissions
    permissions = {
      'users': {'create': true, 'read': true, 'update': true},
      'dispatch': {'create': true, 'read': true, 'update': false},
      'reports': {'create': false, 'read': true, 'update': false},
      'fleet': {'create': true, 'read': true, 'update': true},
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRoleTemplatesCard(context),
        const SizedBox(height: 24),
        _buildPermissionMatrixCard(context),
        const SizedBox(height: 24),
        _buildAdvancedSecurityCard(context),
      ],
    );
  }

  Widget _buildRoleTemplatesCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ROLE TEMPLATES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _buildRoleTemplate(
            'Admin', 'Full System Sovereignty', Icons.admin_panel_settings),
        const SizedBox(height: 10),
        _buildRoleTemplate('Manager', 'Fleet & Dispatch Control', Icons.people),
        const SizedBox(height: 10),
        _buildRoleTemplate(
            'Driver', 'Logistics & Route Access', Icons.person_outline),
      ],
    );
  }

  Widget _buildRoleTemplate(String name, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildPermissionMatrixCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.security,
      title: 'Permission Matrix',
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Editing Role: Fleet Manager',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.amber[900],
            ),
          ),
        ),
        // Optimized table with virtualization for large permission sets
        _buildOptimizedPermissionTable(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () {},
              child: const Text('Discard Changes'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[900],
              ),
              child: const Text(
                'Save Role Definition',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptimizedPermissionTable() {
    // Use SingleChildScrollView with limited height to prevent UI jank
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 32,
        ),
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(
              label: Text(
                'MODULE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'CREATE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'READ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'UPDATE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          rows: permissions.entries.map((entry) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  _buildPermissionCheckbox(
                    value: true,
                    onChanged: (v) {
                      setState(() {
                        permissions[entry.key]!['create'] = v;
                      });
                    },
                  ),
                ),
                DataCell(
                  _buildPermissionCheckbox(
                    value: true,
                    onChanged: (v) {
                      setState(() {
                        permissions[entry.key]!['read'] = v;
                      });
                    },
                  ),
                ),
                DataCell(
                  _buildPermissionCheckbox(
                    value: entry.value['update'] ?? false,
                    onChanged: (v) {
                      setState(() {
                        permissions[entry.key]!['update'] = v;
                      });
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPermissionCheckbox({
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: value ? AppColors.success : Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: value ? AppColors.success : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: value
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _buildAdvancedSecurityCard(BuildContext context) {
    return _DarkCard(
      icon: Icons.shield,
      title: 'Advanced Security Protocol',
      subtitle:
          'Implementing Multi-Factor Authentication (MFA) and Biometric logs for high-clearance dispatch roles ensures audit-ready compliance.',
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[900],
                ),
                child: const Text(
                  'CONFIGURE MFA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  'VIEW SECURITY LOGS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
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

/// Reusable dark card
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
