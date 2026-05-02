import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/user_model.dart';
import '../services/manager_onboarding_service.dart';
import 'manager_dashboard_screen.dart';

class ManagerOnboardingShellScreen extends StatefulWidget {
  const ManagerOnboardingShellScreen({super.key, required this.user});

  final User user;

  @override
  State<ManagerOnboardingShellScreen> createState() =>
      _ManagerOnboardingShellScreenState();
}

class _ManagerOnboardingShellScreenState
    extends State<ManagerOnboardingShellScreen> {
  final _onboardingService = ManagerOnboardingService();
  final _ambulanceNumberController = TextEditingController();
  final _ambulancePhoneController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _driverEmailController = TextEditingController();
  final _driverPasswordController = TextEditingController();
  final _driverPhoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _state;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _ambulanceNumberController.dispose();
    _ambulancePhoneController.dispose();
    _driverNameController.dispose();
    _driverEmailController.dispose();
    _driverPasswordController.dispose();
    _driverPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final state = await _onboardingService.getOnboardingState();
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addAmbulance() async {
    if (_ambulanceNumberController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Numero ambulance requis.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _onboardingService.addAmbulance(
        ambulanceNumber: _ambulanceNumberController.text.trim(),
        telephone: _ambulancePhoneController.text.trim().isEmpty
            ? null
            : _ambulancePhoneController.text.trim(),
      );
      _ambulanceNumberController.clear();
      _ambulancePhoneController.clear();
      await _loadState();
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addDriver() async {
    if (_driverNameController.text.trim().isEmpty ||
        _driverEmailController.text.trim().isEmpty ||
        _driverPasswordController.text.length < 8) {
      setState(() {
        _errorMessage =
            'Nom, email, et mot de passe chauffeur sont requis.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _onboardingService.addDriver(
        driverName: _driverNameController.text.trim(),
        driverEmail: _driverEmailController.text.trim(),
        driverPassword: _driverPasswordController.text,
        driverPhone: _driverPhoneController.text.trim().isEmpty
            ? null
            : _driverPhoneController.text.trim(),
      );
      _driverNameController.clear();
      _driverEmailController.clear();
      _driverPasswordController.clear();
      _driverPhoneController.clear();
      await _loadState();
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _onboardingService.finishOnboarding();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ManagerDashboardScreen(user: widget.user),
        ),
      );
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildAddAmbulanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajoutez votre premiere ambulance',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _ambulanceNumberController,
              decoration: const InputDecoration(
                labelText: 'Numero ambulance',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ambulancePhoneController,
              decoration: const InputDecoration(
                labelText: 'Telephone ambulance (optionnel)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addAmbulance,
                child: const Text('Ajouter ambulance'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddDriverCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajoutez votre premier chauffeur',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _driverNameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _driverEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _driverPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _driverPhoneController,
              decoration: const InputDecoration(
                labelText: 'Telephone (optionnel)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addDriver,
                child: const Text('Ajouter chauffeur'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final counts = Map<String, dynamic>.from(
      _state?['counts'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
    final onboarding = Map<String, dynamic>.from(
      _state?['onboarding'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
    );
    final ambulanceCount = (counts['ambulanceCount'] as num?)?.toInt() ??
        (counts['ambulance_count'] as num?)?.toInt() ??
        0;
    final driverCount = (counts['driverCount'] as num?)?.toInt() ??
        (counts['driver_count'] as num?)?.toInt() ??
        0;
    final isComplete = onboarding['is_complete'] == true;

    if (isComplete) {
      return ManagerDashboardScreen(user: widget.user);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration initiale'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadState,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finalisez votre espace manager',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ambulances: $ambulanceCount | Chauffeurs: $driverCount',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildAddAmbulanceCard(),
              const SizedBox(height: 12),
              if (ambulanceCount > 0) _buildAddDriverCard(),
              const SizedBox(height: 12),
              if (ambulanceCount > 0 && driverCount > 0)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _finishOnboarding,
                    child: const Text('Terminer la configuration'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
