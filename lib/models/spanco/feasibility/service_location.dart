// lib/models/spanco/feasibility/service_location.dart

class ServiceLocation {
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  ServiceLocation({
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.landmark,
    this.latitude,
    this.longitude,
  });

  /// Create from JSON (handle both string and number types for coordinates)
  factory ServiceLocation.fromJson(Map<String, dynamic> json) {
    return ServiceLocation(
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      landmark: json['landmark'] as String?,

      // ✅ Robust parsing for latitude (handles string or number)
      latitude: _parseCoordinate(json['latitude']),

      // ✅ Robust parsing for longitude (handles string or number)
      longitude: _parseCoordinate(json['longitude']),
    );
  }

  /// Helper method to parse coordinate from string or number
  static double? _parseCoordinate(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);

    return null; // Unknown type
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      if (landmark != null) 'landmark': landmark,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  String get fullAddress {
    final parts = [address, landmark, city, state, pincode];
    return parts.where((p) => p != null && p.isNotEmpty).join(', ');
  }

  /// Create a copy with updated fields
  ServiceLocation copyWith({
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? landmark,
    double? latitude,
    double? longitude,
  }) {
    return ServiceLocation(
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() {
    return 'ServiceLocation(address: $address, city: $city, state: $state, '
        'pincode: $pincode, lat: $latitude, lng: $longitude)';
  }
}
