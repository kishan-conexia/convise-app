import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/profile_details.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/profile/family_edit_request_sheet.dart';  // ← add

class FamilyPage extends StatefulWidget {   // ← StatefulWidget
  const FamilyPage({super.key});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState        = Provider.of<AppState>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      if (!profileProvider.initialized) {
        profileProvider.fetchAll(appState.userId);
      }
    });
  }

  void _showFamilyEditPicker() {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final details  = provider.profileDetails;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('What would you like to update?',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            ...[
              ('father_name', Icons.man_outlined,          'Father Name',  Colors.orange, FamilyRequestType.field),
              ('mother_name', Icons.woman_outlined,        'Mother Name',  Colors.pink,   FamilyRequestType.field),
              ('spouse_name', Icons.people_outline,        'Spouse Name',  Colors.pink,   FamilyRequestType.field),
              ('children',    Icons.child_care_outlined,   'Children',     Colors.teal,   FamilyRequestType.children),
              ('nominees',    Icons.verified_user_outlined,'Nominees',     Colors.purple, FamilyRequestType.nominees),
            ].map((f) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding:
                const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(f.$2, color: f.$4, size: 20),
                title: Text(f.$3,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 20),
                onTap: () {
                  Navigator.pop(context);

                  final provider =
                  Provider.of<ProfileProvider>(context, listen: false);

                  // Determine subtype for this item
                  final checkSubtype = f.$5 == FamilyRequestType.field
                      ? 'family_field'
                      : f.$5 == FamilyRequestType.children
                      ? 'children'
                      : 'nominees';

                  final checkField = f.$5 == FamilyRequestType.field
                      ? f.$1  // father_name / mother_name / spouse_name
                      : null; // children & nominees are array-level, no field key

                  final alreadyPending = provider.hasPendingRequest(
                    subtype:  checkSubtype,
                    fieldKey: checkField,
                  );

                  if (alreadyPending) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        'A pending request for "${f.$3}" already exists. '
                            'Please wait for it to be reviewed.',
                      ),
                      behavior:        SnackBarBehavior.floating,
                      backgroundColor: Colors.orange.shade700,
                    ));
                    return;
                  }

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => FamilyEditRequestSheet(
                      requestType:  f.$5,
                      fieldKey:     f.$1,
                      fieldLabel:   f.$3,
                      currentValue: f.$5 == FamilyRequestType.field
                          ? _currentFamily(f.$1, details)
                          : null,
                      currentList: f.$5 == FamilyRequestType.children
                          ? details?.children
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList()
                          : f.$5 == FamilyRequestType.nominees
                          ? details?.nominees
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList()
                          : null,
                    ),
                  );
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _currentFamily(String field, ProfileDetails? d) {
    switch (field) {
      case 'father_name': return d?.fatherName ?? '';
      case 'mother_name': return d?.motherName ?? '';
      case 'spouse_name': return d?.spouseName ?? '';
      default:            return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context);
    final details  = provider.profileDetails;

    final children = (details?.children ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final nominees = (details?.nominees ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text('Family',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white70,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.blue.shade600,
                  Colors.blue.shade800
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
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
        child: provider.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 24),
          children: [

            // ── Parents ──────────────────────────────
            _SectionHeader(
                icon: Icons.family_restroom_outlined,
                title: 'Parents',
                color: Colors.orange),
            const SizedBox(height: 12),
            _FamilyMemberCard(
              avatar: 'F', avatarColor: Colors.orange,
              name: details?.fatherName ?? '',
              nameLabel: 'Father',
              icon: Icons.man_outlined,
            ),
            _FamilyMemberCard(
              avatar: 'M', avatarColor: Colors.pink,
              name: details?.motherName ?? '',
              nameLabel: 'Mother',
              icon: Icons.woman_outlined,
            ),

            const SizedBox(height: 24),

            // ── Spouse ───────────────────────────────
            _SectionHeader(
                icon: Icons.favorite_border,
                title: 'Spouse',
                color: Colors.pink),
            const SizedBox(height: 12),
            _FamilyMemberCard(
              avatar: 'S', avatarColor: Colors.pink,
              name: details?.spouseName ?? '',
              nameLabel: 'Spouse',
              icon: Icons.people_outline,
            ),

            const SizedBox(height: 24),

            // ── Children ─────────────────────────────
            _SectionHeader(
                icon: Icons.child_care_outlined,
                title: 'Children',
                color: Colors.teal,
                count: children.length),
            const SizedBox(height: 12),
            if (children.isEmpty)
              const _EmptyState(message: 'No children added')
            else
              ...children.asMap().entries.map((e) =>
                  _ChildCard(index: e.key + 1, data: e.value)),

            const SizedBox(height: 24),

            // ── Nominees ─────────────────────────────
            _SectionHeader(
                icon: Icons.verified_user_outlined,
                title: 'Nominees',
                color: Colors.purple,
                count: nominees.length),
            const SizedBox(height: 12),
            if (nominees.isNotEmpty)
              _ShareBar(nominees: nominees),
            const SizedBox(height: 8),
            if (nominees.isEmpty)
              const _EmptyState(message: 'No nominees added')
            else
              ...nominees.asMap().entries.map((e) =>
                  _NomineeCard(index: e.key + 1, data: e.value)),

            const SizedBox(height: 32),

            // ── Request Update Button ─────────────────
            ElevatedButton.icon(
              onPressed: _showFamilyEditPicker,  // ← wired
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Request Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── All helper widgets below stay exactly as-is ───────────────
// _SectionHeader, _FamilyMemberCard, _ChildCard, _NomineeCard,
// _ShareBar, _Chip, _EmptyState — no changes needed

// ─────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final int? count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Family Member Card (Father / Mother / Spouse)
// ─────────────────────────────────────────────────────────────
class _FamilyMemberCard extends StatelessWidget {
  final String avatar;
  final Color avatarColor;
  final String name;
  final String nameLabel;
  final IconData icon;

  const _FamilyMemberCard({
    required this.avatar,
    required this.avatarColor,
    required this.name,
    required this.nameLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: avatarColor.withOpacity(0.15),
          child: Text(avatar,
              style: TextStyle(
                  color: avatarColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        title: Text(nameLabel,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          name.isNotEmpty ? name : 'Not set',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: name.isNotEmpty ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Child Card
// ─────────────────────────────────────────────────────────────
class _ChildCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;

  const _ChildCard({required this.index, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.teal.shade100,
            child: Text(
              _initials(data['name'] ?? 'C$index'),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Child $index',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (data['gender'] != null)
                      _Chip(
                        icon: Icons.wc_outlined,
                        label: data['gender'],
                        color: Colors.teal,
                      ),
                    if (data['dob'] != null)
                      _Chip(
                        icon: Icons.cake_outlined,
                        label: data['dob'],
                        color: Colors.teal,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'C';
  }
}

// ─────────────────────────────────────────────────────────────
// Nominee Card
// ─────────────────────────────────────────────────────────────
class _NomineeCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;

  const _NomineeCard({required this.index, required this.data});

  @override
  Widget build(BuildContext context) {
    final share = data['share_percentage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.purple.shade100,
            child: Text(
              _initials(data['name'] ?? 'N$index'),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['name'] ?? 'Nominee $index',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (share != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          '$share%',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.purple.shade700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (data['relation'] != null)
                      _Chip(
                        icon: Icons.people_outline,
                        label: data['relation'],
                        color: Colors.purple,
                      ),
                    if (data['dob'] != null)
                      _Chip(
                        icon: Icons.cake_outlined,
                        label: data['dob'],
                        color: Colors.purple,
                      ),
                    if (data['contact'] != null)
                      _Chip(
                        icon: Icons.phone_outlined,
                        label: data['contact'],
                        color: Colors.purple,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'N';
  }
}

// ─────────────────────────────────────────────────────────────
// Share Bar (total % validator for nominees)
// ─────────────────────────────────────────────────────────────
class _ShareBar extends StatelessWidget {
  final List<Map<String, dynamic>> nominees;
  const _ShareBar({required this.nominees});

  @override
  Widget build(BuildContext context) {
    final total = nominees.fold<num>(
        0, (sum, n) => sum + (n['share_percentage'] ?? 0));
    final isValid = total == 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.green.shade200 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            size: 18,
            color: isValid ? Colors.green.shade600 : Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            isValid
                ? 'Total share: 100% ✓'
                : 'Total share: $total% (should be 100%)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isValid ? Colors.green.shade700 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Chip (small tag inside cards)
// ─────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(message,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }
}
