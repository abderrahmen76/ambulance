import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../config/constants.dart';

/// Admin Ambulances Management Screen
class AdminAmbulancesScreen extends StatefulWidget {
  final User user;

  const AdminAmbulancesScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<AdminAmbulancesScreen> createState() => _AdminAmbulancesScreenState();
}

class _AdminAmbulancesScreenState extends State<AdminAmbulancesScreen> {
  final _adminService = AdminService();
  late Future<List<Map<String, dynamic>>> _ambulancesFuture;

  @override
  void initState() {
    super.initState();
    _refreshAmbulances();
  }

  void _refreshAmbulances() {
    setState(() {
      _ambulancesFuture = _adminService.getAllAmbulances();
    });
  }

  void _showCreateDialog() {
    final numberController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedTenantId;
    late Future<List<Map<String, dynamic>>> tenantsFuture;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Load tenants on first build
          tenantsFuture = _adminService.getAllTenants();

          return AlertDialog(
            title: const Text('Create New Ambulance'),
            content: SingleChildScrollView(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: tenantsFuture,
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> tenants = snapshot.data ?? [];

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tenant Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedTenantId,
                        decoration: const InputDecoration(
                          labelText: 'Tenant',
                          border: OutlineInputBorder(),
                          hintText: 'Select a tenant',
                        ),
                        isExpanded: true,
                        items: tenants
                            .map((tenant) => DropdownMenuItem<String>(
                                  value: tenant['id'],
                                  child: Text(tenant['name'] ?? 'Unknown'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedTenantId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: numberController,
                        decoration: const InputDecoration(
                          labelText: 'Ambulance Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
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
                  if (numberController.text.isEmpty ||
                      selectedTenantId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Ambulance Number and Tenant are required'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    await _adminService.createAmbulance(
                      ambulanceNumber: numberController.text,
                      tenantId: selectedTenantId!,
                      telephone: phoneController.text,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      _refreshAmbulances();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ambulance created successfully'),
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
          );
        },
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> ambulance) {
    final numberController =
        TextEditingController(text: ambulance['ambulance_number']);
    final phoneController =
        TextEditingController(text: ambulance['telephone'] ?? '');
    final kmController = TextEditingController(
      text: ambulance['kilometrage']?.toString() ?? '0',
    );
    String? selectedTenantId = ambulance['tenant_id'];
    late Future<List<Map<String, dynamic>>> tenantsFuture;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          tenantsFuture = _adminService.getAllTenants();

          return AlertDialog(
            title: const Text('Edit Ambulance'),
            content: SingleChildScrollView(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: tenantsFuture,
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> tenants = snapshot.data ?? [];

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tenant Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedTenantId,
                        decoration: const InputDecoration(
                          labelText: 'Tenant',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: tenants
                            .map((tenant) => DropdownMenuItem<String>(
                                  value: tenant['id'],
                                  child: Text(tenant['name'] ?? 'Unknown'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedTenantId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: numberController,
                        decoration: const InputDecoration(
                          labelText: 'Ambulance Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: kmController,
                        decoration: const InputDecoration(
                          labelText: 'Kilometrage',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
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
                    await _adminService.updateAmbulance(
                      ambulance['id'].toString(),
                      ambulanceNumber: numberController.text,
                      telephone: phoneController.text,
                      tenantId: selectedTenantId,
                      kilometrage: double.tryParse(kmController.text) ?? 0.0,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      _refreshAmbulances();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ambulance updated successfully'),
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
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> ambulance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Ambulance'),
        content: Text(
          'Are you sure you want to delete "${ambulance['ambulance_number']}"?\nThis action cannot be undone.',
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
                await _adminService.deleteAmbulance(
                  ambulance['id'].toString(),
                );

                if (mounted) {
                  Navigator.pop(context);
                  _refreshAmbulances();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ambulance deleted successfully'),
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
        label: const Text('Create Ambulance'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ambulancesFuture,
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
                    onPressed: _refreshAmbulances,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final ambulances = snapshot.data ?? [];

          if (ambulances.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_taxi, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No ambulances found'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ambulances.length,
            itemBuilder: (context, index) {
              final ambulance = ambulances[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.local_taxi, color: Colors.white),
                  ),
                  title: Text(
                    ambulance['ambulance_number'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Phone: ${ambulance['telephone'] ?? '-'}'),
                      Text(
                        'KM: ${ambulance['kilometrage']?.toStringAsFixed(1) ?? '0'} km',
                      ),
                      Text(
                        'Tenant: ${ambulance['tenant_id'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Edit'),
                        onTap: () => Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _showEditDialog(ambulance),
                        ),
                      ),
                      PopupMenuItem(
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () => Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _showDeleteConfirmation(ambulance),
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
