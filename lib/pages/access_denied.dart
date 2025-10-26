import 'package:flutter/material.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Denied'),
        automaticallyImplyLeading: false, // Prevent going back if this is a blocking page
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.lock_outline, // A lock icon to visually indicate restricted access
                size: 80,
                color: Colors.redAccent, // Use a color that signifies a warning or denial
              ),
              SizedBox(height: 24),
              Text(
                'You don\'t have access to this app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Please contact your administrator for assistance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 32),
              // Optional: Add a button to log out or close the app
              // ElevatedButton(
              //   onPressed: () {
              //     // Implement logout logic here if applicable,
              //     // or simply navigate back to a login screen.
              //     // For example:
              //     Navigator.of(context).pushReplacementNamed('/login'); // Assuming you have a login route
              //     // Or, if truly blocking: exit(0); // From 'dart:io', to close the app (use with caution)
              //   },
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.blueAccent, // A clear call to action color
              //     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              //     shape: RoundedRectangleBorder(
              //       borderRadius: BorderRadius.circular(8),
              //     ),
              //   ),
              //   child: const Text(
              //     'Contact Admin / Go to Login',
              //     style: TextStyle(
              //       fontSize: 18,
              //       color: Colors.white,
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}