// import 'dart:io';
// import 'dart:math';
//
// import 'package:app_settings/app_settings.dart';
// import 'package:flutter/material.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
//
// import '../main.dart';
// import '../models/app_state.dart';
//
// class AttendancePage2 extends StatefulWidget {
//   const AttendancePage2({super.key});
//
//   @override
//   _AttendancePage2State createState() => _AttendancePage2State();
// }
//
// class _AttendancePage2State extends State<AttendancePage2> {
//   bool loading = true;
//   bool processingPunch = false;
//
//   String? currentLocation;
//
//
//   @override
//   void initState() {
//     super.initState();
//     fetchAttendance();
//   }
//
//   Future<void> fetchAttendance() async {
//     // Simulating data fetching delay
//     // await Future.delayed(const Duration(seconds: 2));
//     setState(() {
//       loading = false;
//     });
//   }
//
//
//
//   Future<void> _fetchCurrentLocation(bool isPunchIn) async {
//     bool serviceEnabled;
//     LocationPermission permission;
//
//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       _showMessage("Location services are disabled.");
//       return;
//     }
//
//     permission = await Geolocator.checkPermission();
//
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         _showMessage("Location permission denied.");
//         return;
//       }
//     }
//
//     if (permission == LocationPermission.deniedForever) {
//       _showPermissionDialog();
//       return;
//     }
//
//     try {
//       // Permission granted - use platform-specific settings
//       Position position = await Geolocator.getCurrentPosition(
//         locationSettings: Platform.isAndroid
//             ? AndroidSettings(
//           accuracy: LocationAccuracy.high,
//           // forceLocationManager: true,
//         )
//             : AppleSettings(
//           accuracy: LocationAccuracy.high,
//           activityType: ActivityType.fitness,
//         ),
//       );
//
//       // Check if the accuracy is acceptable (e.g., less than 100 meters)
//       if (position.accuracy > 100) {
//         _showApproximateDialog();
//         return;
//       }
//
//       setState(() {
//         currentLocation = '${position.latitude}, ${position.longitude}';
//       });
//
//       print("Current Location: $currentLocation (Accuracy: ${position.accuracy}m)");
//
//       await _checkGeofence(position, isPunchIn);
//
//     } catch (e) {
//       _showMessage("Failed to get location: $e");
//     }
//   }
//
//
//   // it is working as expected
//   Future<void> _checkGeofence(Position position, bool isPunchIn) async {
//     final currentLat = position.latitude;
//     final currentLng = position.longitude;
//     final radius = AppState().radius;
//
//     if (AppState().geofencing != true || AppState().workLocation.isEmpty) return;
//
//
//     final locationKeyword = AppState().workLocation.trim().toLowerCase();
//
//     if (locationKeyword.contains(',')) {
//       // 🔍 Treat as coordinates
//       final workCoords = locationKeyword.split(',');
//       if (workCoords.length == 2) {
//         final workLat = double.tryParse(workCoords[0].trim()) ?? 0.0;
//         final workLng = double.tryParse(workCoords[1].trim()) ?? 0.0;
//
//         final distance = Geolocator.distanceBetween(
//           currentLat,
//           currentLng,
//           workLat,
//           workLng,
//         );
//
//         print("📏 Distance from work location: ${distance.toStringAsFixed(2)} meters");
//
//         if (distance > radius) {
//           print("🚫 Outside allowed radius of $radius meters");
//         } else {
//           print("✅ Within allowed radius");
//           await handleAttendance(isPunchIn);
//         }
//       } else {
//         print("⚠️ Invalid coordinate format");
//       }
//
//     } else {
//       // 🏙️ Treat as location name (e.g., city)
//       try {
//         List<Placemark> placemarks = await placemarkFromCoordinates(currentLat, currentLng);
//         final placemark = placemarks.first;
//
//         String combinedAddress = "${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea}, ${placemark.country}";
//         print("📍 Reverse geocoded address: $combinedAddress");
//
//         if (combinedAddress.toLowerCase().contains(locationKeyword)) {
//           print("✅ Location is inside ${AppState().workLocation}");
//           await handleAttendance(isPunchIn);
//           return;
//         } else {
//           print("🚫 Main location is outside ${AppState().workLocation}, checking nearby directions...");
//         }
//
//         // 8 directions: N, NE, E, SE, S, SW, W, NW
//         final List<double> directions = [0, 45, 90, 135, 180, 225, 270, 315];
//
//         for (double bearing in directions) {
//           LatLng offset = _computeOffset(currentLat, currentLng, radius.toDouble(), bearing);
//           List<Placemark> nearbyPlacemarks = await placemarkFromCoordinates(offset.latitude, offset.longitude);
//
//           final nearPlacemark = nearbyPlacemarks.first;
//           String nearbyAddress = "${nearPlacemark.locality}, ${nearPlacemark.subAdministrativeArea}, ${nearPlacemark.administrativeArea}, ${nearPlacemark.country}";
//           print("🔍 Address at $bearing°: $nearbyAddress");
//
//           if (nearbyAddress.toLowerCase().contains(locationKeyword)) {
//             print("✅ Found $locationKeyword nearby at $bearing°, considering location as valid.");
//             await handleAttendance(isPunchIn);
//             return;
//           }
//         }
//
//         print("🚫 None of the surrounding addresses matched $locationKeyword");
//
//       } catch (e) {
//         print("❌ Failed to reverse geocode: $e");
//       }
//
//     }
//   }
//
//
//   LatLng _computeOffset(double lat, double lng, double distanceInMeters, double bearingInDegrees) {
//     const double earthRadius = 6371000; // meters
//     final double bearingRad = bearingInDegrees * pi / 180;
//     final double latRad = lat * pi / 180;
//     final double lngRad = lng * pi / 180;
//     final double distanceRatio = distanceInMeters / earthRadius;
//
//     final double newLatRad = asin(
//       sin(latRad) * cos(distanceRatio) +
//           cos(latRad) * sin(distanceRatio) * cos(bearingRad),
//     );
//
//     final double newLngRad = lngRad +
//         atan2(
//           sin(bearingRad) * sin(distanceRatio) * cos(latRad),
//           cos(distanceRatio) - sin(latRad) * sin(newLatRad),
//         );
//
//     return LatLng(newLatRad * 180 / pi, newLngRad * 180 / pi);
//   }
//
//
//
//
//
//   void _showPermissionDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Permission Required"),
//         content: const Text("Location permission is permanently denied. Please enable it from settings."),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//             },
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () {
//               AppSettings.openAppSettings();
//               Navigator.pop(context);
//             },
//             child: const Text("Open Settings"),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showApproximateDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Precise Location Required"),
//         content: const Text(
//           "Your device is providing approximate location. Please allow precise location in app settings.",
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Cancel"),
//           ),
//           TextButton(
//             onPressed: () {
//               AppSettings.openAppSettings();
//               Navigator.pop(context);
//             },
//             child: const Text("Open Settings"),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   void _showMessage(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         duration: const Duration(seconds: 3),
//       ),
//     );
//   }
//
//   Future<void> handleAttendance(bool isPunchIn) async {
//     try {
//       final DateTime currentTime = await AppState().getCurrentTime();
//
//       final String? location = currentLocation; // Replace with your location string logic
//       final String profileId = AppState().userId ?? ''; // Ensure this is available
//
//       if (profileId.isEmpty) {
//         _showMessage("User not logged in");
//         return;
//       }
//
//       final String dateString = currentTime.toUtc().toIso8601String().substring(0, 10); // 'YYYY-MM-DD'
//
//       final existingRecord = await supabase
//           .from('attendance')
//           .select('id, punch_out')
//           .eq('employee_id', profileId)
//           .eq('date', dateString)
//           .maybeSingle();
//
//       if (isPunchIn) {
//         if (existingRecord == null) {
//           // First check-in of the day
//           await supabase.from('attendance').insert({
//             'employee_id': profileId,
//             'punch_in': currentTime.toUtc().toIso8601String(),
//             'punch_in_location': location,
//             'date': currentTime.toUtc().toIso8601String().substring(0, 10), // 'YYYY-MM-DD'
//           });
//
//           _showMessage("✅ Punch-in successful at $currentTime");
//         } else {
//           _showMessage("⚠️ Already punched in today.");
//         }
//       } else {
//         if (existingRecord != null && existingRecord['punch_out'] == null) {
//           // Punch-out for the same day
//           await supabase.from('attendance').update({
//             'punch_out': currentTime.toUtc().toIso8601String(),
//             'punch_out_location': location,
//           }).eq('id', existingRecord['id']);
//
//           _showMessage("✅ Punch-out successful at $currentTime");
//         } else {
//           _showMessage("⚠️ No punch-in found or already punched out.");
//         }
//       }
//     } catch (e) {
//       _showMessage("❌ Failed to mark attendance: $e");
//       print("❌ Failed to mark attendance: $e");
//     }
//   }
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(60),
//         child: AppBar(
//           title: const Text(
//             'Attendance',
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w600,
//               fontSize: 18,
//             ),
//           ),
//           elevation: 0.0,
//           backgroundColor: Colors.transparent,
//           flexibleSpace: Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: const BorderRadius.vertical(
//                 bottom: Radius.circular(20),
//               ),
//             ),
//           ),
//         ),
//       ),
//       body: loading
//           ? const Center(child: CircularProgressIndicator())
//           : Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             ElevatedButton(
//               onPressed: () => _fetchCurrentLocation(true),
//               child: const Text('Punch In'),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () => _fetchCurrentLocation(false),
//               child: const Text('Punch Out'),
//             ),
//           ],
//         ),
//       ),
//
//     );
//   }
//
//
//
//
// // Future<void> _checkGeofence(Position position) async {
// //   if (AppState().workLocation.isNotEmpty && AppState().geofencing == true) {
// //     final currentLat = position.latitude;
// //     final currentLng = position.longitude;
// //
// //     final workCoords = AppState().workLocation.split(',');
// //     if (workCoords.length == 2) {
// //       final workLat = double.tryParse(workCoords[0].trim()) ?? 0.0;
// //       final workLng = double.tryParse(workCoords[1].trim()) ?? 0.0;
// //
// //       final distance = Geolocator.distanceBetween(
// //         currentLat,
// //         currentLng,
// //         workLat,
// //         workLng,
// //       );
// //
// //       print("📏 Distance from work location: ${distance.toStringAsFixed(2)} meters");
// //
// //       if (distance > AppState().radius) {
// //         print("🚫 Outside allowed radius of ${AppState().radius} meters");
// //         // Optionally show a dialog/snackbar here
// //         // _showMessage("You're outside the allowed location radius.");
// //       } else {
// //         print("✅ Within allowed radius");
// //       }
// //     } else {
// //       print("⚠️ Invalid work location format in AppState");
// //     }
// //   }
// // }
// // Future<void> _checkGeofence(Position position) async {
// //   final currentLat = position.latitude;
// //   final currentLng = position.longitude;
// //   final radius = AppState().radius;
// //
// //   if (AppState().geofencing != true || AppState().workLocation.isEmpty) return;
// //
// //
// //   final locationKeyword = AppState().workLocation.trim().toLowerCase();
// //
// //   if (locationKeyword.contains(',')) {
// //     // 🔍 Treat as coordinates
// //     final workCoords = locationKeyword.split(',');
// //     if (workCoords.length == 2) {
// //       final workLat = double.tryParse(workCoords[0].trim()) ?? 0.0;
// //       final workLng = double.tryParse(workCoords[1].trim()) ?? 0.0;
// //
// //       final distance = Geolocator.distanceBetween(
// //         currentLat,
// //         currentLng,
// //         workLat,
// //         workLng,
// //       );
// //
// //       print("📏 Distance from work location: ${distance.toStringAsFixed(2)} meters");
// //
// //       if (distance > radius) {
// //         print("🚫 Outside allowed radius of $radius meters");
// //       } else {
// //         print("✅ Within allowed radius");
// //       }
// //     } else {
// //       print("⚠️ Invalid coordinate format");
// //     }
// //
// //   } else {
// //     // 🏙️ Treat as location name (e.g., city)
// //     try {
// //       List<Placemark> placemarks = await placemarkFromCoordinates(currentLat, currentLng);
// //       final placemark = placemarks.first;
// //
// //       String combinedAddress = "${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea}, ${placemark.country}";
// //       print("📍 Reverse geocoded address: $combinedAddress");
// //
// //       if (combinedAddress.toLowerCase().contains(locationKeyword)) {
// //         print("✅ Location is inside ${AppState().workLocation}");
// //       } else {
// //         print("🚫 Location is outside ${AppState().workLocation}");
// //       }
// //
// //     } catch (e) {
// //       print("❌ Failed to reverse geocode: $e");
// //     }
// //   }
// // }
//
//
// }
//
// class LatLng {
//   final double latitude;
//   final double longitude;
//
//   LatLng(this.latitude, this.longitude);
// }
