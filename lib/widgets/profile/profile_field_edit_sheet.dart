import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../models/app_state.dart';
import '../../providers/profile_provider.dart';

class ProfileFieldEditSheet extends StatefulWidget {
  final String fieldKey;    // e.g. 'date_of_birth'
  final String fieldLabel;  // e.g. 'Date of Birth'
  final String currentValue;

  const ProfileFieldEditSheet({
    super.key,
    required this.fieldKey,
    required this.fieldLabel,
    required this.currentValue,
  });

  @override
  State<ProfileFieldEditSheet> createState() =>
      _ProfileFieldEditSheetState();
}

class _ProfileFieldEditSheetState
    extends State<ProfileFieldEditSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _noteCtrl    = TextEditingController();
  late TextEditingController _valueCtrl;

  String  _priority    = 'normal';
  bool    _submitting  = false;
  String? _error;

  // For date_of_birth
  DateTime? _selectedDate;

  // For marital_status
  static const _maritalOptions = [
    'Single', 'Married', 'Divorced', 'Widowed'
  ];
  String? _selectedMarital;

  @override
  void initState() {
    super.initState();
    _valueCtrl = TextEditingController(text: widget.currentValue);
    if (widget.fieldKey == 'marital_status' &&
        widget.currentValue.isNotEmpty) {
      _selectedMarital = widget.currentValue;
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _finalValue {
    switch (widget.fieldKey) {
      case 'date_of_birth':
        return _selectedDate != null
            ? '${_selectedDate!.year}-'
            '${_selectedDate!.month.toString().padLeft(2, '0')}-'
            '${_selectedDate!.day.toString().padLeft(2, '0')}'
            : widget.currentValue;
      case 'marital_status':
        return _selectedMarital ?? widget.currentValue;
      default:
        return _valueCtrl.text.trim();
    }
  }

  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final init = _selectedDate ??
        DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context:      context,
      initialDate:  init,
      firstDate:    DateTime(1950),
      lastDate:     DateTime(now.year - 18, now.month, now.day),
      helpText:     'Select Date of Birth',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final value = _finalValue;
    if (value.isEmpty) {
      setState(() => _error = 'Please enter a value');
      return;
    }
    if (value == widget.currentValue) {
      setState(() => _error = 'No changes made');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final appState = Provider.of<AppState>(context, listen: false);

      await supabase.from('requests').insert({
        'user_id':      appState.userId,
        'request_type': 'profile_update',
        'priority':     _priority,
        'user_note':    _noteCtrl.text.trim().isEmpty
            ? null : _noteCtrl.text.trim(),
        'new_data': {
          'subtype':      'profile_field',    // ← was missing
          'field':        widget.fieldKey,
          'value':        value,
          'field_label':  widget.fieldLabel,
          'old_value':    widget.currentValue ?? '',
        },
      });

      // Refresh pending requests
      final profileProvider =
      Provider.of<ProfileProvider>(context, listen: false);
      await profileProvider
          .fetchPendingDocumentRequests(appState.userId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.fieldLabel} update request submitted'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to submit request. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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

                // Title
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update ${widget.fieldLabel}',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const Text('Submit a change request to admin',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Current value
                if (widget.currentValue.isNotEmpty) ...[
                  Text('Current Value',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(widget.currentValue,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 16),
                ],

                // New value input
                Text('New Value',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                _buildValueInput(),
                const SizedBox(height: 16),

                // Priority
                Text('Priority',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                _buildPrioritySelector(),
                const SizedBox(height: 16),

                // Note
                Text('Note (Optional)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Any additional context...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.blue.shade400, width: 2)),
                  ),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Submit
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(_submitting
                      ? 'Submitting...'
                      : 'Submit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueInput() {
    switch (widget.fieldKey) {

    // ── Date picker ─────────────────────────────────────
      case 'date_of_birth':
        return GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: Colors.blue.shade600),
                const SizedBox(width: 10),
                Text(
                  _selectedDate != null
                      ? '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                      '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                      '${_selectedDate!.year}'
                      : 'Tap to select date',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDate != null
                        ? Colors.black87
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        );

    // ── Dropdown ────────────────────────────────────────
      case 'marital_status':
        return DropdownButtonFormField<String>(
          value: _selectedMarital,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.blue.shade400, width: 2)),
          ),
          hint: const Text('Select marital status'),
          items: _maritalOptions
              .map((o) => DropdownMenuItem(
              value: o, child: Text(o)))
              .toList(),
          onChanged: (v) =>
              setState(() => _selectedMarital = v),
          validator: (v) =>
          v == null ? 'Please select a status' : null,
        );

    // ── Text (address fields) ────────────────────────────
      default:
        return TextFormField(
          controller: _valueCtrl,
          maxLines:
          widget.fieldKey.contains('address') ? 3 : 1,
          decoration: InputDecoration(
            hintText: 'Enter new ${widget.fieldLabel.toLowerCase()}',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.blue.shade400, width: 2)),
          ),
          validator: (v) => v == null || v.trim().isEmpty
              ? 'This field is required'
              : null,
        );
    }
  }

  Widget _buildPrioritySelector() {
    final priorities = [
      ('low',    'Low',    Colors.grey),
      ('normal', 'Normal', Colors.blue),
      ('high',   'High',   Colors.orange),
      ('urgent', 'Urgent', Colors.red),
    ];
    return Row(
      children: priorities.map((p) {
        final isSelected = _priority == p.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _priority = p.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? p.$3.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? p.$3
                      : Colors.grey.shade300,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(p.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? p.$3
                          : Colors.grey.shade500)),
            ),
          ),
        );
      }).toList(),
    );
  }
}