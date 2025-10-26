import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mnr/main.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_state.dart';
import 'device_sensor_page.dart';

class SensorPage extends StatefulWidget {

  const SensorPage({super.key});

  @override
  _SensorPageState createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';


  @override
  void initState() {
    super.initState();
    _initialize();
  }


  Future<void> _initialize() async {

    if (AppState().devices.isEmpty){
      AppState().devices = await AppState().loadObserviumDevices();
    }
    setState(() {
      isLoading = false;
    });
  }


  Widget _buildDeviceCard(d) {
    const iconColor = Colors.blue;
    final iconBgColor = iconColor.withOpacity(0.1);

    return Card(
      // color: Colors.blueGrey.shade50,
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DeviceSensorPage(deviceId: d.detailsPath),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: iconBgColor,
                child: Icon(
                  _getDeviceIcon(d.os),
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      d.location ?? 'Unknown Device',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'IP: ${d.hostname}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }


  IconData _getDeviceIcon(String os) {
    // final lowerOs = os.toLowerCase();
    // if (lowerOs.contains('router')) return Icons.router;
    // if (lowerOs.contains('switch')) return Icons.developer_board;
    // if (lowerOs.contains('firewall')) return Icons.security;
    return Icons.dns_outlined;
  }

  Future<void> _showSignOutDialog() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      _signOut();
    }
  }

  Future<void> _signOut() async {
    try {
      Navigator.of(context).pop();
      await supabase.auth.signOut();
      await Supabase.instance.client.dispose();

      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }

      await AppState().resetState();
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      exit(0);
    } on AuthException catch (error) {
      context.showSnackBar(error.message, isError: true);
    } catch (_) {
      context.showSnackBar('Unexpected error occurred', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Sensor',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          elevation: 0.0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredDevices = appState.devices.where((device) {
                  final query = searchQuery.toLowerCase();
                  return device.hostname.toLowerCase().contains(query) ||
                      device.location.toLowerCase().contains(query) ||
                      device.os.toLowerCase().contains(query);
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildSearchBar(),
                    ),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredDevices.length,
                        itemBuilder: (context, i) {
                          final d = filteredDevices[i];
                          return _buildDeviceCard(d);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search Switches by Name or IP',
          prefixIcon: const Icon(Icons.search, color: Colors.purple),
          filled: true,
          fillColor: Colors.white.withOpacity(0.7),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade100),
          ),
        ),
      ),
    );
  }

  bool _isNumeric(String input) {
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(input);
  }

  // Function to get background color based on the first letter
  Color getColorForLetter(String letter) {
    if (letter.isEmpty) return Colors.grey; // Default color if letter is empty

    switch (letter.toUpperCase()) {
      case 'A':
      case 'B':
      case 'C':
        return Colors.blue.shade400;
      case 'D':
      case 'E':
      case 'F':
        return Colors.orange.shade400;
      case 'G':
      case 'H':
      case 'I':
        return Colors.green.shade400;
      case 'J':
      case 'K':
      case 'L':
        return Colors.brown.shade300;
      case 'M':
      case 'N':
      case 'O':
        return Colors.teal.shade300;
      case 'P':
      case 'Q':
      case 'R':
        return Colors.red.shade400;
      case 'S':
      case 'T':
      case 'U':
        return Colors.yellow.shade700;
      case 'V':
      case 'W':
      case 'X':
        return Colors.purple.shade300;
      case 'Y':
      case 'Z':
        return Colors.pink.shade300; // 'Rose' color
      default:
        return Colors.blueGrey; // Default color for unexpected input
    }
  }

  // Helper function to get the first valid letter
  String? getFirstValidLetter(String? input) {
    if (input == null || input.isEmpty) return null;

    for (int i = 0; i < input.length; i++) {
      if (RegExp(r'[A-Za-z]').hasMatch(input[i])) {
        return input[i].toUpperCase();
      }
    }
    return null; // Return null if no valid letter is found
  }




  @override
  void dispose() {
    searchController.dispose();
    searchQuery = '';

    super.dispose();
  }


}
