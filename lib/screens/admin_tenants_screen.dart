import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../config/constants.dart';
import '../utils/responsive.dart';

/// Admin Tenants Management Screen
class AdminTenantsScreen extends StatefulWidget {
  final User user;

  const AdminTenantsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<AdminTenantsScreen> createState() => _AdminTenantsScreenState();
}

class _AdminTenantsScreenState extends State<AdminTenantsScreen> {
  final _adminService = AdminService();
  late Future<List<Map<String, dynamic>>> _tenantsFuture;

  @override
  void initState() {
    super.initState();
    _refreshTenants();
  }

  void _refreshTenants() {
    setState(() {
      _tenantsFuture = _adminService.getAllTenants();
    });
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Tenant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tenant Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: slugController,
                decoration: const InputDecoration(
                  labelText: 'Slug (URL-friendly)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || slugController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name and Slug are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await _adminService.createTenant(
                  name: nameController.text,
                  slug: slugController.text,
                  description: descController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _refreshTenants();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tenant created successfully'),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> tenant) {
    final nameController = TextEditingController(text: tenant['name']);
    final descController =
        TextEditingController(text: tenant['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tenant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tenant Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
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
                await _adminService.updateTenant(
                  tenant['id'],
                  name: nameController.text,
                  description: descController.text,
                );

                if (mounted) {
                  Navigator.pop(context);
                  _refreshTenants();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tenant updated successfully'),
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
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: Text(
          'Are you sure you want to delete "${tenant['name']}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              try {
                await _adminService.deleteTenant(tenant['id']);

                if (mounted) {
                  Navigator.pop(context);
                  _refreshTenants();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tenant deleted successfully'),
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
        label: const Text('Create Tenant'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _tenantsFuture,
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
                    onPressed: _refreshTenants,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final tenants = snapshot.data ?? [];

          if (tenants.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No tenants found'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tenants.length,
            itemBuilder: (context, index) {
              final tenant = tenants[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    tenant['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Slug: ${tenant['slug'] ?? '-'}'),
                      Text(
                        'Status: ${tenant['subscription_status'] ?? '-'}',
                        style: TextStyle(
                          color: tenant['subscription_status'] == 'active'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      Text(
                        'Tier: ${tenant['subscription_tier'] ?? '-'}',
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Edit'),
                        onTap: () => Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _showEditDialog(tenant),
                        ),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () => Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _showDeleteConfirmation(tenant),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
