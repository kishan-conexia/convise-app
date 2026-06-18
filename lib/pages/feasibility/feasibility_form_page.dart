// lib/pages/feasibility/feasibility_form_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../models/spanco/feasibility/feasibility_request.dart';
import '../../models/spanco/feasibility/service_location.dart';
import '../../models/spanco/feasibility/service_requirements.dart';
import '../../models/spanco/spanco_lead.dart';
import '../../providers/feasibility_provider.dart';
import '../../main.dart';

class FeasibilityFormPage extends StatefulWidget {
  final SpancoLead lead;

  const FeasibilityFormPage({
    Key? key,
    required this.lead,
  }) : super(key: key);

  @override
  State<FeasibilityFormPage> createState() => _FeasibilityFormPageState();
}

class _FeasibilityFormPageState extends State<FeasibilityFormPage> {
  final _formKey = GlobalKey<FormState>();
  late FeasibilityProvider _feasibilityProvider;

  // Form Controllers
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _landmarkController;
  late TextEditingController _bandwidthController;
  late TextEditingController _specialConditionsController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  // Form State
  String _feasibilityType = 'technical';
  String _serviceType = 'leased_line'; // ✅ NEW: Partner or Leased Line
  String _urgency = 'normal';

  @override
  void initState() {
    super.initState();
    _feasibilityProvider = Provider.of<FeasibilityProvider>(context, listen: false);
    _initializeControllers();
  }

  void _initializeControllers() {
    // Pre-fill from lead data
    _addressController = TextEditingController(text: widget.lead.serviceAddress);
    _cityController = TextEditingController(text: widget.lead.serviceCity);
    _stateController = TextEditingController(text: widget.lead.serviceState);
    _pincodeController = TextEditingController(text: widget.lead.servicePincode);
    _landmarkController = TextEditingController(text: widget.lead.landmark);
    _bandwidthController = TextEditingController(text: widget.lead.bandwidthRequired);
    _specialConditionsController = TextEditingController();

    // Initialize coordinate controllers
    _latitudeController = TextEditingController(
      text: widget.lead.serviceLatitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: widget.lead.serviceLongitude?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _bandwidthController.dispose();
    _specialConditionsController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Request Feasibility',
          style: TextStyle(
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppState().bodyGradient,
          ),
          child: Consumer<FeasibilityProvider>(
            builder: (context, provider, _) {
              return SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lead Information
                        _buildSectionHeader('Lead Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          'Customer: ${widget.lead.customerName}',
                          'Lead #${widget.lead.leadNumber}',
                        ),
                        const SizedBox(height: 24),

                        // Request Type & Urgency
                        _buildSectionHeader('Request Details'),
                        const SizedBox(height: 12),
                        // ✅ UPDATED: Show fixed feasibility type with improved styling
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.blue.shade200, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: Colors.blue.shade700, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Feasibility Type',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Technical',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          label: 'Urgency',
                          value: _urgency,
                          items: const [
                            {'value': 'low', 'label': 'Low'},
                            {'value': 'normal', 'label': 'Normal'},
                            {'value': 'high', 'label': 'High'},
                            {'value': 'urgent', 'label': 'Urgent'},
                          ],
                          onChanged: (value) {
                            setState(() => _urgency = value);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Service Location
                        _buildSectionHeader('Service Location'),
                        const SizedBox(height: 12),
                        _buildTextFormField(
                          controller: _addressController,
                          label: 'Service Address *',
                          hint: 'Full address',
                          minLines: 2,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter service address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _cityController,
                                label: 'City *',
                                hint: 'City',
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Required';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _stateController,
                                label: 'State *',
                                hint: 'State',
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Required';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _pincodeController,
                                label: 'Pincode *',
                                hint: '6-digit pincode',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final v = (value ?? '').trim();
                                  if (v.isEmpty) return 'Required';
                                  final isValid = RegExp(r'^\d{6}$').hasMatch(v);
                                  if (!isValid) return 'Must be 6 digits';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _landmarkController,
                                label: 'Landmark',
                                hint: 'Optional',
                              ),
                            ),
                          ],
                        ),

                        // Coordinate fields
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _latitudeController,
                                label: 'Latitude',
                                hint: 'e.g., 28.7041',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null; // Optional field
                                  }
                                  final lat = double.tryParse(value.trim());
                                  if (lat == null) {
                                    return 'Invalid latitude';
                                  }
                                  if (lat < -90 || lat > 90) {
                                    return 'Must be between -90 and 90';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _longitudeController,
                                label: 'Longitude',
                                hint: 'e.g., 77.1025',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return null; // Optional field
                                  }
                                  final lng = double.tryParse(value.trim());
                                  if (lng == null) {
                                    return 'Invalid longitude';
                                  }
                                  if (lng < -180 || lng > 180) {
                                    return 'Must be between -180 and 180';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        // Helper text for coordinates
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Coordinates help technical team locate service area',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Service Requirements
                        _buildSectionHeader('Service Requirements'),
                        const SizedBox(height: 12),

                        // ✅ Service Type (Partner or Leased Line)
                        _buildDropdownField(
                          label: 'Service Type *',
                          value: _serviceType,
                          items: _getServiceTypeOptions(),
                          onChanged: (value) {
                            setState(() => _serviceType = value);
                          },
                        ),


                        // ✅ Show bandwidth field only for Leased Line and Bandwidth types
                        if (_serviceType == 'leased_line' || _serviceType == 'bandwidth') ...[
                          const SizedBox(height: 12),
                          _buildTextFormField(
                            controller: _bandwidthController,
                            label: 'Bandwidth Required *',
                            hint: _serviceType == 'bandwidth'
                                ? 'e.g., 10 Gbps, 20 Gbps'
                                : 'e.g., 1 Gbps, 500 Mbps',
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Please enter bandwidth';
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Special Conditions
                        _buildSectionHeader('Special Conditions (Optional)'),
                        const SizedBox(height: 12),
                        _buildTextFormField(
                          controller: _specialConditionsController,
                          label: 'Special Conditions or Requirements',
                          hint: 'Any specific requirements from the customer',
                          minLines: 3,
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: provider.isLoading ? null : _submitForm,
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
                                : const Text(
                              'Submit Feasibility Request',
                              style: TextStyle(
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


  Widget _buildInfoCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: minLines > 1 ? minLines + 2 : 1,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required Function(String) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item['value'],
          child: Text(item['label']!),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Get user department
    final appState = Provider.of<AppState>(context, listen: false);
    final departmentId = appState.departmentId;
    if (departmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department not found')),
      );
      return;
    }

    try {
      // ✅ Get accurate server time
      final currentTime = await appState.getCurrentTime();

      // Parse coordinates from text fields
      double? latitude;
      double? longitude;

      final latText = _latitudeController.text.trim();
      final lngText = _longitudeController.text.trim();

      if (latText.isNotEmpty) {
        latitude = double.tryParse(latText);
      }

      if (lngText.isNotEmpty) {
        longitude = double.tryParse(lngText);
      }

      // Create ServiceLocation object
      final serviceLocation = ServiceLocation(
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        landmark: _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        latitude: latitude,
        longitude: longitude,
      );

      // Create ServiceRequirements object
      final serviceRequirements = ServiceRequirements(
        feasibilityType: _feasibilityType,
        connectionType: _serviceType,
        bandwidth: _serviceType == 'leased_line'
            ? _bandwidthController.text.trim()
            : 'N/A',
        staticIpRequired: false,
        staticIpCount: 0,
        ipv6Required: false,
        urgency: _urgency,
        priority: 'normal',
        specialConditions: _specialConditionsController.text.trim().isEmpty
            ? null
            : _specialConditionsController.text.trim(),
      );

      // ✅ UPDATED: Create FeasibilityRequest with server time
      final request = FeasibilityRequest(
        leadId: widget.lead.id!,
        createdAt: currentTime,        // ✅ Use server time
        updatedAt: currentTime,        // ✅ Use server time
        requestedBy: userId,
        requestingDepartment: departmentId,
        requestedAt: currentTime,      // ✅ Use server time
        serviceLocation: serviceLocation,
        serviceRequirements: serviceRequirements,
      );

      // ✅ UPDATED: Handle Map result
      final result = await _feasibilityProvider.createRequest(request);

      if (result != null && mounted) {
        // ✅ Extract values from the map
        final requestNumber = result['requestNumber'] as String;
        final wasReused = result['wasReused'] as bool;

        Navigator.pop(context, true); // Return true to indicate success

        // ✅ Show different message based on whether request was reused
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasReused
                  ? 'Reactivated cancelled request $requestNumber!'
                  : 'Feasibility request $requestNumber submitted successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  // In FeasibilityFormPage class, add this helper method to get available service types
  List<Map<String, String>> _getServiceTypeOptions() {
    final appState = Provider.of<AppState>(context, listen: false);
    final departmentId = appState.departmentId;

    // Partner department (201) - Show only Partner and Leased Line
    if (departmentId == 201) {
      return const [
        {'value': 'partner', 'label': 'Partner'},
        {'value': 'leased_line', 'label': 'Leased Line'},
      ];
    }

    // Other departments (SME/Business/Individual) - Show all options
    return const [
      {'value': 'leased_line', 'label': 'Leased Line'},
      {'value': 'partner', 'label': 'Partner'},
      {'value': 'bandwidth', 'label': 'Bandwidth'},
    ];
  }

// Add helper to get color based on service type
  Color _getServiceTypeHelperColor() {
    switch (_serviceType) {
      case 'partner':
        return Colors.purple;
      case 'bandwidth':
        return Colors.orange;
      case 'leased_line':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

// Add helper to get icon based on service type
  IconData _getServiceTypeHelperIcon() {
    switch (_serviceType) {
      case 'partner':
        return Icons.handshake;
      case 'bandwidth':
        return Icons.speed;
      case 'leased_line':
        return Icons.business;
      default:
        return Icons.lightbulb_outline;
    }
  }

// Add helper to get description text
  String _getServiceTypeHelperText() {
    switch (_serviceType) {
      case 'leased_line':
        return 'Leased Line: For companies, corporate offices, and large businesses';
      case 'partner':
        return 'Partner: For local area internet distribution partners';
      case 'bandwidth':
        return 'Bandwidth: For customers who need pure bandwidth to resell or redistribute';
      default:
        return '';
    }
  }



}
