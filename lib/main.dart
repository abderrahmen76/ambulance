import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/constants.dart';
import 'config/environment.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/fcm_token_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/manager_entry_screen.dart';
import 'screens/manager_signup_screen.dart';
import 'screens/admin_dashboard_screen.dart';

void _ensureHttpsUrl(String value, {bool allowDevelopmentHttp = false}) {
  final trimmed = value.trim();
  if (trimmed.startsWith('https://')) {
    return;
  }

  if (allowDevelopmentHttp &&
      (trimmed.startsWith('http://127.0.0.1') ||
          trimmed.startsWith('http://localhost') ||
          trimmed.startsWith('http://192.168.') ||
          trimmed.startsWith('http://10.'))) {
    return;
  }

  throw StateError('Insecure URL is not allowed: $trimmed');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _ensureHttpsUrl(SupabaseConfig.supabaseUrl);
  _ensureHttpsUrl(
    EnvironmentConfig.notificationBackendUrl,
    allowDevelopmentHttp: EnvironmentConfig.currentEnvironment ==
        Environment.development,
  );

  // Initialize Supabase (must be done before any auth operations)
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.anonKey,
    );
    debugPrint('✅ [MAIN] Supabase initialized');
  } catch (e) {
    debugPrint('❌ [MAIN] Error initializing Supabase: $e');
    // Continue anyway - app can still function
  }

  // Initialize Firebase (mobile only - web doesn't need it for this app)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();

      // Initialize Firebase Messaging and Local Notifications
      await NotificationService.instance.initialize();

      // Pre-download notification sound in background (doesn't block app startup)
      NotificationService.instance.preloadNotificationSounds().catchError((e) {
        debugPrint(
            '[MAIN] ⚠️ Warning: Sound preload failed (will use built-in): $e');
      });

      // Get and log FCM token for testing
      String? fcmToken = await NotificationService.instance.getFcmToken();
      if (fcmToken != null) {
        debugPrint('🔔 FCM Token: $fcmToken');
      }

      // Set up FCM token refresh listener
      try {
        FCMTokenService().listenForTokenRefresh();
      } catch (e) {
        debugPrint('⚠️  [MAIN] Error setting up FCM token listener: $e');
      }
    } catch (e) {
      debugPrint('⚠️  [MAIN] Error initializing Firebase: $e');
      // Continue anyway - Firebase errors shouldn't prevent app from loading
    }
  }

  // Restore user session from persistent storage if it exists
  await AuthService().restoreSessionOnStartup();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String _initialRoute;

  @override
  void initState() {
    super.initState();
    // Determine initial route based on whether user is logged in
    final authService = AuthService();
    _initialRoute = authService.isLoggedIn ? '/dashboard' : '/login';
    print('🔄 [INIT] Initial route set to: $_initialRoute');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: _buildTheme(),
      initialRoute: _initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/dashboard': (context) {
          final authService = AuthService();
          final user = authService.cachedUser;
          if (user != null) {
            print('[DEBUG] Route /dashboard: User role = ${user.role}');
            // Route to the correct dashboard based on user role
            if (user.role == 'admin') {
              print('[DEBUG] Returning AdminDashboardScreen for admin user');
              return AdminDashboardScreen(user: user);
            } else if (user.role == 'manager') {
              print('[DEBUG] Returning ManagerEntryScreen for manager user');
              return ManagerEntryScreen(user: user);
            } else {
              print('[DEBUG] Returning DashboardScreen for driver user');
              return DashboardScreen(user: user);
            }
          }
          // Fallback if no user (shouldn't happen)
          return const LoginScreen();
        },
        '/manager-dashboard': (context) {
          final authService = AuthService();
          final user = authService.cachedUser;
          if (user != null) {
            return ManagerEntryScreen(user: user);
          }
          // Fallback if no user (shouldn't happen)
          return const LoginScreen();
        },
        '/manager-signup': (context) => const ManagerSignupScreen(),
      },
    );
  }

  /// Build custom theme with red color scheme
  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: AppColors.surface,
      ),

      // Typography
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
