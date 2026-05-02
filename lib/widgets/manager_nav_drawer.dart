import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../screens/notifications_list_screen.dart';

/// Right-side navigation drawer for manager views.
class ManagerNavDrawer extends StatelessWidget {
  final User user;
  final int selectedIndex;
  final GlobalKey<ScaffoldState> scaffoldState;
  final Function(int) onNavItemTapped;
  final VoidCallback onLogout;

  const ManagerNavDrawer({
    required this.user,
    required this.selectedIndex,
    required this.scaffoldState,
    required this.onNavItemTapped,
    required this.onLogout,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'AmbuGestion',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Manager',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildNavItem(
                    context: context,
                    icon: Icons.home,
                    label: 'Accueil',
                    index: 0,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.assignment,
                    label: 'Missions',
                    index: 1,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.local_shipping,
                    label: 'Parc',
                    index: 2,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.medical_services,
                    label: 'Équipements',
                    index: 3,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.history,
                    label: 'Historique',
                    index: 4,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.badge,
                    label: 'Shifts',
                    index: 5,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.map,
                    label: 'Suivi Temps Réel',
                    index: 6,
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.settings,
                    label: 'Paramètres',
                    index: 7,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(scaffoldState.currentContext!);
                        Navigator.push(
                          scaffoldState.currentContext!,
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationsListScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_outlined, size: 18),
                      label: const Text('Notifications'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.name.isNotEmpty ? user.name : 'Manager',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(scaffoldState.currentContext!);
                        onLogout();
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Déconnexion'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color:
            isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.pop(scaffoldState.currentContext!);
            onNavItemTapped(index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : Colors.grey.shade600,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
