// lib/models/device.dart
class Device {
  final String id;
  final String hostname;
  final String location;
  final int interfaces;
  final String os;
  final String uptime;
  final String detailsPath;  // e.g. "device/device=149/"

  Device({
    required this.id,
    required this.hostname,
    required this.location,
    required this.interfaces,
    required this.os,
    required this.uptime,
    required this.detailsPath,
  });

  @override
  String toString() {
    return 'Device(id=$id, hostname=$hostname, location=$location, '
        'interfaces=$interfaces, os=$os, uptime=$uptime, '
        'detailsPath=$detailsPath)';
  }
}
