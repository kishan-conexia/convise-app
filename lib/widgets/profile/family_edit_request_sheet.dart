import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../models/app_state.dart';
import '../../providers/profile_provider.dart';

enum FamilyRequestType { field, children, nominees }

class FamilyEditRequestSheet extends StatefulWidget {
  final FamilyRequestType requestType;
  final String? fieldKey;
  final String? fieldLabel;
  final String? currentValue;
  final List<Map<String, dynamic>>? currentList;

  const FamilyEditRequestSheet({
    super.key,
    required this.requestType,
    this.fieldKey,
    this.fieldLabel,
    this.currentValue,
    this.currentList,
  });

  @override
  State<FamilyEditRequestSheet> createState() =>
      _FamilyEditRequestSheetState();
}

class _FamilyEditRequestSheetState
    extends State<FamilyEditRequestSheet> {

  final _formKey   = GlobalKey<FormState>();
  final _noteCtrl  = TextEditingController();
  final _valueCtrl = TextEditingController();

  String  _priority   = 'normal';
  bool    _submitting = false;
  String? _error;

  late List<Map<String, dynamic>> _editableList;

  static const int _maxChildren    = 10;
  static const int _maxInsured     = 2;
  static const int _maxNominees = 5;

  @override
  void initState() {
    super.initState();
    _valueCtrl.text = widget.currentValue ?? '';
    _editableList = (widget.currentList ?? []).map((e) {
      final item = Map<String, dynamic>.from(e);
      // Normalize relation to Title Case to match dropdown items
      if (item['relation'] != null) {
        final r = item['relation'].toString();
        item['relation'] = r[0].toUpperCase() + r.substring(1).toLowerCase();
      }
      return item;
    }).toList();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────

  num get _totalShare => _editableList.fold<num>(
      0, (s, n) => s + (n['share_percentage'] ?? 0));

  num get _remainingShare => 100 - _totalShare;

  bool get _canAddNominee => _totalShare < 100;

  int get _insuredCount =>
      _editableList.where((c) => c['insured'] == true).length;

  Future<DateTime?> _pickDate(
      BuildContext context, {DateTime? initial}) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(2000),
      firstDate:   DateTime(1900),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.blue.shade600,
          ),
        ),
        child: child!,
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Submit ────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      Map<String, dynamic> newData;

      switch (widget.requestType) {
        case FamilyRequestType.field:
          final value = _valueCtrl.text.trim();
          if (value == (widget.currentValue ?? '')) {
            setState(() { _error = 'No changes made'; _submitting = false; });
            return;
          }
          newData = {
            'subtype':     'family_field',
            'field':       widget.fieldKey,
            'value':       value,
            'field_label': widget.fieldLabel,
            'old_value':   widget.currentValue ?? '',
          };

        case FamilyRequestType.children:
          if (_editableList.isEmpty) {
            setState(() { _error = 'Add at least one child'; _submitting = false; });
            return;
          }
          newData = {
            'subtype':   'children',
            'value':     _editableList,
            'old_value': widget.currentList ?? [],
          };

        case FamilyRequestType.nominees:
          if (_editableList.isEmpty) {
            setState(() { _error = 'Add at least one nominee'; _submitting = false; });
            return;
          }
          if (_totalShare != 100) {
            setState(() {
              _error = 'Total share must equal 100% (current: $_totalShare%)';
              _submitting = false;
            });
            return;
          }
          newData = {
            'subtype':   'nominees',
            'value':     _editableList,
            'old_value': widget.currentList ?? [],
          };
      }

      await supabase.from('requests').insert({
        'user_id':      appState.userId,
        'request_type': 'profile_update',
        'priority':     _priority,
        'user_note':    _noteCtrl.text.trim().isEmpty
            ? null : _noteCtrl.text.trim(),
        'new_data':     newData,
      });

      final profileProvider =
      Provider.of<ProfileProvider>(context, listen: false);
      await profileProvider.fetchPendingDocumentRequests(appState.userId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.fieldLabel ?? _subtypeLabel} update request submitted'),
          behavior:        SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade600,
        ));
      }
    } catch (e) {
      setState(() => _error = 'Failed to submit. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _subtypeLabel {
    switch (widget.requestType) {
      case FamilyRequestType.children: return 'Children';
      case FamilyRequestType.nominees: return 'Nominees';
      default: return widget.fieldLabel ?? 'Family';
    }
  }

  // ── Build ─────────────────────────────────────────────────

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
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),

                // Title
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_outlined,
                        color: Colors.orange.shade600, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_subtypeLabel,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        Text('Request an update',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Body by type ────────────────────
                if (widget.requestType == FamilyRequestType.field)
                  _buildFieldInput()
                else if (widget.requestType == FamilyRequestType.children)
                  _buildChildrenEditor()
                else
                  _buildNomineesEditor(),

                // ── Priority ────────────────────────
                const SizedBox(height: 20),
                _buildPriorityRow(),

                // ── Note ────────────────────────────
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add a note for HR (optional)',
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
                            color: Colors.orange.shade400, width: 2)),
                  ),
                ),

                // ── Error ────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13)),
                      ),
                    ]),
                  ),
                ],

                // ── Submit ────────────────────────────
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(
                      _submitting ? 'Submitting...' : 'Submit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
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

  // ── Field input (father/mother/spouse name) ───────────────

  Widget _buildFieldInput() {
    return TextFormField(
      controller: _valueCtrl,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: widget.fieldLabel,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            BorderSide(color: Colors.orange.shade400, width: 2)),
      ),
      validator: (v) =>
      v == null || v.trim().isEmpty ? 'This field is required' : null,
    );
  }

  // ── Children editor ───────────────────────────────────────

  Widget _buildChildrenEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info bar
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(children: [
            Icon(Icons.info_outline,
                size: 15, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            // Expanded(
            //   child: Text(
            //     'Max $_maxChildren children  •  Up to $_maxInsured can be insured under corporate policy',
            //     style: TextStyle(
            //         fontSize: 12, color: Colors.teal.shade800),
            //   ),
            // ),
          ]),
        ),
        const SizedBox(height: 16),

        // Child cards
        ..._editableList.asMap().entries.map((e) =>
            _buildChildCard(e.key)),

        // Add button
        if (_editableList.length < _maxChildren)
          _buildAddButton(
            label: 'Add Child',
            color: Colors.teal,
            icon: Icons.child_care_outlined,
            onTap: () => setState(() => _editableList.add({
              'name':    '',
              'gender':  null,
              'dob':     null,
              'insured': false,
            })),
          ),
      ],
    );
  }

  Widget _buildChildCard(int index) {
    final child     = _editableList[index];
    final isInsured = child['insured'] == true;
    final canInsure = isInsured || _insuredCount < _maxInsured;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.teal.shade100,
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700)),
            ),
            const SizedBox(width: 8),
            Text('Child ${index + 1}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() => _editableList.removeAt(index)),
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade400, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 12),

          // Name
          _buildInputField(
            label: 'Full Name',
            value: child['name'] ?? '',
            icon: Icons.person_outline,
            color: Colors.teal,
            onChanged: (v) => child['name'] = v,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Name is required' : null,
          ),
          const SizedBox(height: 10),

          // Gender
          _buildGenderRow(
            value: child['gender'],
            color: Colors.teal,
            onChanged: (v) => setState(() => child['gender'] = v),
          ),
          const SizedBox(height: 10),

          // DOB — calendar picker
          _buildDatePickerField(
            label: 'Date of Birth',
            value: child['dob'],
            color: Colors.teal,
            onPicked: (v) => setState(() => child['dob'] = v),
          ),
          const SizedBox(height: 12),

          // Insurance toggle
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isInsured
                  ? Colors.green.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isInsured
                      ? Colors.green.shade200
                      : Colors.grey.shade200),
            ),
            child: Row(children: [
              Icon(Icons.health_and_safety_outlined,
                  size: 16,
                  color: isInsured
                      ? Colors.green.shade600
                      : Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Include under corporate insurance',
                  style: TextStyle(
                      fontSize: 13,
                      color: isInsured
                          ? Colors.green.shade700
                          : Colors.grey.shade600),
                ),
              ),
              Switch(
                value: isInsured,
                onChanged: canInsure
                    ? (v) => setState(() => child['insured'] = v)
                    : null,
                activeColor: Colors.green.shade600,
              ),
            ]),
          ),

          // Warning if max insured reached and this child is not insured
          if (!isInsured && !canInsure)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Max $_maxInsured children already selected for insurance',
                style: TextStyle(
                    fontSize: 11, color: Colors.orange.shade700),
              ),
            ),
        ],
      ),
    );
  }

  // ── Nominees editor ───────────────────────────────────────

  Widget _buildNomineesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Share progress bar
        _buildShareBar(),
        const SizedBox(height: 16),

        // Nominee cards
        ..._editableList.asMap().entries.map((e) =>
            _buildNomineeCard(e.key)),

        // Add button — only if remaining share > 0
        // AFTER
        if (_canAddNominee && _editableList.length < _maxNominees)
          _buildAddButton(
            label: 'Add Nominee  ($_remainingShare% remaining)',
            color: Colors.purple,
            icon: Icons.person_add_outlined,
            onTap: () => setState(() => _editableList.add({
              'name':             '',
              'relation':         null,
              'dob':              null,
              'contact':          null,
              'share_percentage': _remainingShare,
            })),
          ),

        // AFTER nominees cards, replace the existing locked info block
        if (!_canAddNominee || _editableList.length >= _maxNominees)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _editableList.length >= _maxNominees
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _editableList.length >= _maxNominees
                    ? Colors.orange.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Row(children: [
              Icon(
                _editableList.length >= _maxNominees
                    ? Icons.group_outlined
                    : Icons.check_circle_outline,
                size: 15,
                color: _editableList.length >= _maxNominees
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                _editableList.length >= _maxNominees
                    ? 'Maximum $_maxNominees nominees allowed'
                    : '100% allocated — no more nominees can be added',
                style: TextStyle(
                  fontSize: 12,
                  color: _editableList.length >= _maxNominees
                      ? Colors.orange.shade800
                      : Colors.green.shade800,
                ),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _buildNomineeCard(int index) {
    final nominee = _editableList[index];
    final share   = (nominee['share_percentage'] ?? 0) as num;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.purple.shade100,
              child: Text('${index + 1}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700)),
            ),
            const SizedBox(width: 8),
            Text('Nominee ${index + 1}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() {
                _editableList.removeAt(index);
                // redistribute remaining if needed
              }),
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade400, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 12),

          // Name
          _buildInputField(
            label: 'Full Name',
            value: nominee['name'] ?? '',
            icon: Icons.person_outline,
            color: Colors.purple,
            onChanged: (v) => nominee['name'] = v,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Name is required' : null,
          ),
          const SizedBox(height: 10),

          // Relation
          _buildRelationDropdown(
            value: nominee['relation'],
            onChanged: (v) => setState(() => nominee['relation'] = v),
          ),
          const SizedBox(height: 10),

          // DOB — calendar picker
          _buildDatePickerField(
            label: 'Date of Birth',
            value: nominee['dob'],
            color: Colors.purple,
            onPicked: (v) => setState(() => nominee['dob'] = v),
          ),
          const SizedBox(height: 10),

          // Contact
          _buildInputField(
            label: 'Contact Number',
            value: nominee['contact'] ?? '',
            icon: Icons.phone_outlined,
            color: Colors.purple,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => nominee['contact'] = v,
          ),
          const SizedBox(height: 12),

          // Share percentage
          _buildShareSlider(index, share),
        ],
      ),
    );
  }

  Widget _buildShareSlider(int index, num currentShare) {
    // Max share this nominee can take = currentShare + remaining
    final maxShare = (currentShare + _remainingShare).clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.pie_chart_outline,
              size: 14, color: Colors.purple.shade600),
          const SizedBox(width: 6),
          Text('Share: ',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
          Text('${currentShare.toInt()}%',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple.shade700)),
          const Spacer(),
          Text('Max: ${maxShare.toInt()}%',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade400)),
        ]),
        Slider(
          value: currentShare.toDouble(),
          min: 1,
          max: maxShare.toDouble(),
          divisions: maxShare.toInt() > 0 ? maxShare.toInt() : 1,
          activeColor: Colors.purple.shade600,
          inactiveColor: Colors.purple.shade100,
          onChanged: (v) => setState(() {
            _editableList[index]['share_percentage'] = v.toInt();
          }),
        ),
      ],
    );
  }

  Widget _buildShareBar() {
    final total   = _totalShare;
    final isValid = total == 100;
    final pct     = (total / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(
            isValid
                ? Icons.check_circle_outline
                : Icons.pie_chart_outline,
            size: 15,
            color: isValid
                ? Colors.green.shade600
                : Colors.purple.shade600,
          ),
          const SizedBox(width: 6),
          Text('Total share allocated: ',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
          Text('${total.toInt()}%',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isValid
                      ? Colors.green.shade700
                      : Colors.purple.shade700)),
          if (!isValid) ...[
            const SizedBox(width: 6),
            Text('(${_remainingShare.toInt()}% remaining)',
                style: TextStyle(
                    fontSize: 12, color: Colors.orange.shade700)),
          ],
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value:           pct,
            minHeight:       8,
            backgroundColor: Colors.purple.shade100,
            valueColor: AlwaysStoppedAnimation(
              isValid ? Colors.green.shade500 : Colors.purple.shade500,
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared sub-widgets ────────────────────────────────────

  Widget _buildInputField({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: color.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: 1.5)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required String? value,
    required Color color,
    required ValueChanged<String> onPicked,
  }) {
    return GestureDetector(
      onTap: () async {
        DateTime? initial;
        if (value != null && value.isNotEmpty) {
          try { initial = DateTime.parse(value); } catch (_) {}
        }
        final picked = await _pickDate(context, initial: initial);
        if (picked != null) onPicked(_formatDate(picked));
      },
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(Icons.cake_outlined,
              size: 18, color: color.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value != null && value.isNotEmpty ? value : label,
              style: TextStyle(
                fontSize: 14,
                color: value != null && value.isNotEmpty
                    ? Colors.black87
                    : Colors.grey.shade500,
              ),
            ),
          ),
          Icon(Icons.calendar_today_outlined,
              size: 16, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }

  Widget _buildGenderRow({
    required String? value,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.wc_outlined, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text('Gender:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ['Male', 'Female', 'Other'].map((g) => ChoiceChip(
              label:    Text(g, style: const TextStyle(fontSize: 12)),
              selected: value == g,
              onSelected: (_) => onChanged(g),
              selectedColor: color.withOpacity(0.15),
              labelStyle: TextStyle(
                  color: value == g ? color : Colors.grey.shade600,
                  fontWeight:
                  value == g ? FontWeight.w600 : FontWeight.normal),
              side: BorderSide(
                  color: value == g
                      ? color.withOpacity(0.4)
                      : Colors.grey.shade200),
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationDropdown({
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    const relations = [
      'Spouse', 'Father', 'Mother', 'Son', 'Daughter',
      'Brother', 'Sister', 'Grandfather', 'Grandmother', 'Other',
    ];
    // If stored value doesn't match any item, treat as null
    final safeValue = relations.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(
        labelText: 'Relation',
        prefixIcon: Icon(Icons.people_outline,
            size: 18, color: Colors.purple.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            BorderSide(color: Colors.purple.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            BorderSide(color: Colors.purple.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: Colors.purple, width: 1.5)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: relations
          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildAddButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withOpacity(0.3), style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ['low', 'normal', 'high', 'urgent'].map((p) {
            final label = p[0].toUpperCase() + p.substring(1);
            return ChoiceChip(
              label: Text(label, style: const TextStyle(fontSize: 12)),
              selected: _priority == p,
              onSelected: (_) => setState(() => _priority = p),
              selectedColor: _priorityColor(p).withOpacity(0.15),
              labelStyle: TextStyle(
                  color: _priority == p
                      ? _priorityColor(p)
                      : Colors.grey.shade600,
                  fontWeight: _priority == p
                      ? FontWeight.w600
                      : FontWeight.normal),
              side: BorderSide(
                  color: _priority == p
                      ? _priorityColor(p).withOpacity(0.4)
                      : Colors.grey.shade200),
              padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent': return Colors.red;
      case 'high':   return Colors.orange;
      case 'low':    return Colors.grey;
      default:       return Colors.blue;
    }
  }
}