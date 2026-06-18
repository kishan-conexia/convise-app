import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/profile/profile_field_edit_sheet.dart';


class AboutMePage extends StatefulWidget {
  const AboutMePage({super.key});

  @override
  State<AboutMePage> createState() => _AboutMePageState();
}

class _AboutMePageState extends State<AboutMePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'Personal',   'icon': Icons.person_outline},
    {'label': 'Contact',    'icon': Icons.contact_phone_outlined},
    {'label': 'Employment', 'icon': Icons.work_outline},
    {'label': 'Bank',       'icon': Icons.account_balance_outlined},
    {'label': 'Statutory',  'icon': Icons.gavel_outlined},
    {'label': 'Attributes', 'icon': Icons.tune_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState        = Provider.of<AppState>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      profileProvider.fetchAll(appState.userId);   // ← forced refreshed is removed, it was like: profileProvider.fetchAll(appState.userId, forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState        = Provider.of<AppState>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final profile         = appState.employeeProfile;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          title: const Text('About Me',
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
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: _tabs.map((t) => Tab(
              icon: Icon(t['icon'] as IconData, size: 18),
              text: t['label'] as String,
            )).toList(),
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
        child: profileProvider.loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          controller: _tabController,
          children: [
            // TAB 1 – Personal
            _TabContent(
              showRequestButton: true,
              fields: [
                _F(Icons.person,          'Full Name',      profile['full_name'] ?? ''),
                _F(Icons.cake_outlined,   'Date of Birth',  profileProvider.profileDetails?.dateOfBirth ?? ''),
                _F(Icons.wc_outlined,     'Gender',         profile['gender'] ?? ''),
                _F(Icons.favorite_border, 'Marital Status', profileProvider.profileDetails?.maritalStatus ?? ''),
              ],
            ),

            // TAB 2 – Contact
            _TabContent(
              showRequestButton: true,
              fields: [
                _F(Icons.phone_outlined,         'Phone',             appState.userPhone),
                _F(Icons.email_outlined,         'Email',             appState.userEmail),
                _F(Icons.home_outlined,          'Current Address',   profileProvider.profileDetails?.currentAddress ?? ''),
                _F(Icons.location_city_outlined, 'Permanent Address', profileProvider.profileDetails?.permanentAddress ?? ''),
              ],
            ),

            // TAB 3 – Employment
            _TabContent(fields: [
              _F(Icons.badge_outlined,           'Employee Code',    appState.empCode),
              _F(Icons.business_outlined,        'Department',       profileProvider.departmentName ?? ''),
              _F(Icons.work_history_outlined,    'Designation',      profileProvider.positionDesignation ?? ''),
              _F(Icons.layers_outlined,          'Level',            profileProvider.positionLevel ?? ''),
              _F(Icons.calendar_today_outlined,  'Joining Date',     profile['date_of_joining'] ?? ''),
              _F(Icons.timer_outlined,           'Employment Type',  profile['employment_type'] ?? ''),
            ]),

            // TAB 4 – Bank
            _TabContent(fields: [
              _F(Icons.account_balance_outlined, 'Bank Name',       profileProvider.profileDetails?.bankName ?? ''),
              _F(Icons.numbers_outlined,         'Account Number',  profileProvider.profileDetails?.accountNumber ?? ''),
              _F(Icons.category_outlined,        'Account Type',    profileProvider.profileDetails?.accountType ?? ''),
              _F(Icons.code_outlined,            'IFSC Code',       profileProvider.profileDetails?.ifscCode ?? ''),
              _F(Icons.location_city_outlined,   'Branch Name',     profileProvider.profileDetails?.branchName ?? ''),
            ]),

            // TAB 5 – Statutory
            _TabContent(fields: [
              _F(Icons.fingerprint,                  'Aadhaar Number',  profileProvider.profileDetails?.aadhaarNumber ?? ''),
              _F(Icons.credit_card_outlined,         'PAN Number',      profileProvider.profileDetails?.panNumber ?? ''),
              _F(Icons.book_outlined,                'Passport Number', profileProvider.profileDetails?.passportNumber ?? ''),
            ]),

            // TAB 6 – Attributes
            _TabContent(fields: [
              _F(Icons.grade_outlined,   'Approval Levels', profile['approval_levels']?.toString() ?? ''),
              _F(Icons.toggle_on_outlined,'App Access',     profile['app_access'] == true ? 'Enabled' : 'Disabled'),
              _F(Icons.language,         'Web Access',      profile['web_access'] == true ? 'Enabled' : 'Disabled'),
              _F(Icons.my_location,      'Geofencing',      profile['geofencing'] == true ? 'Enabled' : 'Disabled'),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Shorthand alias ───────────────────────────────────────────
typedef _F = _FieldData;

// ─── Reusable Tab + Field ──────────────────────────────────────
class _FieldData {
  final IconData icon;
  final String label;
  final String value;
  const _FieldData(this.icon, this.label, this.value);
}

class _TabContent extends StatelessWidget {
  final List<_FieldData> fields;
  final bool showRequestButton;

  const _TabContent({
    required this.fields,
    this.showRequestButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        ...fields.map((f) => _buildField(f)),
        const SizedBox(height: 20),
        if (showRequestButton) _buildRequestButton(context),
      ],
    );
  }

  Widget _buildField(_FieldData f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.8),
            Colors.white.withOpacity(0.5)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3))
        ],
      ),
      child: ListTile(
        leading: Icon(f.icon, color: Colors.blue.shade600, size: 22),
        title: Text(f.label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          f.value.isNotEmpty ? f.value : 'Not set',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: f.value.isNotEmpty
                ? Colors.black87
                : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showUpdateSheet(context),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Request Update'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  void _showUpdateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
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
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_outlined,
                        color: Colors.blue.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Request Update',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      Text('Select a field to update',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...[
                ('date_of_birth',     Icons.cake_outlined,         'Date of Birth'),
                ('marital_status',    Icons.favorite_border,       'Marital Status'),
                ('current_address',   Icons.home_outlined,         'Current Address'),
                ('permanent_address', Icons.location_city_outlined,'Permanent Address'),
              ].map((f) => ListTile(
                contentPadding:
                const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.grey.shade50,
                leading: Icon(f.$2,
                    color: Colors.blue.shade600, size: 20),
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

                  final alreadyPending = provider.hasPendingRequest(
                    subtype:  'profile_field',
                    fieldKey: f.$1,
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
                    builder: (_) => ProfileFieldEditSheet(
                      fieldKey:     f.$1,
                      fieldLabel:   f.$3,
                      currentValue: _currentValueFor(f.$1, context),
                    ),
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  String _currentValueFor(String fieldKey, BuildContext context) {
    final profileProvider =
    Provider.of<ProfileProvider>(context, listen: false);
    final details = profileProvider.profileDetails;
    switch (fieldKey) {
      case 'date_of_birth':     return details?.dateOfBirth      ?? '';
      case 'marital_status':    return details?.maritalStatus    ?? '';
      case 'current_address':   return details?.currentAddress   ?? '';
      case 'permanent_address': return details?.permanentAddress ?? '';
      default: return '';
    }
  }
}
