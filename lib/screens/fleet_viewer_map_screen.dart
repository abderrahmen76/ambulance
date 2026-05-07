/**
 * Fleet Viewer Map Screen - Real-Time Fleet Tracking Display
 * Shows all drivers on an interactive map with live updates via Socket.IO
 * 
 * Features:
 * - Live map display of all drivers
 * - Real-time marker updates
 * - Driver details and status
 * - Offline/online indicators
 * - Connection status monitoring
 */

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../../models/user_model.dart';
import '../../models/ambulance_model.dart';
import '../../services/api_client.dart';
import '../../services/fleet_tracking/fleet_viewer_service.dart';
import '../../services/fleet_tracking/fleet_tracking_models.dart';
import '../../config/constants.dart';

class FleetViewerMapScreen extends StatefulWidget {
  final User user;

  const FleetViewerMapScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<FleetViewerMapScreen> createState() => _FleetViewerMapScreenState();
}

class _FleetViewerMapScreenState extends State<FleetViewerMapScreen> {
  FleetViewerService? _viewerService;
  late MapController _mapController;
  final ApiClient _apiClient = ApiClient();

  bool _isConnected = false;
  bool _isFullscreen = false;
  bool _hasInitialFit = false; // Prevent repeated map refitting
  List<DriverLocation> _drivers = [];
  final Set<String> _tenantAmbulanceIds = <String>{};
  final Map<String, String> _tenantAmbulanceNumbers = <String, String>{};
  bool _isLoadingTenantFleet = true;
  DriverLocation? _selectedDriver;
  String? _error;
  int _updateCount = 0;
  final Map<String, String> _driverPlaceNames = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeViewer();
  }

  Future<void> _loadTenantFleet() async {
    final tenantId = widget.user.tenantId?.trim();
    if (tenantId == null || tenantId.isEmpty) {
      throw Exception('Tenant manager introuvable pour le suivi temps reel.');
    }

    final rows = await _apiClient.get(
      SupabaseConfig.ambulancesTable,
      filters: {'tenant_id': 'eq.$tenantId'},
    );
    final ambulances = rows
        .map((row) => Ambulance.fromJson(row))
        .where((ambulance) => ambulance.id.isNotEmpty)
        .toList();

    _tenantAmbulanceIds
      ..clear()
      ..addAll(ambulances.map((ambulance) => ambulance.id));
    _tenantAmbulanceNumbers
      ..clear()
      ..addEntries(
        ambulances.map(
          (ambulance) => MapEntry(ambulance.id, ambulance.ambulanceNumber),
        ),
      );
  }

  List<DriverLocation> _filterTenantDrivers(List<DriverLocation> drivers) {
    if (_tenantAmbulanceIds.isEmpty) return <DriverLocation>[];
    return drivers
        .where((driver) => _tenantAmbulanceIds.contains(driver.ambulanceId))
        .toList();
  }

  String _ambulanceDisplayName(String ambulanceId) {
    final number = _tenantAmbulanceNumbers[ambulanceId];
    if (number == null || number.trim().isEmpty) return ambulanceId;
    return number;
  }

  String _placeDisplayName(DriverLocation driver) {
    return _driverPlaceNames[driver.driverId] ?? 'Recherche du lieu...';
  }

  /**
   * Initialize fleet viewer
   */
  Future<void> _initializeViewer() async {
    try {
      await _loadTenantFleet();
      if (mounted) {
        setState(() => _isLoadingTenantFleet = false);
      }

      _viewerService = FleetViewerService(
        backendUrl: 'https://ambulance-backend-1-n6wd.onrender.com',
      );

      // Setup listeners
      _viewerService!.onConnected(() {
        if (mounted) {
          setState(() {
            _isConnected = true;
            _error = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connecté au suivi de flotte'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });

      _viewerService!.onDisconnected(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _hasInitialFit = false; // Reset so map refits on reconnect
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Déconnecté du suivi de flotte'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _viewerService!.onDriversUpdate((drivers) {
        if (mounted) {
          setState(() {
            _drivers = _filterTenantDrivers(drivers);
            if (_selectedDriver != null &&
                !_tenantAmbulanceIds.contains(_selectedDriver!.ambulanceId)) {
              _selectedDriver = null;
            }
            _updateCount++;
          });
          // Only fit map bounds on first load
          if (!_hasInitialFit && _drivers.isNotEmpty) {
            _fitMapToBounds();
            _hasInitialFit = true;
          }
          // Fetch place names for all drivers
          for (var driver in _drivers) {
            _getPlaceName(driver);
          }
        }
      });

      _viewerService!.onLocationUpdate((driver) {
        if (mounted) {
          if (!_tenantAmbulanceIds.contains(driver.ambulanceId)) {
            setState(() {
              _drivers.removeWhere((d) => d.driverId == driver.driverId);
              if (_selectedDriver?.driverId == driver.driverId) {
                _selectedDriver = null;
              }
            });
            return;
          }

          setState(() {
            final index = _drivers.indexWhere(
              (d) => d.driverId == driver.driverId,
            );
            if (index >= 0) {
              _drivers[index] = driver;
            } else {
              _drivers.add(driver);
            }
          });
          // Get place name for the driver
          _getPlaceName(driver);
        }
      });

      _viewerService!.onDriverOffline((driverId) {
        if (mounted) {
          setState(() {
            _drivers.removeWhere((d) => d.driverId == driverId);
            if (_selectedDriver?.driverId == driverId) {
              _selectedDriver = null;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Le conducteur $driverId est hors ligne'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _viewerService!.onError((error) {
        if (mounted) {
          setState(() {
            _error = error;
          });
        }
      });

      // Connect
      await _viewerService!.connect();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoadingTenantFleet = false;
        });
      }
    }
  }

  /**
   * Fit map to all drivers
   * @private
   */
  void _fitMapToBounds() {
    if (_drivers.isEmpty) return;

    double minLat = _drivers[0].latitude;
    double maxLat = _drivers[0].latitude;
    double minLng = _drivers[0].longitude;
    double maxLng = _drivers[0].longitude;

    for (var driver in _drivers) {
      minLat = minLat > driver.latitude ? driver.latitude : minLat;
      maxLat = maxLat < driver.latitude ? driver.latitude : maxLat;
      minLng = minLng > driver.longitude ? driver.longitude : minLng;
      maxLng = maxLng < driver.longitude ? driver.longitude : maxLng;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
    );
  }

  /**
   * Get marker color based on driver status
   * @private
   */
  Color _getMarkerColor(DriverLocation driver) {
    // Could add more logic here (speed, status, etc.)
    return AppColors.primary;
  }

  Future<String?> _reverseGeocodeWithOsm(DriverLocation driver) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': driver.latitude.toString(),
        'lon': driver.longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'AmbuGestion/1.0 realtime fleet viewer',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = payload['display_name']?.toString().trim();
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /**
   * Get place name from coordinates using reverse geocoding
   */
  Future<void> _getPlaceName(DriverLocation driver) async {
    if (_driverPlaceNames.containsKey(driver.driverId)) {
      return; // Already cached
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        driver.latitude,
        driver.longitude,
      );

      String? placeName;
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((p) => p != null && p.trim().isNotEmpty).cast<String>();
        placeName = parts.join(', ');
      }
      if (placeName == null || placeName.trim().isEmpty) {
        placeName = await _reverseGeocodeWithOsm(driver);
      }

      if (mounted) {
        setState(() {
          _driverPlaceNames[driver.driverId] =
              placeName?.trim().isNotEmpty == true
              ? placeName!.trim()
              : 'Lieu indisponible';
        });
      }
    } catch (error) {
      final placeName = await _reverseGeocodeWithOsm(driver);
      if (mounted) {
        setState(() {
          _driverPlaceNames[driver.driverId] =
              placeName?.trim().isNotEmpty == true
              ? placeName!.trim()
              : 'Lieu indisponible';
        });
      }
    }
  }

  @override
  void dispose() {
    _viewerService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTenantFleet) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: LatLng(36.8065, 10.1875), // Tunisia center as default
            zoom: 12,
            minZoom: 3,
            maxZoom: 18,
          ),
          children: [
            // OpenStreetMap tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ambulance_tracking_app',
              subdomains: const ['a', 'b', 'c'],
            ),

            // Markers for drivers
            MarkerLayer(
              markers: _drivers.map((driver) {
                return Marker(
                  point: LatLng(driver.latitude, driver.longitude),
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDriver =
                            _selectedDriver?.driverId == driver.driverId
                            ? null
                            : driver;
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _selectedDriver?.driverId == driver.driverId
                                ? Colors.blueAccent
                                : _getMarkerColor(driver),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.directions_car,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Top bar with status
        if (!_isFullscreen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suivi en temps réel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_drivers.length} ambulances en ligne',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isConnected ? 'Connecté' : 'Connexion',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Fullscreen button (top-right, below status bar)
        if (!_isFullscreen)
          Positioned(
            top: 100,
            right: 12,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              elevation: 4,
              child: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  _isFullscreen = !_isFullscreen;
                });
              },
            ),
          ),

        // Fullscreen exit button (bottom-right, visible only in fullscreen)
        if (_isFullscreen)
          Positioned(
            bottom: 20,
            right: 12,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.fullscreen_exit, color: Colors.black),
              onPressed: () {
                setState(() {
                  _isFullscreen = !_isFullscreen;
                });
              },
            ),
          ),

        // Error display
        if (_error != null)
          Positioned(
            top: 100,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Driver list (bottom sheet)
        if (!_isFullscreen)
          Positioned(bottom: 0, left: 0, right: 0, child: _buildDriverList()),
      ],
    );
  }

  /**
   * Build driver list at bottom
   * @private
   */
  Widget _buildDriverList() {
    return SingleChildScrollView(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Selected driver details
            if (_selectedDriver != null) ...[
              _buildSelectedDriverDetails(),
              const Divider(),
            ],

            // Live drivers list
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ambulances actives',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_drivers.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_drivers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Aucune ambulance active pour votre société',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _drivers.length,
                        itemBuilder: (context, index) {
                          final driver = _drivers[index];
                          final isSelected =
                              _selectedDriver?.driverId == driver.driverId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : null,
                            child: ListTile(
                              leading: Icon(
                                Icons.directions_car,
                                color: AppColors.primary,
                              ),
                              title: Text(driver.driverName),
                              subtitle: Text(
                                'Ambulance : ${_ambulanceDisplayName(driver.ambulanceId)}\n'
                                'Lieu : ${_placeDisplayName(driver)}',
                                style: const TextStyle(fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedDriver = isSelected ? null : driver;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /**
   * Build selected driver details
   * @private
   */
  Widget _buildSelectedDriverDetails() {
    final driver = _selectedDriver!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  driver.driverName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'En ligne',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ambulance : ${_ambulanceDisplayName(driver.ambulanceId)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              'Lieu : ${_placeDisplayName(driver)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Mis à jour : ${driver.timestamp.toString().split('.')[0]}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
