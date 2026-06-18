// will use it in future currently direclty handled in the feasibility request table with the need of this one.



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../models/spanco/feasibility_request.dart';
// import '../../providers/feasibility_provider.dart';
//
// class DeptResponsePage extends StatefulWidget {
//   final FeasibilityRequest request;
//   final int departmentId;
//   final String departmentName;
//
//   const DeptResponsePage({
//     Key? key,
//     required this.request,
//     required this.departmentId,
//     required this.departmentName,
//   }) : super(key: key);
//
//   @override
//   State<DeptResponsePage> createState() => _DeptResponsePageState();
// }
//
// class _DeptResponsePageState extends State<DeptResponsePage> {
//   final _formKey = GlobalKey<FormState>();
//   late FeasibilityProvider _feasibilityProvider;
//
//   // Form Controllers
//   final TextEditingController _remarksController = TextEditingController();
//   final TextEditingController _detailedCommentsController =
//   TextEditingController();
//
//   // Department-specific controllers
//   final TextEditingController _itemsAvailableController =
//   TextEditingController();
//   final TextEditingController _itemsUnavailableController =
//   TextEditingController();
//   final TextEditingController _estimatedCostController =
//   TextEditingController();
//   final TextEditingController _estimatedRevenueController =
//   TextEditingController();
//   final TextEditingController _estimatedWorkDaysController =
//   TextEditingController();
//
//   // Form State
//   String _responseStatus = 'pending';
//   bool _isApproved = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _feasibilityProvider =
//         Provider.of<FeasibilityProvider>(context, listen: false);
//     _setInitialResponseStatus();
//   }
//
//   void _setInitialResponseStatus() {
//     // Set appropriate response status based on department
//     switch (widget.departmentName.toLowerCase()) {
//       case 'inventory':
//         _responseStatus = 'available';
//         break;
//       case 'noc':
//         _responseStatus = 'approved';
//         break;
//       case 'feasibility':
//         _responseStatus = 'feasible';
//         break;
//       case 'fieldops':
//         _responseStatus = 'approved';
//         break;
//       case 'finance':
//         _responseStatus = 'approved';
//         break;
//       default:
//         _responseStatus = 'approved';
//     }
//   }
//
//   @override
//   void dispose() {
//     _remarksController.dispose();
//     _detailedCommentsController.dispose();
//     _itemsAvailableController.dispose();
//     _itemsUnavailableController.dispose();
//     _estimatedCostController.dispose();
//     _estimatedRevenueController.dispose();
//     _estimatedWorkDaysController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('${widget.departmentName} Response'),
//       ),
//       body: Consumer<FeasibilityProvider>(
//         builder: (context, provider, _) {
//           return SingleChildScrollView(
//             child: Form(
//               key: _formKey,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Request Information Card
//                     _buildRequestInfoCard(),
//                     const SizedBox(height: 24),
//
//                     // Response Status
//                     _buildSectionHeader('Response Status'),
//                     const SizedBox(height: 12),
//                     _buildResponseStatusSelector(),
//                     const SizedBox(height: 24),
//
//                     // Department-Specific Fields
//                     _buildDepartmentSpecificFields(),
//
//                     // Common Fields
//                     _buildSectionHeader('Comments'),
//                     const SizedBox(height: 12),
//                     _buildTextFormField(
//                       controller: _remarksController,
//                       label: 'Summary Remarks',
//                       hint: 'Brief summary of your decision',
//                       minLines: 2,
//                       validator: (value) {
//                         if (value?.isEmpty ?? true) {
//                           return 'Please provide remarks';
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 12),
//                     _buildTextFormField(
//                       controller: _detailedCommentsController,
//                       label: 'Detailed Comments (Optional)',
//                       hint: 'Additional details and explanations',
//                       minLines: 3,
//                     ),
//                     const SizedBox(height: 32),
//
//                     // Action Buttons
//                     SizedBox(
//                       width: double.infinity,
//                       child: FilledButton(
//                         onPressed:
//                         provider.isLoading ? null : () => _submitResponse(),
//                         child: provider.isLoading
//                             ? const SizedBox(
//                           height: 20,
//                           width: 20,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             valueColor: AlwaysStoppedAnimation<Color>(
//                               Colors.white,
//                             ),
//                           ),
//                         )
//                             : const Text('Submit Response'),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     SizedBox(
//                       width: double.infinity,
//                       child: OutlinedButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: const Text('Cancel'),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildRequestInfoCard() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.blue[50],
//         border: Border.all(color: Colors.blue[200]!),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.info, color: Colors.blue),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Text(
//                   'Request #${widget.request.requestNumber ?? widget.request.id}',
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 16,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           _buildInfoRow('Location', widget.request.serviceCity),
//           _buildInfoRow('Connection', widget.request.connectionType),
//           _buildInfoRow('Bandwidth', widget.request.bandwidthRequired),
//           _buildInfoRow('Urgency', widget.request.urgency.label),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         children: [
//           SizedBox(
//             width: 100,
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSectionHeader(String title) {
//     return Text(
//       title,
//       style: const TextStyle(
//         fontSize: 16,
//         fontWeight: FontWeight.w600,
//       ),
//     );
//   }
//
//   Widget _buildResponseStatusSelector() {
//     final statusOptions = _getStatusOptions();
//
//     return Column(
//       children: statusOptions.map((option) {
//         final isSelected = _responseStatus == option['value'];
//         return Container(
//           margin: const EdgeInsets.only(bottom: 8),
//           decoration: BoxDecoration(
//             border: Border.all(
//               color: isSelected ? _getStatusColor(option['value']!) : Colors.grey[300]!,
//               width: isSelected ? 2 : 1,
//             ),
//             borderRadius: BorderRadius.circular(8),
//             color: isSelected
//                 ? _getStatusColor(option['value']!).withOpacity(0.1)
//                 : null,
//           ),
//           child: RadioListTile<String>(
//             value: option['value']!,
//             groupValue: _responseStatus,
//             onChanged: (value) {
//               setState(() {
//                 _responseStatus = value!;
//                 _isApproved = _isApprovedStatus(value);
//               });
//             },
//             title: Text(
//               option['label']!,
//               style: TextStyle(
//                 fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
//                 color: isSelected ? _getStatusColor(option['value']!) : null,
//               ),
//             ),
//             subtitle: option['description'] != null
//                 ? Text(
//               option['description']!,
//               style: const TextStyle(fontSize: 12),
//             )
//                 : null,
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildDepartmentSpecificFields() {
//     switch (widget.departmentName.toLowerCase()) {
//       case 'inventory':
//         return _buildInventoryFields();
//       case 'noc':
//         return _buildNocFields();
//       case 'feasibility':
//         return _buildFeasibilityFields();
//       case 'fieldops':
//         return _buildFieldOpsFields();
//       case 'finance':
//         return _buildFinanceFields();
//       default:
//         return const SizedBox.shrink();
//     }
//   }
//
//   Widget _buildInventoryFields() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionHeader('Inventory Details'),
//         const SizedBox(height: 12),
//         _buildTextFormField(
//           controller: _itemsAvailableController,
//           label: 'Items Available',
//           hint: 'List of available equipment',
//           minLines: 2,
//         ),
//         const SizedBox(height: 12),
//         _buildTextFormField(
//           controller: _itemsUnavailableController,
//           label: 'Items Unavailable',
//           hint: 'List of unavailable equipment',
//           minLines: 2,
//         ),
//         const SizedBox(height: 24),
//       ],
//     );
//   }
//
//   Widget _buildNocFields() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionHeader('Network Analysis'),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.orange[50],
//             border: Border.all(color: Colors.orange[200]!),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.warning, color: Colors.orange[700]),
//               const SizedBox(width: 12),
//               const Expanded(
//                 child: Text(
//                   'NOC can veto this request. Rejection will stop the entire workflow.',
//                   style: TextStyle(fontSize: 12),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 24),
//       ],
//     );
//   }
//
//   Widget _buildFeasibilityFields() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionHeader('Feasibility Assessment'),
//         const SizedBox(height: 12),
//         _buildTextFormField(
//           controller: _estimatedWorkDaysController,
//           label: 'Estimated Work Days',
//           hint: 'Number of days required',
//           keyboardType: TextInputType.number,
//         ),
//         const SizedBox(height: 24),
//       ],
//     );
//   }
//
//   Widget _buildFieldOpsFields() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionHeader('Field Operations Assessment'),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: Colors.orange[50],
//             border: Border.all(color: Colors.orange[200]!),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Row(
//             children: [
//               Icon(Icons.warning, color: Colors.orange[700]),
//               const SizedBox(width: 12),
//               const Expanded(
//                 child: Text(
//                   'Field Ops can veto this request. Rejection will stop the entire workflow.',
//                   style: TextStyle(fontSize: 12),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 12),
//         _buildTextFormField(
//           controller: _estimatedWorkDaysController,
//           label: 'Estimated Installation Days',
//           hint: 'Number of days required',
//           keyboardType: TextInputType.number,
//         ),
//         const SizedBox(height: 24),
//       ],
//     );
//   }
//
//   Widget _buildFinanceFields() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSectionHeader('Financial Assessment'),
//         const SizedBox(height: 12),
//         _buildTextFormField(
//           controller: _estimatedCostController,
//           label: 'Estimated Cost (₹)',
//           hint: 'Total estimated cost',
//           keyboardType: TextInputType.number,
//         ),
//         const SizedBox(height: 12),
//         _buildTextFormField(
//           controller: _estimatedRevenueController,
//           label: 'Estimated Revenue (₹)',
//           hint: 'Expected revenue',
//           keyboardType: TextInputType.number,
//         ),
//         const SizedBox(height: 24),
//       ],
//     );
//   }
//
//   Widget _buildTextFormField({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     TextInputType keyboardType = TextInputType.text,
//     int minLines = 1,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       decoration: InputDecoration(
//         labelText: label,
//         hintText: hint,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         contentPadding:
//         const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       ),
//       keyboardType: keyboardType,
//       minLines: minLines,
//       maxLines: minLines > 1 ? 5 : 1,
//       validator: validator,
//     );
//   }
//
//   List<Map<String, String>> _getStatusOptions() {
//     switch (widget.departmentName.toLowerCase()) {
//       case 'inventory':
//         return [
//           {
//             'value': 'available',
//             'label': 'Available',
//             'description': 'All required items are in stock'
//           },
//           {
//             'value': 'unavailable',
//             'label': 'Unavailable',
//             'description': 'Some items need to be procured'
//           },
//           {
//             'value': 'conditional',
//             'label': 'Partially Available',
//             'description': 'Some items available, some need procurement'
//           },
//         ];
//       case 'noc':
//       case 'fieldops':
//         return [
//           {
//             'value': 'approved',
//             'label': 'Approved',
//             'description': 'Request is feasible and approved'
//           },
//           {
//             'value': 'rejected',
//             'label': 'Rejected (VETO)',
//             'description': 'Request cannot proceed - stops workflow'
//           },
//           {
//             'value': 'conditional',
//             'label': 'Conditional',
//             'description': 'Approved with specific conditions'
//           },
//         ];
//       case 'feasibility':
//         return [
//           {
//             'value': 'feasible',
//             'label': 'Feasible',
//             'description': 'Technically feasible'
//           },
//           {
//             'value': 'not_feasible',
//             'label': 'Not Feasible',
//             'description': 'Not technically possible'
//           },
//           {
//             'value': 'conditional',
//             'label': 'Conditionally Feasible',
//             'description': 'Feasible with modifications'
//           },
//         ];
//       case 'finance':
//         return [
//           {
//             'value': 'approved',
//             'label': 'Financially Viable',
//             'description': 'Good ROI and profitability'
//           },
//           {
//             'value': 'rejected',
//             'label': 'Not Viable',
//             'description': 'Poor financial returns'
//           },
//           {
//             'value': 'conditional',
//             'label': 'Conditional Approval',
//             'description': 'Viable with pricing adjustments'
//           },
//         ];
//       default:
//         return [
//           {'value': 'approved', 'label': 'Approved'},
//           {'value': 'rejected', 'label': 'Rejected'},
//         ];
//     }
//   }
//
//   bool _isApprovedStatus(String status) {
//     return status == 'approved' ||
//         status == 'available' ||
//         status == 'feasible';
//   }
//
//   Color _getStatusColor(String status) {
//     if (status == 'approved' ||
//         status == 'available' ||
//         status == 'feasible') {
//       return Colors.green;
//     } else if (status == 'rejected' ||
//         status == 'unavailable' ||
//         status == 'not_feasible') {
//       return Colors.red;
//     } else {
//       return Colors.orange;
//     }
//   }
//
//   Future<void> _submitResponse() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//
//     // Build additional data based on department
//     final Map<String, dynamic> additionalData = {};
//
//     switch (widget.departmentName.toLowerCase()) {
//       case 'inventory':
//         if (_itemsAvailableController.text.isNotEmpty) {
//           additionalData['items_available'] = _itemsAvailableController.text;
//         }
//         if (_itemsUnavailableController.text.isNotEmpty) {
//           additionalData['items_unavailable'] =
//               _itemsUnavailableController.text;
//         }
//         break;
//       case 'finance':
//         if (_estimatedCostController.text.isNotEmpty) {
//           additionalData['estimated_cost'] =
//               double.tryParse(_estimatedCostController.text);
//         }
//         if (_estimatedRevenueController.text.isNotEmpty) {
//           additionalData['estimated_revenue'] =
//               double.tryParse(_estimatedRevenueController.text);
//         }
//         break;
//       case 'feasibility':
//       case 'fieldops':
//         if (_estimatedWorkDaysController.text.isNotEmpty) {
//           additionalData['estimated_work_days'] =
//               int.tryParse(_estimatedWorkDaysController.text);
//         }
//         break;
//     }
//
//     final result = await _feasibilityProvider.submitDepartmentResponse(
//       requestId: widget.request.id!,
//       departmentId: widget.departmentId,
//       departmentName: widget.departmentName,
//       responseStatus: _responseStatus,
//       remarks: _remarksController.text,
//       additionalData: additionalData,
//     );
//
//     if (result != null && mounted) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Response submitted successfully!'),
//         ),
//       );
//     }
//   }
// }
