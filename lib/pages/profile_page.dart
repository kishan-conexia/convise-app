import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool loading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text(
            'My Profile',
            overflow: TextOverflow.ellipsis,
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
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.blue.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          children: [
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: (appState.userAvatar.isNotEmpty)
                    ? NetworkImage(appState.userAvatar)
                    : null,
                backgroundColor: (appState.userAvatar.isEmpty)
                    ? (appState.userName.isNotEmpty)
                    ? _isNumeric(appState.userName!)
                    ? Colors.blueGrey // Background for numeric-only names
                    : getColorForLetter(getFirstValidLetter(appState.userName)?.toUpperCase() ?? '')
                    : Colors.grey // For null or empty names
                    : Colors.transparent,
                child: (appState.userAvatar.isEmpty)
                    ? (getFirstValidLetter(appState.userName) != null
                    ? Text(
                  getFirstValidLetter(appState.userName)!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.white,
                ))
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                appState.userName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 24),
            if (appState.empCode.isNotEmpty) _buildProfileField(Icons.badge, 'Employee Code', appState.empCode),
            if (appState.userPhone.isNotEmpty) _buildProfileField(Icons.phone, 'Phone', appState.userPhone),
            if (appState.userEmail.isNotEmpty) _buildProfileField(Icons.email, 'Email', appState.userEmail),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value.isNotEmpty ? value : 'Not set'),
      ),
    );
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

  bool _isNumeric(String input) {
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(input);
  }

}
