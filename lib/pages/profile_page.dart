import 'package:flutter/material.dart';
import 'package:mnr/pages/profile/about_me_page.dart';
import 'package:mnr/pages/profile/address_page.dart';
import 'package:mnr/pages/profile/documents_page.dart';
import 'package:mnr/pages/profile/family_page.dart';
import 'package:mnr/pages/profile/request_history_page.dart';
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
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text(
            'My Profile',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
          // AppBar actions — hide history button for test account
          actions: [
            if (!appState.isTestAccount)
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  Future.microtask(() {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestHistoryPage()));
                  });
                },
              ),
          ],
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
            // Avatar
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: appState.userAvatar.isNotEmpty
                    ? NetworkImage(appState.userAvatar)
                    : null,
                backgroundColor: appState.userAvatar.isEmpty
                    ? (appState.userName.isNotEmpty
                    ? _isNumeric(appState.userName!)
                    ? Colors.blueGrey
                    : getColorForLetter(getFirstValidLetter(appState.userName)?.toUpperCase() ?? '')
                    : Colors.grey)
                    : Colors.transparent,
                child: appState.userAvatar.isEmpty
                    ? (getFirstValidLetter(appState.userName) != null
                    ? Text(
                  getFirstValidLetter(appState.userName)!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.person, size: 50, color: Colors.white))
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // Name
            Center(
              child: Text(
                appState.userName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            // Emp Code + basic info
            if (appState.empCode.isNotEmpty)
              Center(
                child: Text(
                  appState.empCode,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),

            const SizedBox(height: 32),

            // Section Cards
            if (!appState.isTestAccount)
              _buildSectionCard(
                context,
                icon: Icons.person_outline,
                label: 'About Me',
                subtitle: 'Personal info, contact details',
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutMePage())),
              ),
            // _buildSectionCard(
            //   context,
            //   icon: Icons.location_on_outlined,
            //   label: 'Address / Coordinates',
            //   subtitle: 'Home address, geo location',
            //   color: Colors.green,
            //   onTap: () => Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const AddressPage()),
            //   ),
            // ),
            if (!appState.isTestAccount)
              _buildSectionCard(
                context,
                icon: Icons.people_outline,
                label: 'Family',
                subtitle: 'Parents, spouse, children, nominees',
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyPage())),
              ),

            if (!appState.isTestAccount)
              _buildSectionCard(
                context,
                icon: Icons.folder_outlined,
                label: 'Documents',
                subtitle: 'Aadhaar, PAN, bank details',
                color: Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsPage())),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Color getColorForLetter(String letter) {
    if (letter.isEmpty) return Colors.grey;
    switch (letter.toUpperCase()) {
      case 'A': case 'B': case 'C': return Colors.blue.shade400;
      case 'D': case 'E': case 'F': return Colors.orange.shade400;
      case 'G': case 'H': case 'I': return Colors.green.shade400;
      case 'J': case 'K': case 'L': return Colors.brown.shade300;
      case 'M': case 'N': case 'O': return Colors.teal.shade300;
      case 'P': case 'Q': case 'R': return Colors.red.shade400;
      case 'S': case 'T': case 'U': return Colors.yellow.shade700;
      case 'V': case 'W': case 'X': return Colors.purple.shade300;
      case 'Y': case 'Z': return Colors.pink.shade300;
      default: return Colors.blueGrey;
    }
  }

  String? getFirstValidLetter(String? input) {
    if (input == null || input.isEmpty) return null;
    for (int i = 0; i < input.length; i++) {
      if (RegExp(r'[A-Za-z]').hasMatch(input[i])) return input[i].toUpperCase();
    }
    return null;
  }

  bool _isNumeric(String input) => RegExp(r'^[0-9]+$').hasMatch(input);
}
