import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../config/constants.dart';

/// Admin Users Management Screen
class AdminUsersScreen extends StatefulWidget {
  final User user;

  const AdminUsersScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _adminService = AdminService();
  late Future<List<Map<String, dynamic>>> _usersFuture;
  String _filterRole = 'all'; // all, admin, owner, manager, driver

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = _adminService.getAllUsers();
    });
  }

  void _showCreateDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'driver';
    String? selectedTenantId;
    bool _obscurePassword = true;
    late Future<List<Map<String, dynamic>>> tenantsFuture;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Load tenants on first build
          tenantsFuture = _adminService.getAllTenants();

          return AlertDialog(
            title: const Text('Create Tenant User'),
            content: SingleChildScrollView(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: tenantsFuture,
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> tenants = snapshot.data ?? [];

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          hintText: 'Leave empty to generate random',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setDialogState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                              ),
                              if (passwordController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: passwordController.text,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password copied to clipboard',
                                        ),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tenant Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedTenantId,
                        decoration: const InputDecoration(
                          labelText: 'Selected Tenant',
                          border: OutlineInputBorder(),
                          hintText: 'Select the tenant for this user',
                        ),
                        isExpanded: true,
                        items: tenants
                            .map(
                              (tenant) => DropdownMenuItem<String>(
                                value: tenant['id'],
                                child: Text(tenant['name'] ?? 'Unknown'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedTenantId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      // Role Dropdown with debug logging
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Account Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'owner',
                            child: Text('Owner'),
                          ),
                          DropdownMenuItem(
                            value: 'manager',
                            child: Text('Manager'),
                          ),
                          DropdownMenuItem(
                            value: 'driver',
                            child: Text('Driver'),
                          ),
                        ],
                        onChanged: (value) {
                          print('[DIALOG] Role dropdown changed: $value');
                          setDialogState(() {
                            selectedRole = value ?? 'driver';
                            print(
                              '[DIALOG] selectedRole updated to: $selectedRole',
                            );
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (emailController.text.isEmpty ||
                      nameController.text.isEmpty ||
                      selectedTenantId == null) {
                    _showErrorDialog(
                      'Missing Information',
                      'Please fill in all required fields:\n• Email\n• Full Name\n• Tenant',
                    );
                    return;
                  }

                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (loadingContext) => AlertDialog(
                      content: Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 16),
                          const Text('Creating user...'),
                        ],
                      ),
                    ),
                  );

                  try {
                    // DEBUG: Log the values at submission time
                    print(
                      '[DIALOG_SUBMIT] Creating user with role: $selectedRole (type: ${selectedRole.runtimeType})',
                    );
                    print('[DIALOG_SUBMIT] Email: ${emailController.text}');
                    print('[DIALOG_SUBMIT] Name: ${nameController.text}');
                    print('[DIALOG_SUBMIT] TenantId: $selectedTenantId');

                    final response = await _adminService.createUser(
                      email: emailController.text,
                      name: nameController.text,
                      tenantId: selectedTenantId!,
                      role: selectedRole,
                      password: passwordController.text.isNotEmpty
                          ? passwordController.text
                          : null,
                    );

                    if (mounted) {
                      Navigator.pop(context); // Close loading dialog
                      Navigator.pop(context); // Close create dialog

                      // Show password dialog
                      final tempPassword =
                          response['temporary_password'] ?? 'N/A';
                      _showPasswordDialog(emailController.text, tempPassword);

                      // Refresh list
                      _refreshUsers();
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // Close loading dialog
                      _parseAndShowError(e.toString());
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> userItem) {
    final nameController = TextEditingController(text: userItem['name']);
    String selectedRole = userItem['role'] ?? 'driver';
    String? selectedTenantId = userItem['tenant_id'];
    bool isActive = userItem['is_active'] ?? true;
    late Future<List<Map<String, dynamic>>> tenantsFuture;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          tenantsFuture = _adminService.getAllTenants();

          return AlertDialog(
            title: const Text('Edit User'),
            content: SingleChildScrollView(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: tenantsFuture,
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> tenants = snapshot.data ?? [];

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Email: ${userItem['email']}'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tenant Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedTenantId,
                        decoration: const InputDecoration(
                          labelText: 'Tenant',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: tenants
                            .map(
                              (tenant) => DropdownMenuItem<String>(
                                value: tenant['id'],
                                child: Text(tenant['name'] ?? 'Unknown'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedTenantId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'owner',
                            child: Text('Owner'),
                          ),
                          DropdownMenuItem(
                            value: 'manager',
                            child: Text('Manager'),
                          ),
                          DropdownMenuItem(
                            value: 'driver',
                            child: Text('Driver'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedRole = value ?? 'driver');
                        },
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (value) {
                          setState(() => isActive = value ?? true);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _adminService.updateUser(
                      userItem['id'].toString(),
                      name: nameController.text,
                      tenantId: selectedTenantId,
                      role: selectedRole,
                      isActive: isActive,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      _refreshUsers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _parseAndShowError(e.toString());
                      _refreshUsers();
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> userItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete "${userItem['name']}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _adminService.deleteUser(userItem['id'].toString());

                if (mounted) {
                  Navigator.pop(context);
                  _refreshUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create User'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshUsers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          var users = snapshot.data ?? [];

          // Apply role filter
          if (_filterRole != 'all') {
            users = users.where((u) => u['role'] == _filterRole).toList();
          }

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No users found'),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter Bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _filterRole == 'all',
                        onSelected: (selected) {
                          setState(() => _filterRole = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Admin'),
                        selected: _filterRole == 'admin',
                        onSelected: (selected) {
                          setState(() => _filterRole = 'admin');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Owner'),
                        selected: _filterRole == 'owner',
                        onSelected: (selected) {
                          setState(() => _filterRole = 'owner');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Manager'),
                        selected: _filterRole == 'manager',
                        onSelected: (selected) {
                          setState(() => _filterRole = 'manager');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Driver'),
                        selected: _filterRole == 'driver',
                        onSelected: (selected) {
                          setState(() => _filterRole = 'driver');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Users List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userItem = users[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(userItem['role']),
                          child: Text(
                            userItem['name']?[0]?.toUpperCase() ?? '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          userItem['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userItem['email'] ?? ''),
                            Text(
                              'Role: ${userItem['role'] ?? '-'} ${userItem['is_active'] ?? true ? '✓' : '✗'}',
                              style: TextStyle(
                                color: userItem['is_active'] ?? true
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Text(
                              'Tenant: ${userItem['tenant_id'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Edit'),
                              onTap: () => Future.delayed(
                                const Duration(milliseconds: 100),
                                () => _showEditDialog(userItem),
                              ),
                            ),
                            PopupMenuItem(
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                              onTap: () => Future.delayed(
                                const Duration(milliseconds: 100),
                                () => _showDeleteConfirmation(userItem),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPasswordDialog(String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'User Created Successfully! 🎉',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Temporary Password',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: SelectableText(
                  password,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.lime,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'User must change password on first login',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: password));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Password copied to clipboard! ✅'),
                  backgroundColor: Colors.green.shade600,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Password'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _parseAndShowError(String errorMessage) {
    String title = 'Error';
    String message = errorMessage;
    String icon = '❌';

    // Parse specific error messages from backend
    if (errorMessage.contains('already been registered')) {
      title = 'Email Already Registered';
      message =
          'This email address is already registered in the system.\n\n💡 Tip: Use a different email or check if the user already exists.';
      icon = '📧';
    } else if (errorMessage.contains('Tenant mismatch')) {
      title = 'Tenant Conflict';
      message =
          'The selected tenant is not available for this operation.\n\n💡 Tip: Please select another tenant.';
      icon = '🏢';
    } else if (errorMessage.contains('Not admin')) {
      title = 'Permission Denied';
      message =
          'You do not have permission to create users.\n\n💡 Tip: Only administrators can create new users.';
      icon = '🔐';
    } else if (errorMessage.contains('Missing fields')) {
      title = 'Incomplete Information';
      message =
          'All required fields must be completed.\n\n💡 Tip: Check all fields are filled in correctly.';
      icon = '📝';
    } else if (errorMessage.contains('Database error')) {
      title = 'Database Error';
      message =
          'An error occurred while saving the user.\n\n💡 Tip: Please try again. If the problem persists, contact support.';
      icon = '🗄️';
    } else if (errorMessage.contains('Auth creation failed')) {
      title = 'Authentication Error';
      message =
          'Failed to create authentication credentials.\n\n💡 Tip: Please try again with a valid email address.';
      icon = '🔑';
    } else {
      // Generic error
      title = 'Creation Failed';
      message = errorMessage.replaceFirst('Error: ', '');
      icon = '❌';
    }

    // Remove "Error: " prefix if present
    if (message.startsWith('Error: ')) {
      message = message.substring(7);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Dismiss'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade100,
              foregroundColor: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'owner':
        return Colors.purple;
      case 'manager':
        return Colors.orange;
      case 'driver':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
