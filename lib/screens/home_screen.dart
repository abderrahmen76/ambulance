import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../utils/responsive.dart';
import '../models/ambulance_model.dart';
import '../services/ambulance_service.dart';
import '../services/auth_service.dart';

/// Home Screen - Driver Dashboard
/// Displays driver info and assigned ambulance details
/// Optimized for fast loading and performance
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _ambulanceService = AmbulanceService();

  late Future<Ambulance?> _ambulanceFuture;

  @override
  void initState() {
    super.initState();
    print('\n🏠 [HOME SCREEN] initState() called');

    // Start fetching ambulance data immediately
    if (_authService.cachedUser != null) {
      print('👤 [HOME SCREEN] User found: ${_authService.cachedUser!.name}');
      print('⏳ [HOME SCREEN] Starting ambulance data fetch...');

      _ambulanceFuture =
          _ambulanceService.getAmbulanceForDriver(_authService.cachedUser!.id);
    }
  }

  /// Handle logout
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
    final user = _authService.cachedUser;

    if (user == null) {
      // User not logged in, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Driver App',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.responsive.paddingValueLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Welcome Message
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Hi, ',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                    ),
                    TextSpan(
                      text: user.name,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              /// User Role
              if (user.roleLabel != null)
                Text(
                  user.roleLabel!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),

              const SizedBox(height: 24),

              /// Ambulance Information Card
              FutureBuilder<Ambulance?>(
                future: _ambulanceFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingCard();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorCard(snapshot.error.toString());
                  }

                  final ambulance = snapshot.data;

                  if (ambulance == null) {
                    return _buildNoAmbulanceCard();
                  }

                  return _buildAmbulanceCard(ambulance);
                },
              ),

              const SizedBox(height: 24),

              /// Quick Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.assignment,
                      label: 'Missions',
                      value: '0',
                    ),
                  ),
                  const SizedBox(width: 12),
                  FutureBuilder<Ambulance?>(
                    future: _ambulanceFuture,
                    builder: (context, snapshot) {
                      final distance = snapshot.data?.kilometrage ?? 0;
                      return Expanded(
                        child: _buildStatCard(
                          icon: Icons.location_on,
                          label: 'Distance',
                          value: '${distance.toStringAsFixed(0)} km',
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Missions feature coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View Missions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('GPS tracking coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text('Start GPS Tracking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build ambulance information card
  Widget _buildAmbulanceCard(Ambulance ambulance) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.primary.withOpacity(0.02),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Ambulance',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      Text(
                        ambulance.ambulanceNumber,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),

            /// Ambulance Details Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailColumn(
                  icon: Icons.phone,
                  label: 'Telephone',
                  value: ambulance.telephone ?? 'N/A',
                ),
                _buildDetailColumn(
                  icon: Icons.speed,
                  label: 'Kilometrage',
                  value:
                      '${(ambulance.kilometrage ?? 0).toStringAsFixed(0)} km',
                ),
                _buildDetailColumn(
                  icon: Icons.location_on,
                  label: 'Destination',
                  value: ambulance.currentDestination ?? 'None',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading card
  Widget _buildLoadingCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ambulance data...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build error card
  Widget _buildErrorCard(String error) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.error.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error loading ambulance',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.replaceFirst('Exception: ', ''),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error.withOpacity(0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build no ambulance assigned card
  Widget _buildNoAmbulanceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.warning.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No Ambulance Assigned',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have an ambulance assigned yet. Contact your administrator.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build detail column (for ambulance info grid)
  Widget _buildDetailColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build stat card
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
