import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../config/constants.dart';
import '../utils/responsive.dart';
import 'admin_tenants_screen.dart';
import 'admin_users_screen.dart';
import 'admin_ambulances_screen.dart';

/// Admin Dashboard Screen
/// Main interface for system administrators
/// Provides access to: Tenants, Users, Ambulances management
class AdminDashboardScreen extends StatefulWidget {
  final User user;

  const AdminDashboardScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminService = AdminService();
  final _authService = AuthService();
  int _selectedTabIndex = 0;

  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    print('[AdminDashboard] Initializing for user: ${widget.user.name}');
    _statsFuture = _adminService.getDashboardStats();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red[700],
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Admin: ${widget.user.name}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: DefaultTabController(
        length: 3,
        initialIndex: _selectedTabIndex,
        child: Column(
          children: [
            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                tabs: const [
                  Tab(
                    icon: Icon(Icons.business),
                    text: 'Tenants',
                  ),
                  Tab(
                    icon: Icon(Icons.people),
                    text: 'Users',
                  ),
                  Tab(
                    icon: Icon(Icons.local_taxi),
                    text: 'Ambulances',
                  ),
                ],
                labelColor: Colors.red[700],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.red[700],
              ),
            ),

            // Statistics
            FutureBuilder<Map<String, dynamic>>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final stats = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Tenants',
                          stats['total_tenants'].toString(),
                          Icons.business,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Users',
                          stats['total_users'].toString(),
                          Icons.people,
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Ambulances',
                          stats['total_ambulances'].toString(),
                          Icons.local_taxi,
                          Colors.orange,
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  // Tenants Tab
                  AdminTenantsScreen(user: widget.user),

                  // Users Tab
                  AdminUsersScreen(user: widget.user),

                  // Ambulances Tab
                  AdminAmbulancesScreen(user: widget.user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
