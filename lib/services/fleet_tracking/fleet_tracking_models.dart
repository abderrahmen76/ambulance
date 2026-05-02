/**
 * Fleet Tracking Data Models
 */

class DriverLocation {
  final String driverId;
  final double latitude;
  final double longitude;
  final String ambulanceId;
  final String driverName;
  final DateTime timestamp;
  final bool isOnline;

  DriverLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.ambulanceId,
    required this.driverName,
    required this.timestamp,
    this.isOnline = true,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      driverId: json['driverId'] ?? json['driver_id'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      ambulanceId: json['ambulanceId'] ?? json['ambulance_id'] ?? '',
      driverName: json['driverName'] ?? json['driver_name'] ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isOnline: json['isOnline'] ?? json['is_online'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'ambulanceId': ambulanceId,
        'driverName': driverName,
        'timestamp': timestamp.toIso8601String(),
        'isOnline': isOnline,
      };

  @override
  String toString() =>
      'DriverLocation($driverId: $latitude, $longitude @ $timestamp)';
}

class TrackingStats {
  final int activeDrivers;
  final int totalUpdates;
  final DateTime lastUpdate;
  final bool isConnected;

  TrackingStats({
    required this.activeDrivers,
    required this.totalUpdates,
    required this.lastUpdate,
    required this.isConnected,
  });

  @override
  String toString() =>
      'TrackingStats(active: $activeDrivers, updates: $totalUpdates, connected: $isConnected)';
}
