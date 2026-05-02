import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../services/auth_service.dart';
import '../services/manager_onboarding_service.dart';

class ManagerSignupScreen extends StatefulWidget {
  const ManagerSignupScreen({super.key});

  @override
  State<ManagerSignupScreen> createState() => _ManagerSignupScreenState();
}

class _ManagerSignupScreenState extends State<ManagerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyCityController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _managerPasswordController = TextEditingController();

  final _authService = AuthService();
  final _onboardingService = ManagerOnboardingService();

  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyCityController.dispose();
    _companyAddressController.dispose();
    _managerNameController.dispose();
    _managerEmailController.dispose();
    _managerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _onboardingService.startSignup(
        companyName: _companyNameController.text.trim(),
        companyPhone: _companyPhoneController.text.trim(),
        companyCity: _companyCityController.text.trim(),
        companyAddress: _companyAddressController.text.trim().isEmpty
            ? null
            : _companyAddressController.text.trim(),
        managerName: _managerNameController.text.trim(),
        managerEmail: _managerEmailController.text.trim(),
        managerPassword: _managerPasswordController.text,
      );

      await _authService.login(
        email: _managerEmailController.text.trim(),
        password: _managerPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed('/manager-dashboard');
    } catch (error) {
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

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Creer ma societe"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commencez avec le minimum utile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "Creez votre societe, votre compte manager, puis ajoutez vos ambulances et chauffeurs.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _companyNameController,
                  decoration: _decoration('Nom de la societe', Icons.business),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyPhoneController,
                  decoration: _decoration('Telephone societe', Icons.phone),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyCityController,
                  decoration: _decoration('Ville', Icons.location_city),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyAddressController,
                  decoration: _decoration('Adresse (optionnel)', Icons.place),
                ),
                const SizedBox(height: 24),
                Text(
                  'Compte manager',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _managerNameController,
                  decoration: _decoration('Nom complet', Icons.person),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _managerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration('Email', Icons.mail_outline),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Champ requis'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _managerPasswordController,
                  obscureText: !_showPassword,
                  decoration: _decoration(
                    'Mot de passe',
                    Icons.lock_outline,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (value) => (value == null || value.length < 8)
                      ? '8 caracteres minimum'
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Creer et continuer'),
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
