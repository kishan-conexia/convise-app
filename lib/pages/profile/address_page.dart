import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';

class AddressPage extends StatelessWidget {
  const AddressPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final profile  = appState.employeeProfile;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text('Address & Coordinates',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [

            // ── Address Section ──────────────────────────────
            _buildSectionHeader(Icons.home_outlined, 'Address Details', Colors.green),
            const SizedBox(height: 12),
            _buildField(
              Icons.home_outlined,
              'Current Address',
              profile['current_address'] ?? '',
              multiline: true,
            ),
            _buildField(
              Icons.location_city_outlined,
              'Permanent Address',
              profile['permanent_address'] ?? '',
              multiline: true,
            ),

            const SizedBox(height: 24),

            // ── Coordinates Section ──────────────────────────
            _buildSectionHeader(Icons.my_location_outlined, 'Coordinates', Colors.blue),
            const SizedBox(height: 12),
            _buildField(Icons.map_outlined,         'Latitude',  profile['latitude']?.toString()  ?? ''),
            _buildField(Icons.map_outlined,         'Longitude', profile['longitude']?.toString() ?? ''),
            _buildField(Icons.radar_outlined,       'Geofencing Radius', profile['geofencing_radius']?.toString() ?? ''),

            const SizedBox(height: 8),

            // Geofencing status badge
            _buildGeofencingBadge(profile['geofencing'] == true),

            const SizedBox(height: 32),

            // ── Request Update Button ────────────────────────
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Open request update form
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Request Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildField(IconData icon, String label, String value, {bool multiline = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: multiline ? 8 : 0,
        ),
        leading: Icon(icon, color: Colors.blue.shade600, size: 22),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value.isNotEmpty ? value : 'Not set',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: value.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
          ),
          maxLines: multiline ? 4 : 1,
          overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildGeofencingBadge(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: enabled ? Colors.green.shade600 : Colors.red.shade400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            enabled ? 'Geofencing is active for this account' : 'Geofencing is disabled for this account',
            style: TextStyle(
              fontSize: 13,
              color: enabled ? Colors.green.shade700 : Colors.red.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
