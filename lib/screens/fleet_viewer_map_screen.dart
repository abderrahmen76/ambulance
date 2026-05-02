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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/user_model.dart';
import '../../services/fleet_tracking/fleet_viewer_service.dart';
import '../../services/fleet_tracking/fleet_tracking_models.dart';
import '../../config/constants.dart';

class FleetViewerMapScreen extends StatefulWidget {
  final User user;

  const FleetViewerMapScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<FleetViewerMapScreen> createState() => _FleetViewerMapScreenState();
}

class _FleetViewerMapScreenState extends State<FleetViewerMapScreen> {
  late FleetViewerService _viewerService;
  late MapController _mapController;

  bool _isConnected = false;
  bool _isFullscreen = false;
  bool _hasInitialFit = false; // Prevent repeated map refitting
  List<DriverLocation> _drivers = [];
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

  /**
   * Initialize fleet viewer
   */
  Future<void> _initializeViewer() async {
    try {
      _viewerService = FleetViewerService(
        backendUrl: 'https://ambulance-backend-1-n6wd.onrender.com',
      );

      // Setup listeners
      _viewerService.onConnected(() {
        if (mounted) {
          setState(() {
            _isConnected = true;
            _error = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Connected to fleet tracking'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });

      _viewerService.onDisconnected(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _hasInitialFit = false; // Reset so map refits on reconnect
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Disconnected from fleet tracking'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _viewerService.onDriversUpdate((drivers) {
        if (mounted) {
          setState(() {
            _drivers = drivers;
            _updateCount++;
          });
          // Only fit map bounds on first load
          if (!_hasInitialFit && _drivers.isNotEmpty) {
            _fitMapToBounds();
            _hasInitialFit = true;
          }
          // Fetch place names for all drivers
          for (var driver in drivers) {
            _getPlaceName(driver);
          }
        }
      });

      _viewerService.onLocationUpdate((driver) {
        if (mounted) {
          setState(() {
            final index =
                _drivers.indexWhere((d) => d.driverId == driver.driverId);
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

      _viewerService.onDriverOffline((driverId) {
        if (mounted) {
          setState(() {
            _drivers.removeWhere((d) => d.driverId == driverId);
            if (_selectedDriver?.driverId == driverId) {
              _selectedDriver = null;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔴 Driver $driverId went offline'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });

      _viewerService.onError((error) {
        if (mounted) {
          setState(() {
            _error = error;
          });
        }
      });

      // Connect
      await _viewerService.connect();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
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

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitBounds(bounds,
        options: const FitBoundsOptions(padding: EdgeInsets.all(50)));
  }

  /**
   * Get marker color based on driver status
   * @private
   */
  Color _getMarkerColor(DriverLocation driver) {
    // Could add more logic here (speed, status, etc.)
    return AppColors.primary;
  }

  /**
   * Get place name from coordinates using reverse geocoding
   */
  Future<void> _getPlaceName(DriverLocation driver) async {
    if (_driverPlaceNames.containsKey(driver.driverId)) {
      return; // Already cached
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        driver.latitude,
        driver.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final placeName = [place.street, place.locality, place.country]
            .where((p) => p != null && p.isNotEmpty)
            .join(', ');

        if (mounted) {
          setState(() {
            _driverPlaceNames[driver.driverId] = placeName.isNotEmpty
                ? placeName
                : '${driver.latitude.toStringAsFixed(4)}, ${driver.longitude.toStringAsFixed(4)}';
          });
        }
      }
    } catch (error) {
      // Geocoding failed (e.g., no Google Play Services on emulator) - use coordinates as fallback
      if (mounted) {
        setState(() {
          _driverPlaceNames[driver.driverId] =
              '${driver.latitude.toStringAsFixed(4)}, ${driver.longitude.toStringAsFixed(4)}';
        });
      }
    }
  }

  @override
  void dispose() {
    _viewerService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
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
                          'Fleet Tracking',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_drivers.length} drivers online',
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
                            _isConnected ? 'Connected' : 'Connecting',
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
              child: const Icon(
                Icons.fullscreen_exit,
                color: Colors.black,
              ),
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildDriverList(),
          ),
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
                        'Active Drivers',
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
                          'No active drivers',
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
                                '${driver.ambulanceId}\n'
                                '📍 ${_driverPlaceNames[driver.driverId] ?? 'Loading location...'}',
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
                    'Online',
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
              'Ambulance: ${driver.ambulanceId}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              '📍 ${_driverPlaceNames[driver.driverId] ?? 'Loading location...'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Updated: ${driver.timestamp.toString().split('.')[0]}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
