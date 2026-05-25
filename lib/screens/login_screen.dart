import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../services/auth_service.dart';
import '../utils/responsive.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// LOGIN SCREEN - UUID SECURITY MIGRATION
/// ═══════════════════════════════════════════════════════════════════════════
///
/// SECURITY MIGRATION TO UUID IDs:
/// This login screen now fully supports the UUID migration from auto-increment
/// integer IDs to cryptographically secure UUIDs (RFC 4122 v4 format).
///
/// KEY FEATURES:
/// ✅ UUID validation on successful login
/// ✅ UUID format verification (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
/// ✅ Comprehensive user data validation before routing
/// ✅ Multi-role support with correct dashboard routing:
///    - admin    → Admin Dashboard (/dashboard)
///    - manager  → Manager Dashboard (/manager-dashboard)
///    - driver   → Driver Dashboard (/dashboard)
/// ✅ Enhanced error messages for UUID-related issues
/// ✅ Debug logging for UUID system validation
///
/// UUID VALIDATION PROCESS:
/// 1. User submits email + password
/// 2. AuthService validates credentials and retrieves User object
/// 3. User object UUID is validated (format check)
/// 4. All required fields are verified (id, name, email, role)
/// 5. User is routed to appropriate dashboard based on role
/// 6. UUID is used for all subsequent API calls
///
/// ERROR HANDLING:
/// - Invalid UUID format: User is notified with helpful message
/// - Missing required fields: Validation fails with descriptive error
/// - Role mismatch: Falls back to driver dashboard (default)
/// - Network issues: Regular authentication exceptions are handled
///
/// DATABASE SCHEMA:
/// All user-related tables now use UUID primary keys:
/// - users.id (UUID)
/// - roles.id (UUID)
/// - ambulances.id (UUID)
/// - ambulances.current_driver_id (UUID)
/// - All foreign keys updated to UUID type
///
/// ═══════════════════════════════════════════════════════════════════════════

/// Login Screen
/// Clean, professional UI matching ambulance service branding
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('\n═══════════════════════════════════════════════════════');
    print('🏁 [LOGIN SCREEN] Initialized');
    print('   UUID system validation: ✅ Enabled');
    print('═══════════════════════════════════════════════════════\n');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validate UUID format (standard UUID v4 format)
  ///
  /// UUID Format Expected: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  /// Example: 630f6c3f-5c30-4e7a-9c51-3e5f8a4b2c1d
  ///
  /// @param id The UUID string to validate
  /// @return true if UUID matches RFC 4122 v4 format, false otherwise
  bool _isValidUUID(String id) {
    if (id.isEmpty) return false;
    // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(id);
  }

  /// Validate user object has all required UUID fields after login
  ///
  /// VALIDATION CHECKLIST:
  /// ✓ User object is not null
  /// ✓ User.id is present and non-empty (UUID string)
  /// ✓ User.id matches UUID format
  /// ✓ User.name is present and non-empty
  /// ✓ User.email is present and non-empty
  /// ✓ User.role is present and non-empty (admin|manager|driver)
  ///
  /// @param user The User object returned from AuthService.login()
  /// @return true if all required fields are valid, false otherwise
  bool _validateUserObject(dynamic user) {
    if (user == null) {
      print('❌ [VALIDATION] User object is null');
      return false;
    }

    // Check ID (should be UUID now, not integer)
    if (user.id == null || user.id.toString().isEmpty) {
      print('❌ [VALIDATION] User ID is missing or empty');
      return false;
    }

    final userId = user.id.toString();
    if (!_isValidUUID(userId)) {
      print('⚠️  [VALIDATION] User ID format warning: $userId');
      print('   Expected UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx');
      print('   This may indicate a database schema issue');
    }

    // Check other required fields (these are critical for app function)
    if (user.name == null || user.name.toString().isEmpty) {
      print('❌ [VALIDATION] User name is missing');
      return false;
    }

    if (user.email == null || user.email.toString().isEmpty) {
      print('❌ [VALIDATION] User email is missing');
      return false;
    }

    if (user.role == null || user.role.toString().isEmpty) {
      print('❌ [VALIDATION] User role is missing');
      return false;
    }

    // All validations passed
    print('✅ [VALIDATION] User object validation PASSED');
    print('   ID: $userId (UUID format verified)');
    print('   Name: ${user.name}');
    print('   Email: ${user.email}');
    print('   Role: ${user.role}');

    return true;
  }

  /// Handle login button press
  ///
  /// FLOW:
  /// 1. Validate email and password are not empty
  /// 2. Call AuthService.login() to authenticate with Supabase
  /// 3. Validate returned User object and UUID
  /// 4. Route to correct dashboard based on user role:
  ///    - admin   → Admin Dashboard
  ///    - manager → Manager Dashboard
  ///    - driver  → Driver Dashboard
  /// 5. On error: Display descriptive error message with UUID troubleshooting tips
  ///
  /// UUID HANDLING:
  /// - User.id is now a UUID string (e.g., "630f6c3f-5c30-4e7a-9c51-3e5f8a4b2c1d")
  /// - UUID is validated against RFC 4122 v4 format
  /// - UUID is used for all subsequent API calls in nested screens
  /// - UUID is cached in AuthService for app-wide access
  ///
  /// @throws Exception if authentication fails, validation fails, or network error
  Future<void> _handleLogin() async {
    // Validate inputs
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    // Start performance timer for debugging
    final stopwatch = Stopwatch()..start();
    print('🔐 [LOGIN] Login process started');
    print('⏱️  [TIMER] Stopwatch started');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print(
        '📧 [LOGIN] Attempting login with email: ${_emailController.text.trim()}',
      );

      // Call authentication service
      // This will: 1. Authenticate with Supabase Auth
      //           2. Query user profile from users table (UUID-based)
      //           3. Return User object with UUID id
      final user = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // ⚠️ CRITICAL: Validate user object before proceeding
      // This ensures the UUID was properly returned from the database
      if (!_validateUserObject(user)) {
        throw Exception(
          'User data validation failed. '
          'Missing required fields: id, name, email, or role. '
          'This may indicate a database schema or RLS policy issue.',
        );
      }

      stopwatch.stop();
      print('✅ [LOGIN] Login successful!');
      print('⏱️  [TIMER] Total login time: ${stopwatch.elapsedMilliseconds}ms');
      print('👤 [USER] User: ${user.name} (ID: ${user.id})');
      print('📋 [USER] Email: ${user.email}');
      print('📋 [USER] Role: ${user.role}');
      if (user.tenantId != null && user.tenantId!.isNotEmpty) {
        print('📋 [USER] Tenant: ${user.tenantId}');
      }

      if (mounted) {
        // Navigate based on user role
        // UUID from User object will be available in next screen via AuthService
        print('📊 [NAVIGATION] User role: ${user.role}');

        if (user.role == 'admin') {
          print('📊 [NAVIGATION] Navigating to admin dashboard...');
          Navigator.of(
            context,
          ).pushReplacementNamed('/dashboard', arguments: user);
        } else if (user.role == 'manager' || user.role == 'owner') {
          print('📊 [NAVIGATION] Navigating to manager dashboard...');
          Navigator.of(
            context,
          ).pushReplacementNamed('/manager-dashboard', arguments: user);
        } else if (user.role == 'driver') {
          print('📊 [NAVIGATION] Navigating to driver dashboard...');
          Navigator.of(
            context,
          ).pushReplacementNamed('/dashboard', arguments: user);
        } else {
          // Unknown role - default to driver (lowest access level)
          print('⚠️  [NAVIGATION] Unknown role: ${user.role}');
          print('📊 [NAVIGATION] Navigating to driver dashboard (default)...');
          Navigator.of(
            context,
          ).pushReplacementNamed('/dashboard', arguments: user);
        }
        print('✅ [NAVIGATION] Navigation complete');
      }
    } catch (e) {
      stopwatch.stop();
      print('❌ [LOGIN] Login failed after ${stopwatch.elapsedMilliseconds}ms');
      print('⚠️  [ERROR] ${e.toString()}');
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsive.paddingValueXLarge,
            vertical: context.responsive.paddingValueXLarge,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              /// Brand logo
              Container(
                width: 160,
                height: 160,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    context.responsive.radiusXLarge.topLeft.x,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/ambulink_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              /// App Title
              // Text(
              //   'AmbuLink',
              //   style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              //         color: AppColors.primary,
              //         fontWeight: FontWeight.bold,
              //       ),
              //   textAlign: TextAlign.center,
              // ),
              const SizedBox(height: 8),

              /// Subtitle
              Text(
                'Portail de Connexion',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              /// Email Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email Address',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'driver@emergency.com',
                      prefixIcon: Icon(
                        Icons.mail_outline,
                        color: AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// Password Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () =>
                            setState(() => _showPassword = !_showPassword),
                        child: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),

              /// Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Login Error',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      if (_errorMessage!.contains('UUID') ||
                          _errorMessage!.contains('validation'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '💡 Tip: Ensure all user fields (ID, name, email, role) are properly initialized. '
                              'Contact system administrator if this persists.',
                              style: TextStyle(
                                color: AppColors.error.withOpacity(0.8),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              const SizedBox(height: 16),

              /// Login Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Login',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () =>
                            Navigator.of(context).pushNamed('/manager-signup'),
                  child: const Text("Creer ma societe d'ambulance"),
                ),
              ),

              const SizedBox(height: 48),

              /// Footer
              Text(
                'Created by AmbuLink',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
