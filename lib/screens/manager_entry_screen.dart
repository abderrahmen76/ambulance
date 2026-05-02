import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/manager_onboarding_service.dart';
import 'manager_dashboard_screen.dart';
import 'manager_onboarding_shell_screen.dart';

class ManagerEntryScreen extends StatefulWidget {
  const ManagerEntryScreen({super.key, required this.user});

  final User user;

  @override
  State<ManagerEntryScreen> createState() => _ManagerEntryScreenState();
}

class _ManagerEntryScreenState extends State<ManagerEntryScreen> {
  final _onboardingService = ManagerOnboardingService();
  bool _isLoading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _resolveEntry();
  }

  Future<void> _resolveEntry() async {
    try {
      final state = await _onboardingService.getOnboardingState();
      final onboarding = Map<String, dynamic>.from(
        state['onboarding'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      );
      final isComplete = onboarding['is_complete'] == true;
      if (!mounted) {
        return;
      }
      setState(() {
        _showOnboarding = !isComplete;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showOnboarding = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return ManagerOnboardingShellScreen(user: widget.user);
    }

    return ManagerDashboardScreen(user: widget.user);
  }
}
