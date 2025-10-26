import 'package:flutter/material.dart';
import 'package:mnr/models/app_state.dart';
import 'package:provider/provider.dart';


class DeviceInfoPage extends StatefulWidget {
  final String deviceId;
  final bool deviceChanged;



  const DeviceInfoPage({super.key, required this.deviceId, required this.deviceChanged});

  @override
  _DeviceInfoPageState createState() => _DeviceInfoPageState();
}

class _DeviceInfoPageState extends State<DeviceInfoPage> {
  bool loading = false;

  @override
  void initState() {
    super.initState();

  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: AppBar(
              title: const Text('Device Changed', style: TextStyle(color: Colors.white),),
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: true,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: appState.appBarGradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  Icon(Icons.warning_amber_rounded, size: 60, color: Colors.red.shade700),
                  const SizedBox(height: 20),
                  Text(
                    'Device Change Detected!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your account is being accessed from a different device.\nFor your security, please contact the administrator or verify your identity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  // Card(
                  //   color: Colors.blue.shade50,
                  //   elevation: 2,
                  //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  //   child: ListTile(
                  //     leading: const Icon(Icons.devices),
                  //     title: const Text('Current Device ID'),
                  //     subtitle: Text(widget.deviceId),
                  //   ),
                  // ),
                  const SizedBox(height: 30),
                  // ElevatedButton.icon(
                  //   onPressed: () {
                  //     // Handle contact admin or verification action
                  //   },
                  //   icon: const Icon(Icons.support_agent),
                  //   label: const Text('Contact Support'),
                  //   style: ElevatedButton.styleFrom(
                  //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  //     backgroundColor: Colors.blue.shade300,
                  //     textStyle: const TextStyle(fontSize: 16),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> deviceChangeRequest() async {

  }



}
