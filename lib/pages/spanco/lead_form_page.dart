import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/spanco/spanco_lead.dart';
import '../../providers/lead_provider.dart';

class LeadFormPage extends StatefulWidget {
  final SpancoLead? leadToEdit;
  final Map<String, dynamic>? feasibilityStatus; // ✅ NEW

  const LeadFormPage({
    super.key,
    this.leadToEdit,
    this.feasibilityStatus, // ✅ NEW
  });

  @override
  State<LeadFormPage> createState() => _LeadFormPageState();
}


class _LeadFormPageState extends State<LeadFormPage> {
  final _formKey = GlobalKey<FormState>();
  late LeadProvider _leadProvider;

  // ✅ Form Controllers (UPDATED with new fields)
  late TextEditingController _customerNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _contactEmailController;
  late TextEditingController _contactPersonController;  // NEW
  late TextEditingController _alternatePhoneController;  // NEW
  late TextEditingController _companyNameController;
  late TextEditingController _gstinController;
  late TextEditingController _panController;
  late TextEditingController _serviceAddressController;
  late TextEditingController _serviceCityController;
  late TextEditingController _serviceStateController;
  late TextEditingController _servicePincodeController;
  late TextEditingController _landmarkController;
  late TextEditingController _bandwidthRequiredController;
  late TextEditingController _serviceTypeController;  // NEW
  late TextEditingController _planInterestController;
  late TextEditingController _numberOfConnectionsController;  // NEW
  late TextEditingController _estimatedValueController;
  late TextEditingController _remarksController;  // NEW
  late TextEditingController _internalNotesController;  // NEW

  // Add these new controllers after existing ones:
  late TextEditingController _currentCustomersController;  // NEW: For Partner
  late TextEditingController _expectedCustomersController; // NEW: For Partner


  // ✅ Form State
  String _selectedCustomerType = 'leased_line';
  late ConnectionType _selectedConnectionType;
  late Priority _selectedPriority;
  LeadSource? _selectedLeadSource;  // NEW

  DateTime? _expectedClosureDate;  // NEW

  // ✅ UPDATED: Check if service location is locked due to feasibility
  bool get _isServiceLocationLocked {
    if (widget.feasibilityStatus == null) return false;

    final status = widget.feasibilityStatus!['status'] as String?;

    // Lock location if feasibility is pending, under_review, awaiting_approval, approved, OR rejected
    return status == 'pending' ||
        status == 'under_review' ||
        status == 'awaiting_approval' ||
        status == 'approved' ||
        status == 'rejected'; // ✅ ADDED rejected
  }

  String get _locationLockReason {
    if (widget.feasibilityStatus == null) return '';

    final status = widget.feasibilityStatus!['status'] as String?;
    final requestNumber = widget.feasibilityStatus!['requestNumber'] as String?;
    final requestNumberText = requestNumber != null ? ' (#$requestNumber)' : '';

    switch (status) {
      case 'pending':
        return 'Service location is locked. Cancel feasibility request$requestNumberText to edit location.';
      case 'under_review':
        return 'Service location is locked. Feasibility request$requestNumberText is under technical review.';
      case 'awaiting_approval':
        return 'Service location is locked. Feasibility request$requestNumberText is awaiting approval.';
      case 'approved':
        return 'Service location is locked. Feasibility request$requestNumberText has been approved.'; // ✅ ADDED
      case 'rejected':
        return 'Service location is locked. Feasibility request$requestNumberText was rejected. Submit new request to change location.'; // ✅ ADDED
      default:
        return '';
    }
  }

  // ✅ NEW: Get allowed customer types based on department
  List<Map<String, String>> get _allowedCustomerTypes {
    final departmentId = AppState().departmentId;

    if (departmentId == null) {
      // If no department, show all (fallback)
      return const [
        {'value': 'leased_line', 'label': 'Leased Line'},
        {'value': 'partner', 'label': 'Partner'},
        {'value': 'bandwidth', 'label': 'Bandwidth'},
      ];
    }

    // Department 202, 203: Only Leased Line & Bandwidth
    if (departmentId == 202 || departmentId == 2013) {
      return const [
        {'value': 'leased_line', 'label': 'Leased Line'},
        {'value': 'bandwidth', 'label': 'Bandwidth'},
      ];
    }

    // Department 2011, 2012: Only Partner
    if (departmentId == 2011 || departmentId == 2012 || departmentId == 104) {
      return const [
        {'value': 'partner', 'label': 'Partner'},
      ];
    }

    // Department 1, 20, 201: All types
    if (departmentId == 1 || departmentId == 20 || departmentId == 201) {
      return const [
        {'value': 'leased_line', 'label': 'Leased Line'},
        {'value': 'partner', 'label': 'Partner'},
        {'value': 'bandwidth', 'label': 'Bandwidth'},
      ];
    }

    // Default: show all (for any other departments)
    return const [
      {'value': 'leased_line', 'label': 'Leased Line'},
      {'value': 'partner', 'label': 'Partner'},
      {'value': 'bandwidth', 'label': 'Bandwidth'},
    ];
  }

  // ✅ NEW: Check if current selection is allowed
  bool get _isCurrentTypeAllowed {
    return _allowedCustomerTypes.any((type) => type['value'] == _selectedCustomerType);
  }


  @override
  void initState() {
    super.initState();
    _leadProvider = Provider.of<LeadProvider>(context, listen: false);
    _initializeControllers();
  }

  void _initializeControllers() {
    final lead = widget.leadToEdit;

    // Existing controllers
    _customerNameController = TextEditingController(text: lead?.customerName ?? '');
    _contactPhoneController = TextEditingController(text: lead?.contactPhone ?? '');
    _contactEmailController = TextEditingController(text: lead?.contactEmail ?? '');
    _companyNameController = TextEditingController(text: lead?.companyName ?? '');
    _gstinController = TextEditingController(text: lead?.gstin ?? '');
    _panController = TextEditingController(text: lead?.pan ?? '');
    _serviceAddressController = TextEditingController(text: lead?.serviceAddress ?? '');
    _serviceCityController = TextEditingController(text: lead?.serviceCity ?? '');
    _serviceStateController = TextEditingController(text: lead?.serviceState ?? '');
    _servicePincodeController = TextEditingController(text: lead?.servicePincode ?? '');
    _landmarkController = TextEditingController(text: lead?.landmark ?? '');
    _bandwidthRequiredController = TextEditingController(text: lead?.bandwidthRequired ?? '');
    _planInterestController = TextEditingController(text: lead?.planInterest ?? '');
    _estimatedValueController = TextEditingController(
      text: lead?.estimatedValue?.toString() ?? '',
    );

    // ✅ NEW: Initialize new controllers
    _contactPersonController = TextEditingController(text: lead?.contactPerson ?? '');
    _alternatePhoneController = TextEditingController(text: lead?.alternatePhone ?? '');
    _serviceTypeController = TextEditingController(text: lead?.serviceType ?? '');
    _numberOfConnectionsController = TextEditingController(
      text: lead?.numberOfConnections.toString() ?? '1',
    );

    _remarksController = TextEditingController(text: lead?.remarks ?? '');
    _internalNotesController = TextEditingController(text: lead?.internalNotes ?? '');

    // ✅ NEW: Initialize partner-specific controllers
    _currentCustomersController = TextEditingController(
      text: lead?.currentCustomers?.toString() ?? '',
    );
    _expectedCustomersController = TextEditingController(
      text: lead?.expectedCustomers?.toString() ?? '',
    );

    // ✅ UPDATED: Initialize state with department-based validation
    if (lead != null) {
      // When editing, convert enum to string for dropdown
      final typeFromLead = _getStringFromCustomerType(lead.customerType);

      // ✅ Check if the lead's type is allowed for current department
      final isAllowed = _allowedCustomerTypes.any((type) => type['value'] == typeFromLead);

      if (isAllowed) {
        _selectedCustomerType = typeFromLead;
      } else {
        // Set to first allowed type if current type not allowed
        _selectedCustomerType = _allowedCustomerTypes.first['value']!;

        // ✅ Optional: Show warning that customer type was changed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Customer type changed to ${_allowedCustomerTypes.first['label']} (your department doesn\'t have access to the original type)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange.shade700,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        });
      }
    } else {
      // ✅ New lead - default to first allowed type for department
      _selectedCustomerType = _allowedCustomerTypes.first['value']!;
    }

    _selectedConnectionType = lead?.connectionType ?? ConnectionType.fiber;
    _selectedPriority = lead?.priority ?? Priority.medium;
    _selectedLeadSource = lead?.leadSource;
    _expectedClosureDate = lead?.expectedClosureDate;
  }


  @override
  void dispose() {
    // Existing controllers
    _customerNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _companyNameController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _serviceAddressController.dispose();
    _serviceCityController.dispose();
    _serviceStateController.dispose();
    _servicePincodeController.dispose();
    _landmarkController.dispose();
    _bandwidthRequiredController.dispose();
    _planInterestController.dispose();
    _estimatedValueController.dispose();

    // ✅ NEW: Dispose new controllers
    _contactPersonController.dispose();
    _alternatePhoneController.dispose();
    _serviceTypeController.dispose();
    _numberOfConnectionsController.dispose();
    _remarksController.dispose();
    _internalNotesController.dispose();

    // ✅ NEW: Dispose partner controllers
    _currentCustomersController.dispose();
    _expectedCustomersController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.leadToEdit != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Lead' : 'Create New Lead',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white70,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppState().appBarGradient,
          ),
        ),
      ),
      body: Column(
        children: [
          // ✅ NEW: Show warning banner if service location is locked
          if (_isServiceLocationLocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service Location Locked',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _locationLockReason,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ✅ Existing form wrapped in Expanded
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppState().bodyGradient,
                ),
                child: Consumer<LeadProvider>(
                  builder: (context, provider, _) {
                    return SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // =====================================================
                              // Customer Information Section
                              // =====================================================
                              _buildSectionHeader('Customer Information'),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _customerNameController,
                                label: 'Customer Name',
                                hint: 'Enter customer name',
                                maxLength: 50,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter customer name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // ✅ UPDATED: Customer Type Dropdown with Department-based filtering
                              DropdownButtonFormField<String>(
                                value: _selectedCustomerType,
                                decoration: InputDecoration(
                                  labelText: 'Customer Type',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                items: _allowedCustomerTypes // ✅ Use filtered list
                                    .map((type) => DropdownMenuItem(
                                  value: type['value'],
                                  child: Text(type['label']!),
                                ))
                                    .toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() => _selectedCustomerType = newValue);
                                  }
                                },
                              ),


                              const SizedBox(height: 12),

                              // ✅ UPDATED: Helper text showing department restrictions
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _getHelperColor().withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getHelperColor().withOpacity(0.3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _getHelperIcon(),
                                      size: 20,
                                      color: _getHelperColor(),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getHelperText(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _getHelperColor().withOpacity(0.9),
                                              height: 1.4,
                                            ),
                                          ),
                                          // ✅ Show restriction info if not all types available
                                          if (_allowedCustomerTypes.length < 3) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Your department has access to ${_allowedCustomerTypes.length} customer type(s).',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),


                              // ✅ NEW: Contact Person
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _contactPersonController,
                                label: 'Contact Person',
                                hint: 'Name of person to contact (optional)',
                                maxLength: 50,
                              ),

                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _contactPhoneController,
                                label: 'Contact Phone',
                                hint: '10-digit phone number',
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter phone number';
                                  }
                                  if (value!.length != 10) {
                                    return 'Phone must be 10 digits';
                                  }
                                  return null;
                                },
                              ),

                              // ✅ NEW: Alternate Phone
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _alternatePhoneController,
                                label: 'Alternate Phone',
                                hint: '10-digit alternate number (optional)',
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (value.length != 10) {
                                      return 'Phone must be 10 digits';
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Phone must contain only digits';
                                    }
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _contactEmailController,
                                label: 'Contact Email',
                                hint: 'email@example.com',
                                keyboardType: TextInputType.emailAddress,
                                maxLength: 100,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _companyNameController,
                                label: 'Company Name',
                                hint: 'Optional',
                                maxLength: 150,
                              ),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _gstinController,
                                label: 'GSTIN',
                                hint: 'Optional (15 characters)',
                                maxLength: 15,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (value.length != 15) {
                                      return 'GSTIN must be 15 characters';
                                    }
                                    final gstinRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
                                    if (!gstinRegex.hasMatch(value)) {
                                      return 'Invalid GSTIN format';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _panController,
                                label: 'PAN',
                                hint: 'Optional (10 characters)',
                                maxLength: 10,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty) {
                                    if (value.length != 10) {
                                      return 'PAN must be 10 characters';
                                    }
                                    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                                    if (!panRegex.hasMatch(value)) {
                                      return 'Invalid PAN format';
                                    }
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // =====================================================
                              // ✅ UPDATED: Location Section with Lock Support
                              // =====================================================
                              _buildSectionHeader('Service Location'),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _serviceAddressController,
                                enabled: !_isServiceLocationLocked, // ✅ Lock if needed
                                decoration: InputDecoration(
                                  labelText: 'Service Address',
                                  hintText: 'Full address',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: _isServiceLocationLocked,
                                  fillColor: _isServiceLocationLocked ? Colors.grey.shade100 : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  counterText: '',
                                  suffixIcon: _isServiceLocationLocked
                                      ? Icon(Icons.lock, size: 18, color: Colors.orange.shade700)
                                      : null,
                                ),
                                minLines: 2,
                                maxLines: 5,
                                maxLength: 200,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter service address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _serviceCityController,
                                enabled: !_isServiceLocationLocked, // ✅ Lock if needed
                                decoration: InputDecoration(
                                  labelText: 'City',
                                  hintText: 'Service city',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: _isServiceLocationLocked,
                                  fillColor: _isServiceLocationLocked ? Colors.grey.shade100 : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  counterText: '',
                                  suffixIcon: _isServiceLocationLocked
                                      ? Icon(Icons.lock, size: 18, color: Colors.orange.shade700)
                                      : null,
                                ),
                                maxLength: 50,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter city';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _serviceStateController,
                                enabled: !_isServiceLocationLocked, // ✅ Lock if needed
                                decoration: InputDecoration(
                                  labelText: 'State',
                                  hintText: 'Service state',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: _isServiceLocationLocked,
                                  fillColor: _isServiceLocationLocked ? Colors.grey.shade100 : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  counterText: '',
                                  suffixIcon: _isServiceLocationLocked
                                      ? Icon(Icons.lock, size: 18, color: Colors.orange.shade700)
                                      : null,
                                ),
                                maxLength: 20,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter state';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _servicePincodeController,
                                enabled: !_isServiceLocationLocked, // ✅ Lock if needed
                                decoration: InputDecoration(
                                  labelText: 'Pincode',
                                  hintText: '6-digit pincode',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: _isServiceLocationLocked,
                                  fillColor: _isServiceLocationLocked ? Colors.grey.shade100 : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  counterText: '',
                                  suffixIcon: _isServiceLocationLocked
                                      ? Icon(Icons.lock, size: 18, color: Colors.orange.shade700)
                                      : null,
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter pincode';
                                  }
                                  if (value!.length != 6) {
                                    return 'Pincode must be 6 digits';
                                  }
                                  if (int.tryParse(value) == null) {
                                    return 'Pincode must contain only digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _landmarkController,
                                enabled: !_isServiceLocationLocked, // ✅ Lock if needed
                                decoration: InputDecoration(
                                  labelText: 'Landmark',
                                  hintText: 'Optional',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: _isServiceLocationLocked,
                                  fillColor: _isServiceLocationLocked ? Colors.grey.shade100 : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  counterText: '',
                                  suffixIcon: _isServiceLocationLocked
                                      ? Icon(Icons.lock, size: 18, color: Colors.orange.shade700)
                                      : null,
                                ),
                                maxLength: 100,
                              ),

                              const SizedBox(height: 24),

                              // =====================================================
                              // Service Requirements Section
                              // =====================================================
                              _buildSectionHeader('Service Requirements'),
                              const SizedBox(height: 12),

                              // For Partner: Show customer count fields
                              if (_selectedCustomerType == 'partner') ...[
                                _buildTextFormField(
                                  controller: _currentCustomersController,
                                  label: 'Current Customers (Estimate)',
                                  hint: 'Approximate number of existing customers',
                                  keyboardType: TextInputType.number,
                                  maxLength: 10,
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      final num = int.tryParse(value);
                                      if (num == null || num < 0) {
                                        return 'Must be a positive number';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildTextFormField(
                                  controller: _expectedCustomersController,
                                  label: 'Expected Customers *',
                                  hint: 'Expected customers from this partner',
                                  keyboardType: TextInputType.number,
                                  maxLength: 10,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Please enter expected customers';
                                    }
                                    final num = int.tryParse(value!);
                                    if (num == null || num <= 0) {
                                      return 'Must be a positive number';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // ✅ UPDATED: Bandwidth type - Show only bandwidth field
                              if (_selectedCustomerType == 'bandwidth') ...[
                                _buildTextFormField(
                                  controller: _bandwidthRequiredController,
                                  label: 'Bandwidth Required *',
                                  hint: 'e.g., 1 Gbps, 10 Gbps',
                                  maxLength: 20,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Please enter bandwidth';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // ✅ UPDATED: Leased Line type - Show all fields
                              if (_selectedCustomerType == 'leased_line') ...[
                                _buildTextFormField(
                                  controller: _bandwidthRequiredController,
                                  label: 'Bandwidth Required *',
                                  hint: 'e.g., 100 Mbps, 1 Gbps',
                                  maxLength: 20,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Please enter bandwidth';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildTextFormField(
                                  controller: _planInterestController,
                                  label: 'Plan Interest',
                                  hint: 'e.g., Standard Plan, Premium Plan',
                                  maxLength: 50,
                                ),
                                const SizedBox(height: 12),
                                _buildTextFormField(
                                  controller: _numberOfConnectionsController,
                                  label: 'Number of Connections',
                                  hint: '1',
                                  maxLength: 5,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Please enter number of connections';
                                    }
                                    final num = int.tryParse(value!);
                                    if (num == null || num <= 0) {
                                      return 'Must be at least 1';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              const SizedBox(height: 24),

                              // =====================================================
                              // Commercial Details Section
                              // =====================================================
                              _buildSectionHeader('Commercial Details'),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _estimatedValueController,
                                label: 'Estimated Value (₹)',
                                hint: 'Enter estimated value',
                                maxLength: 10,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter estimated value';
                                  }
                                  final num = double.tryParse(value.trim());
                                  if (num == null || num <= 0) {
                                    return 'Enter a valid amount';
                                  }
                                  return null;
                                },
                              ),

                              // ✅ NEW: Expected Closure Date
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _selectExpectedClosureDate,
                                child: AbsorbPointer(
                                  child: _buildTextFormField(
                                    controller: TextEditingController(
                                      text: _expectedClosureDate != null
                                          ? '${_expectedClosureDate!.day}/${_expectedClosureDate!.month}/${_expectedClosureDate!.year}'
                                          : '',
                                    ),
                                    label: 'Expected Closure Date',
                                    hint: 'Tap to select date (optional)',
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              _buildDropdownField(
                                label: 'Priority',
                                value: _selectedPriority,
                                items: Priority.values,
                                onChanged: (value) {
                                  setState(() => _selectedPriority = value);
                                },
                              ),

                              const SizedBox(height: 24),

                              // =====================================================
                              // ✅ NEW: Lead Source & Tracking Section
                              // =====================================================
                              _buildSectionHeader('Lead Source & Tracking'),
                              const SizedBox(height: 12),
                              _buildDropdownField(
                                label: 'Lead Source',
                                value: _selectedLeadSource ?? LeadSource.walkIn,
                                items: LeadSource.values,
                                onChanged: (value) {
                                  setState(() => _selectedLeadSource = value);
                                },
                              ),

                              const SizedBox(height: 24),

                              // =====================================================
                              // ✅ NEW: Notes Section
                              // =====================================================
                              _buildSectionHeader('Notes'),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _remarksController,
                                label: 'Remarks',
                                hint: 'General notes or comments (optional)',
                                minLines: 3,
                                maxLength: 500,
                              ),
                              const SizedBox(height: 12),
                              _buildTextFormField(
                                controller: _internalNotesController,
                                label: 'Internal Notes',
                                hint: 'Private notes (optional)',
                                minLines: 3,
                                maxLength: 1000,
                              ),

                              const SizedBox(height: 32),

                              // =====================================================
                              // Action Buttons
                              // =====================================================
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: provider.isLoading
                                      ? null
                                      : () => _submitForm(context, isEditing),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey.shade400,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: provider.isLoading
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                      : Text(
                                    isEditing ? 'Update Lead' : 'Create Lead',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),

    );
  }


  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    int? maxLength, // ✅ ADD: Character limit parameter
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        counterText: '', // ✅ Hide counter
      ),
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: minLines > 1 ? 5 : 1,
      maxLength: maxLength, // ✅ Apply limit
      validator: validator,
    );
  }


  Widget _buildDropdownField<T extends Enum>({
    required String label,
    required T value,
    required List<T> items,
    required Function(T) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items.map((item) {
        String label = '';
        if (item is CustomerType) {
          label = (item as CustomerType).label;
        } else if (item is ConnectionType) {
          label = (item as ConnectionType).label;
        } else if (item is Priority) {
          label = (item as Priority).label;
        } else if (item is LeadSource) {
          label = (item as LeadSource).label;
        }
        return DropdownMenuItem<T>(
          value: item,
          child: Text(label),
        );
      }).toList(),
      onChanged: (T? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  // ✅ NEW: Date Picker Method
  Future<void> _selectExpectedClosureDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expectedClosureDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _expectedClosureDate) {
      setState(() {
        _expectedClosureDate = picked;
      });
    }
  }

  // ✅ UPDATED: Helper to convert string to CustomerType enum
  CustomerType _getCustomerTypeFromString(String type) {
    switch (type) {
      case 'partner':
        return CustomerType.enterprise; // Partner
      case 'bandwidth':  // ✅ CHANGED
        return CustomerType.individual; // Bandwidth customers
      case 'leased_line':
        return CustomerType.business;   // Corporate/Large business
      default:
        return CustomerType.individual;
    }
  }

  /// ✅ UPDATED: Convert CustomerType enum to string for dropdown
  String _getStringFromCustomerType(CustomerType? type) {
    if (type == CustomerType.enterprise) return 'partner';
    if (type == CustomerType.individual) return 'bandwidth'; // ✅ CHANGED
    if (type == CustomerType.business) return 'leased_line';
    return 'leased_line'; // default
  }




  Future<void> _submitForm(BuildContext context, bool isEditing) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentUserId = AppState().userId;

    // ✅ CREATE NESTED JSONB OBJECTS

    // 1. Customer Info
    final customerInfo = LeadCustomerInfo(
      name: _customerNameController.text,
      type: _getCustomerTypeFromString(_selectedCustomerType),
      contactPerson: _contactPersonController.text.isEmpty
          ? null
          : _contactPersonController.text,
      phone: _contactPhoneController.text,
      alternatePhone: _alternatePhoneController.text.isEmpty
          ? null
          : _alternatePhoneController.text,
      email: _contactEmailController.text.isEmpty
          ? null
          : _contactEmailController.text,
      companyName: _companyNameController.text.isEmpty
          ? null
          : _companyNameController.text,
      gstin: _gstinController.text.isEmpty
          ? null
          : _gstinController.text,
      pan: _panController.text.isEmpty
          ? null
          : _panController.text,
    );

    // 2. Service Location
    final serviceLocation = LeadServiceLocation(
      address: _serviceAddressController.text,
      city: _serviceCityController.text,
      state: _serviceStateController.text,
      pincode: _servicePincodeController.text,
      latitude: null, // Can be added later with geolocation
      longitude: null,
      landmark: _landmarkController.text.isEmpty
          ? null
          : _landmarkController.text,
    );

    // 3. Service Requirements
    final serviceRequirements = LeadServiceRequirements(
      connectionType: _selectedCustomerType == 'partner'
          ? ConnectionType.partnerNetwork
          : ConnectionType.leasedLine, // ✅ Both SME and leased_line use leasedLine
      bandwidthRequired: _selectedCustomerType != 'partner'
          ? _bandwidthRequiredController.text
          : 'N/A', // Not applicable for partner
      serviceType: _selectedCustomerType == 'partner'
          ? 'Partner Service'
          : null,
      planInterest: _selectedCustomerType != 'partner'
          ? (_planInterestController.text.isEmpty
          ? null
          : _planInterestController.text)
          : null,
      staticIpRequired: false,
      staticIpCount: 0,
      ipv6Required: false,
      numberOfConnections: _selectedCustomerType != 'partner'
          ? (int.tryParse(_numberOfConnectionsController.text) ?? 1)
          : (int.tryParse(_expectedCustomersController.text) ?? 0),
      currentCustomers: _selectedCustomerType == 'partner'
          ? int.tryParse(_currentCustomersController.text)
          : null,
      expectedCustomers: _selectedCustomerType == 'partner'
          ? int.tryParse(_expectedCustomersController.text)
          : null,
    );


    // 4. Commercial Details (simplified - only estimated value)
    LeadCommercialDetails? commercialDetails;
    if (_estimatedValueController.text.isNotEmpty) {
      commercialDetails = LeadCommercialDetails(
        estimatedValue: double.tryParse(_estimatedValueController.text),
      );
    }

    // 5. Lead Tracking (optional)
    LeadTrackingInfo? leadTracking;
    if (_selectedLeadSource != null) {
      leadTracking = LeadTrackingInfo(
        source: _selectedLeadSource,
        sourceDetails: null,
        referralBy: null,
        campaignId: null,
      );
    }

    // 6. Timeline (optional)
    LeadTimeline? timeline;
    if (_expectedClosureDate != null) {
      timeline = LeadTimeline(
        expectedClosureDate: _expectedClosureDate,
        actualClosureDate: null,
        wonDate: null,
        orderDate: null,
        installationType: null,
      );
    }

    // 7. Notes (optional)
    LeadNotes? notes;
    final hasNotes = _remarksController.text.isNotEmpty ||
        _internalNotesController.text.isNotEmpty;

    if (hasNotes) {
      notes = LeadNotes(
        remarks: _remarksController.text.isEmpty
            ? null
            : _remarksController.text,
        internalNotes: _internalNotesController.text.isEmpty
            ? null
            : _internalNotesController.text,
        tags: null,
      );
    }

    // ✅ CREATE SPANCO LEAD WITH NESTED OBJECTS
    final lead = SpancoLead(
      id: widget.leadToEdit?.id,
      leadNumber: widget.leadToEdit?.leadNumber,
      currentStage: widget.leadToEdit?.currentStage ?? SpancoStage.suspect,
      stageUpdatedAt: widget.leadToEdit?.stageUpdatedAt ?? DateTime.now(),
      status: widget.leadToEdit?.status ?? LeadStatus.active,
      priority: _selectedPriority,
      assignedTo: isEditing
          ? widget.leadToEdit?.assignedTo
          : currentUserId,
      assignedAt: isEditing
          ? widget.leadToEdit?.assignedAt
          : DateTime.now(),
      salesTeamId: widget.leadToEdit?.salesTeamId,

      // ✅ NEW: Direct expected closure date column
      expectedClosureDate: _expectedClosureDate,

      // ✅ Pass nested objects
      customerInfo: customerInfo,
      serviceLocation: serviceLocation,
      serviceRequirements: serviceRequirements,
      commercialDetails: commercialDetails,
      leadTracking: leadTracking,
      timeline: timeline,  // ✅ Still pass timeline for backward compatibility
      outcomeDetails: widget.leadToEdit?.outcomeDetails,
      notes: notes,
    );


    // Submit to provider
    if (isEditing) {
      await _leadProvider.updateLead(
        lead.id!,
        lead.toJsonForUpdate(),
      );
    } else {
      await _leadProvider.createLead(lead);
    }

    if (mounted) {
      Navigator.pop(context, true); // ✅ Return true on success
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //       isEditing ? 'Lead updated successfully' : 'Lead created successfully',
      //     ),
      //     backgroundColor: Colors.green,
      //   ),
      // );
    }
  }



  // ✅ UPDATED: Get helper color based on customer type
  Color _getHelperColor() {
    switch (_selectedCustomerType) {
      case 'partner':
        return Colors.purple;
      case 'bandwidth':  // ✅ CHANGED
        return Colors.orange;
      case 'leased_line':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

// ✅ UPDATED: Get helper icon based on customer type
  IconData _getHelperIcon() {
    switch (_selectedCustomerType) {
      case 'partner':
        return Icons.handshake;
      case 'bandwidth':  // ✅ CHANGED
        return Icons.speed;  // or Icons.network_check
      case 'leased_line':
        return Icons.business;
      default:
        return Icons.lightbulb_outline;
    }
  }

// ✅ UPDATED: Get helper text based on customer type
  String _getHelperText() {
    switch (_selectedCustomerType) {
      case 'leased_line':
        return 'Leased Line: For companies, corporate offices, and large businesses';
      case 'partner':
        return 'Partner: For local area internet distribution partners';
      case 'bandwidth':  // ✅ CHANGED
        return 'Bandwidth: For customers who need pure bandwidth to resell or redistribute';
      default:
        return '';
    }
  }





}
