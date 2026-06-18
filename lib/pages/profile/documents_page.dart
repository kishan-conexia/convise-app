import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../models/app_state.dart';
import '../../providers/profile_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/uploads/document_upload_widget.dart';
import '../../widgets/uploads/document_viewer.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final Map<String, String?> _signedUrls = {};

  bool _loadingUrls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState        = Provider.of<AppState>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

      await profileProvider.fetchAll(appState.userId);
      await profileProvider.fetchPendingDocumentRequests(appState.userId);

      if (mounted) _loadSignedUrls();
    });
  }


  Future<void> _loadSignedUrls() async {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final details  = provider.profileDetails;
    if (details == null) return;

    setState(() => _loadingUrls = true);

    final paths = {
      'aadhaar':      details.aadhaarUrl,
      'aadhaar_back': details.aadhaarBackUrl,   // ← add
      'pan':          details.panUrl,
      'passport':     details.passportUrl,
      'cheque':       details.cancelledChequeUrl,
      'passbook':     details.passbookUrl,
    };

    for (final entry in paths.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        try {
          final signed = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(entry.value!, 3600);
          _signedUrls[entry.key] = signed;
        } catch (_) {
          _signedUrls[entry.key] = null;
        }
      }
    }

    setState(() => _loadingUrls = false);
  }

  void _openRequestForm(String documentType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocumentUploadSheet(
        documentType: documentType,
        onSuccess: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('$documentType update request submitted'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfileProvider>(context);
    final details  = provider.profileDetails;
    final pending  = provider.pendingRequests;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          title: const Text('Documents',
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
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
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

            // ── Identity Documents ─────────────────────────
            const _SectionHeader(
                icon: Icons.fingerprint,
                title: 'Identity Documents',
                color: Colors.indigo),
            const SizedBox(height: 12),

            _DocumentCard(
              title: 'Aadhaar Card',
              documentType: 'aadhaar',
              icon: Icons.fingerprint,
              iconColor: Colors.indigo,
              number: details?.aadhaarNumber,
              maskNumber: _maskAadhaar,
              signedUrl: _signedUrls['aadhaar'],
              signedUrlBack: _signedUrls['aadhaar_back'],   // ← add
              loadingUrls: _loadingUrls,
              pendingRequest: pending['aadhaar'],
              onRequestUpdate: _openRequestForm,
            ),

            _DocumentCard(
              title: 'PAN Card',
              documentType: 'pan',
              icon: Icons.credit_card_outlined,
              iconColor: Colors.blue,
              number: details?.panNumber,
              maskNumber: _maskPan,
              signedUrl: _signedUrls['pan'],
              loadingUrls: _loadingUrls,
              pendingRequest: pending['pan'],
              onRequestUpdate: _openRequestForm,
            ),

            _DocumentCard(
              title: 'Passport',
              documentType: 'passport',
              icon: Icons.book_outlined,
              iconColor: Colors.teal,
              number: details?.passportNumber,
              maskNumber: _maskPassport,
              signedUrl: _signedUrls['passport'],
              loadingUrls: _loadingUrls,
              pendingRequest: pending['passport'],
              onRequestUpdate: _openRequestForm,
            ),

            const SizedBox(height: 24),

            // ── Bank Documents ─────────────────────────────────────
            _SectionHeader(
                icon: Icons.account_balance_outlined,
                title: 'Bank Documents',
                color: Colors.green),
            const SizedBox(height: 4),

// ── Hint: only one required ────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Only one bank document is required — either Cancelled Cheque or Bank Passbook.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            _DocumentCard(
              title:                'Cancelled Cheque',
              documentType:         'cheque',
              icon:                 Icons.receipt_long_outlined,
              iconColor:            Colors.green,
              signedUrl:            _signedUrls['cheque'],
              loadingUrls:          _loadingUrls,
              pendingRequest:       pending['cheque'],
              onRequestUpdate:      _openRequestForm,
              otherBankDocUploaded: _signedUrls['passbook'] != null,
              bankDetails:          _signedUrls['cheque'] != null
                  ? details?.bankDetails
                  : null,   // ← just pass the map directly
            ),

            _DocumentCard(
              title:                'Bank Passbook',
              documentType:         'passbook',
              icon:                 Icons.account_balance_outlined,
              iconColor:            Colors.orange,
              signedUrl:            _signedUrls['passbook'],
              loadingUrls:          _loadingUrls,
              pendingRequest:       pending['passbook'],
              onRequestUpdate:      _openRequestForm,
              otherBankDocUploaded: _signedUrls['cheque'] != null,
              bankDetails:          _signedUrls['passbook'] != null
                  ? details?.bankDetails
                  : null,   // ← just pass the map directly
            ),
          ],
        ),
      ),
    );
  }

  String _maskAadhaar(String n) {
    if (n.length < 4) return n;
    return 'XXXX XXXX ${n.substring(n.length - 4)}';
  }

  String _maskPan(String n) {
    if (n.length < 4) return n;
    return '${n.substring(0, 2)}XXXXXXX${n.substring(n.length - 2)}';
  }

  String _maskPassport(String n) {
    if (n.length < 3) return n;
    return '${n.substring(0, 2)}XXXXX${n.substring(n.length - 2)}';
  }
}

// ─────────────────────────────────────────────────────────────
// Upload Bottom Sheet
// ─────────────────────────────────────────────────────────────
class _DocumentUploadSheet extends StatefulWidget {
  final String documentType;
  final VoidCallback onSuccess;

  const _DocumentUploadSheet({
    required this.documentType,
    required this.onSuccess,
  });

  @override
  State<_DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<_DocumentUploadSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();

  // ── Bank detail controllers (cheque & passbook only) ───
  final _accountHolderCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl          = TextEditingController();
  final _bankNameCtrl      = TextEditingController();
  final _branchNameCtrl    = TextEditingController();
  String _accountType      = 'savings';   // dropdown default

  bool get _isBankDoc =>
      widget.documentType == 'cheque' ||
          widget.documentType == 'passbook';

  // ── Single file (non-aadhaar) ──────────────────────────────
  File?   _selectedFile;
  String? _selectedFileName;

  // ── Aadhaar dual files ─────────────────────────────────────
  File?   _selectedFront;
  String? _selectedFrontName;
  File?   _selectedBack;
  String? _selectedBackName;

  bool    _uploading = false;
  String? _error;

  bool get _isAadhaar => widget.documentType == 'aadhaar';

  // Documents that require a number field
  bool get _hasNumberField =>
      ['aadhaar', 'pan', 'passport'].contains(widget.documentType);

  Map<String, dynamic> get _docConfig => {
    'aadhaar': {
      'title':    'Aadhaar Card',
      'color':    Colors.indigo,
      'icon':     Icons.fingerprint,
      'hasNumber':    true,
      'label':        'Aadhaar Number',
      'hint':         'Enter 12-digit Aadhaar number',
      'mandatory':    true,
      'maxLength':    12,
      'inputType':    TextInputType.number,
      'inputFormatters': [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      'validator': (String? v) {
        if (v == null || v.trim().isEmpty) return 'Aadhaar Number is required';
        if (v.length < 12) return 'Aadhaar Number must be exactly 12 digits';
        return null;
      },
    },
    'pan': {
      'title':    'PAN Card',
      'color':    Colors.blue,
      'icon':     Icons.credit_card_outlined,
      'hasNumber':    true,
      'label':        'PAN Number',
      'hint':         'e.g. ABCDE1234F',
      'mandatory':    true,          // ← was false
      'maxLength':    10,
      'inputType':    TextInputType.text,
      'textCapitalization': TextCapitalization.characters,
      'inputFormatters': [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        LengthLimitingTextInputFormatter(10),
      ],
      'validator': (String? v) {
        if (v == null || v.trim().isEmpty) return 'PAN Number is required';  // ← was optional
        final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
        if (!panRegex.hasMatch(v.trim().toUpperCase())) {
          return 'Enter a valid PAN number (e.g. ABCDE1234F)';
        }
        return null;
      },
    },
    'passport': {
      'title':    'Passport',
      'color':    Colors.teal,
      'icon':     Icons.book_outlined,
      'hasNumber':    true,
      'label':        'Passport Number',
      'hint':         'e.g. A1234567',
      'mandatory':    true,          // ← was false
      'maxLength':    8,
      'inputType':    TextInputType.text,
      'textCapitalization': TextCapitalization.characters,
      'inputFormatters': [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        LengthLimitingTextInputFormatter(8),
      ],
      'validator': (String? v) {
        if (v == null || v.trim().isEmpty) return 'Passport Number is required';  // ← was optional
        if (v.length < 8) return 'Passport number must be 8 characters';
        return null;
      },
    },
    'cheque': {
      'title':    'Cancelled Cheque',
      'color':    Colors.green,
      'icon':     Icons.receipt_long_outlined,
      'hasNumber':    false,
    },
    'passbook': {
      'title':    'Bank Passbook',
      'color':    Colors.orange,
      'icon':     Icons.account_balance_outlined,
      'hasNumber':    false, // bank fields handled separately
    },
  }[widget.documentType]!;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate files
    if (_isAadhaar) {
      if (_selectedFront == null || _selectedBack == null) {
        setState(() => _error =
        'Please select both front and back photos of Aadhaar');
        return;
      }
    } else {
      if (_selectedFile == null) {
        setState(() => _error = 'Please select a document file');
        return;
      }
    }

    setState(() { _uploading = true; _error = null; });

    try {
      final appState        = Provider.of<AppState>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final userId          = appState.userId;

      // Date folder for versioning
      final dateFolder = DateTime.now()
          .toLocal()
          .toIso8601String()
          .split('T')
          .first; // e.g. 2026-03-25

      final newData = <String, dynamic>{
        'document_type': widget.documentType,
      };

      if (_isAadhaar) {
        // ── Upload front ────────────────────────────────────
        final frontExt  = _selectedFrontName!.split('.').last;
        final frontPath =
            '$userId/staging/aadhaar/$dateFolder/front.$frontExt';
        await supabase.storage
            .from('profile-documents')
            .upload(frontPath, _selectedFront!);

        // ── Upload back ─────────────────────────────────────
        final backExt  = _selectedBackName!.split('.').last;
        final backPath =
            '$userId/staging/aadhaar/$dateFolder/back.$backExt';
        await supabase.storage
            .from('profile-documents')
            .upload(backPath, _selectedBack!);

        newData['staging_path_front'] = frontPath;
        newData['staging_path_back']  = backPath;
        newData['date_folder']        = dateFolder;
      } else {
        final ext         = _selectedFileName!.split('.').last;
        final stagingPath =
            '$userId/staging/${widget.documentType}/$dateFolder/document.$ext';
        await supabase.storage
            .from('profile-documents')
            .upload(stagingPath, _selectedFile!);
        newData['staging_path'] = stagingPath;
        newData['date_folder']  = dateFolder;
      }

      // Number field
      if (_hasNumberField && _numberCtrl.text.isNotEmpty) {
        newData['${widget.documentType}_number'] =
            _numberCtrl.text.trim();
      }

      // Bank fields (cheque & passbook)
      if (_isBankDoc) {
        newData['account_holder'] = _accountHolderCtrl.text.trim();
        newData['account_number'] = _accountNumberCtrl.text.trim();
        newData['account_type']   = _accountType;
        newData['ifsc_code']      = _ifscCtrl.text.trim().toUpperCase();
        newData['bank_name']      = _bankNameCtrl.text.trim();
        newData['branch_name']    = _branchNameCtrl.text.trim();
      }

      // Insert request
      await supabase.from('requests').insert({
        'user_id':      userId,
        'request_type': 'profile_update',
        'new_data':     newData,
        'status':       'pending',
      });

      // Refresh pending badge
      await profileProvider.fetchPendingDocumentRequests(userId);

      widget.onSuccess();
    } catch (e) {
      debugPrint('Upload error: $e');
      setState(() => _error = 'Failed to submit request. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final config = _docConfig;
    final color  = config['color'] as Color;
    final title  = config['title'] as String;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Handle ──────────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(config['icon'] as IconData,
                        color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Update $title',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('Request will be reviewed by admin',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Number Field (if applicable) ─────────────────
              if (_hasNumberField) ...[
                Text('${title} Number',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _numberCtrl,
                  keyboardType: _docConfig['inputType'] as TextInputType?,
                  inputFormatters: _docConfig['inputFormatters'] as List<TextInputFormatter>?,
                  maxLength: _docConfig['maxLength'] as int?,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    // labelText: _docConfig['label'] as String?,
                    hintText:  _docConfig['hint']  as String?,
                    // show * for mandatory
                    label: RichText(
                      text: TextSpan(
                        text: _docConfig['label'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        children: _docConfig['mandatory'] == true
                            ? const [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          )
                        ]
                            : [],
                      ),
                    ),
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
                        borderSide: BorderSide(color: color, width: 2)),
                    counterText: '', // hide the maxLength counter
                  ),
                  validator: (v) {
                    final isMandatory = _docConfig['mandatory'] == true;
                    final maxLen      = _docConfig['maxLength'] as int?;

                    if (isMandatory && (v == null || v.trim().isEmpty)) {
                      return '${_docConfig['label']} is required';
                    }
                    if (v != null && v.isNotEmpty && maxLen != null &&
                        v.length < maxLen) {
                      return '${_docConfig['label']} must be exactly $maxLen digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              // ── Bank Detail Fields (cheque & passbook only) ──────────
              if (_isBankDoc) ...[

                // Account Holder
                _buildBankField(
                  controller: _accountHolderCtrl,
                  label:      'Account Holder Name',
                  hint:       'Full name as on bank account',
                  icon:       Icons.person_outlined,
                  validator:  (v) => (v == null || v.trim().isEmpty)
                      ? 'Account holder name is required' : null,
                ),
                const SizedBox(height: 14),

                // Account Number
                _buildBankField(
                  controller:  _accountNumberCtrl,
                  label:       'Account Number',
                  hint:        'Enter your bank account number',
                  icon:        Icons.tag_outlined,
                  inputType:   TextInputType.number,
                  formatters:  [FilteringTextInputFormatter.digitsOnly],
                  validator:   (v) => (v == null || v.trim().isEmpty)
                      ? 'Account number is required' : null,
                ),
                const SizedBox(height: 14),

                // Account Type dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Account Type',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                        children: const [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _accountType,
                      decoration: InputDecoration(
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
                            borderSide: BorderSide(
                                color: _docConfig['color'] as Color, width: 2)),
                        prefixIcon: const Icon(
                            Icons.account_balance_wallet_outlined, size: 18),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'savings', child: Text('Savings')),
                        DropdownMenuItem(value: 'current', child: Text('Current')),
                      ],
                      onChanged: (v) => setState(() => _accountType = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // IFSC Code
                _buildBankField(
                  controller:  _ifscCtrl,
                  label:       'IFSC Code',
                  hint:        'e.g. SBIN0001234',
                  icon:        Icons.code_outlined,
                  inputType:   TextInputType.text,
                  formatters:  [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  capitalize:  TextCapitalization.characters,
                  validator:   (v) {
                    if (v == null || v.trim().isEmpty) return 'IFSC code is required';
                    if (v.trim().length != 11)        return 'IFSC code must be 11 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Bank Name
                _buildBankField(
                  controller: _bankNameCtrl,
                  label:      'Bank Name',
                  hint:       'e.g. State Bank of India',
                  icon:       Icons.account_balance_outlined,
                  validator:  (v) => (v == null || v.trim().isEmpty)
                      ? 'Bank name is required' : null,
                ),
                const SizedBox(height: 14),

                // Branch Name
                _buildBankField(
                  controller: _branchNameCtrl,
                  label:      'Branch Name',
                  hint:       'e.g. Connaught Place, New Delhi',
                  icon:       Icons.location_on_outlined,
                  validator:  (v) => (v == null || v.trim().isEmpty)
                      ? 'Branch name is required' : null,
                ),
                const SizedBox(height: 20),
              ],

              // ── File Upload ───────────────────────────────────────────
              Text('Upload Document',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 8),

              if (_isAadhaar) ...[
                // Front
                Text('Front Side',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                DocumentUploadWidget(
                  label: 'Aadhaar Front',
                  subtitle: 'Photo of front side — JPG or PNG',
                  selectedFile: _selectedFront,
                  accentColor: color,
                  onFilePicked: (file, name) => setState(() {
                    _selectedFront     = file;
                    _selectedFrontName = name;
                    _error             = null;
                  }),
                  onClear: () => setState(() {
                    _selectedFront     = null;
                    _selectedFrontName = null;
                  }),
                ),
                const SizedBox(height: 12),

                // Back
                Text('Back Side',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                DocumentUploadWidget(
                  label: 'Aadhaar Back',
                  subtitle: 'Photo of back side — JPG or PNG',
                  selectedFile: _selectedBack,
                  accentColor: color,
                  onFilePicked: (file, name) => setState(() {
                    _selectedBack     = file;
                    _selectedBackName = name;
                    _error            = null;
                  }),
                  onClear: () => setState(() {
                    _selectedBack     = null;
                    _selectedBackName = null;
                  }),
                ),
              ] else
                DocumentUploadWidget(
                  label: 'Select $title',
                  subtitle: 'PDF, JPG or PNG — max 5MB',
                  selectedFile: _selectedFile,
                  accentColor: color,
                  onFilePicked: (file, name) => setState(() {
                    _selectedFile     = file;
                    _selectedFileName = name;
                    _error            = null;
                  }),
                  onClear: () => setState(() {
                    _selectedFile     = null;
                    _selectedFileName = null;
                  }),
                ),

              // ── Error ─────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Info banner ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.amber.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your document will be uploaded securely and reviewed by admin before updating.',
                        style: TextStyle(
                            color: Colors.amber.shade800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Submit Button ─────────────────────────────────
              ElevatedButton.icon(
                onPressed: _uploading ? null : _submit,
                icon: _uploading
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(_uploading ? 'Submitting...' : 'Submit Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
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
      ),
    );
  }

  Widget _buildBankField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType inputType              = TextInputType.text,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalize        = TextCapitalization.words,
    required String? Function(String?) validator,
  }) {
    final color = _docConfig['color'] as Color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
            children: const [
              TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller:          controller,
          keyboardType:        inputType,
          inputFormatters:     formatters,
          textCapitalization:  capitalize,
          decoration: InputDecoration(
            hintText:   hint,
            prefixIcon: Icon(icon, size: 18),
            filled:     true,
            fillColor:  Colors.grey.shade50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 2)),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Document Card
// ─────────────────────────────────────────────────────────────
class _DocumentCard extends StatefulWidget {
  final String title;
  final String documentType;
  final IconData icon;
  final Color iconColor;
  final String? number;
  final String Function(String)? maskNumber;
  final String? signedUrl;
  final String? signedUrlBack;   // ← add
  final bool loadingUrls;
  final void Function(String documentType) onRequestUpdate;
  final Map<String, dynamic>? pendingRequest;
  final bool otherBankDocUploaded;
  final Map<String, dynamic>? bankDetails;


  const _DocumentCard({
    required this.title,
    required this.documentType,
    required this.icon,
    required this.iconColor,
    this.number,
    this.maskNumber,
    required this.signedUrl,
    this.signedUrlBack,
    required this.loadingUrls,
    required this.pendingRequest,
    required this.onRequestUpdate,
    this.otherBankDocUploaded = false,
    this.bankDetails,
  });

  @override
  State<_DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<_DocumentCard> {
  bool _revealed = false;

  bool get _hasNumber => widget.number != null && widget.number!.isNotEmpty;
  bool get _hasFile   => widget.signedUrl != null && widget.signedUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.6)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Title row ───────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon,
                      color: widget.iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                // ✅ FIXED
                // ✅ Only aadhaar can ever be "Partial"
                _StatusBadge(
                  hasNumber:      _hasNumber,
                  hasFile:        _hasFile,
                  requiresNumber: widget.documentType == 'aadhaar',
                ),
              ],
            ),

            // ── Number row ──────────────────────────────────
            if (_hasNumber) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.tag, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    _revealed
                        ? widget.number!
                        : widget.maskNumber!(widget.number!),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _revealed = !_revealed),
                    child: Icon(
                      _revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.number!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${widget.title} number copied'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Icon(Icons.copy_outlined,
                        size: 18, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],

            // ── Bank details (cheque & passbook) ────────────────
            if (widget.bankDetails != null && _hasFile) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...widget.bankDetails!.entries
                  .where((e) => e.value != null &&
                  e.value.toString().isNotEmpty)   // ← .toString() for dynamic
                  .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(_bankFieldIcon(e.key),
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text('${_bankFieldLabel(e.key)}: ',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                    Expanded(
                      child: Text(
                        e.key == 'account_type'
                            ? _capitalize(e.value.toString())
                            : e.value.toString(),         // ← .toString() for dynamic
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),

            // ── File + Action row ───────────────────────────────────
            Row(
              children: [
                Icon(
                  _hasFile
                      ? Icons.attach_file_outlined
                      : widget.otherBankDocUploaded
                      ? Icons.block_outlined
                      : Icons.upload_file_outlined,
                  size: 16,
                  color: _hasFile
                      ? Colors.green.shade600
                      : widget.otherBankDocUploaded
                      ? Colors.grey.shade400
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  _hasFile
                      ? 'Document uploaded'
                      : widget.otherBankDocUploaded
                      ? 'Not required'
                      : 'No document uploaded',
                  style: TextStyle(
                    fontSize: 13,
                    color: _hasFile
                        ? Colors.green.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                const Spacer(),
                if (widget.loadingUrls)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (widget.pendingRequest != null)
                  _PendingBadge(
                    status:  widget.pendingRequest!['status'],
                    request: widget.pendingRequest!,
                    title:   widget.title,
                  )
                // ── Hide all actions if other bank doc is uploaded ──
                else if (!widget.otherBankDocUploaded) ...[
                    if (_hasFile) ...[
                      _ActionButton(
                        label: 'View',
                        icon:  Icons.open_in_new,
                        color: widget.iconColor,
                        onTap: () {
                          if (widget.documentType == 'aadhaar') {
                            _showAadhaarViewer(context);
                          } else {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => DocumentViewer(
                                url:   widget.signedUrl!,
                                title: widget.title,
                              ),
                            ));
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    _ActionButton(
                      label: _hasFile ? 'Update' : 'Upload',
                      icon:  _hasFile ? Icons.edit_outlined : Icons.upload_outlined,
                      color: widget.iconColor,
                      onTap: () => widget.onRequestUpdate(widget.documentType),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAadhaarViewer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text('Aadhaar Card',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Front
            Text('Front Side',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            _aadhaarImageTile(context, widget.signedUrl, 'Aadhaar Front'),

            const SizedBox(height: 16),

            // Back
            Text('Back Side',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            _aadhaarImageTile(context, widget.signedUrlBack, 'Aadhaar Back'),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aadhaarImageTile(BuildContext context, String? url, String label) {
    if (url == null) {
      return Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.grey.shade400),
        ),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => DocumentViewer(url: url, title: label),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 130,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) =>
          progress == null ? child :
          const SizedBox(height: 130,
              child: Center(child: CircularProgressIndicator())),
          errorBuilder: (_, __, ___) =>
              SizedBox(height: 130,
                  child: Center(child: Icon(Icons.broken_image_outlined,
                      color: Colors.grey.shade400))),
        ),
      ),
    );
  }

  IconData _bankFieldIcon(String key) {
    switch (key) {
      case 'account_holder': return Icons.person_outlined;
      case 'account_number': return Icons.tag_outlined;
      case 'account_type':   return Icons.account_balance_wallet_outlined;
      case 'ifsc_code':      return Icons.code_outlined;
      case 'bank_name':      return Icons.account_balance_outlined;
      case 'branch_name':    return Icons.location_on_outlined;
      default:               return Icons.info_outline;
    }
  }

  String _bankFieldLabel(String key) {
    switch (key) {
      case 'account_holder': return 'Account Holder';
      case 'account_number': return 'Account Number';
      case 'account_type':   return 'Account Type';
      case 'ifsc_code':      return 'IFSC Code';
      case 'bank_name':      return 'Bank Name';
      case 'branch_name':    return 'Branch Name';
      default:               return key;
    }
  }

  String _capitalize(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
}

// ─────────────────────────────────────────────────────────────
// Action Button
// ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool hasNumber;
  final bool hasFile;
  final bool requiresNumber;   // ← add

  const _StatusBadge({
    required this.hasNumber,
    required this.hasFile,
    this.requiresNumber = true, // ← default true (safe for aadhaar/pan/passport)
  });

  @override
  Widget build(BuildContext context) {
    // For docs with no number (cheque, passbook) — complete = file only
    final complete = requiresNumber
        ? (hasNumber && hasFile)
        : hasFile;

    final partial = requiresNumber
        ? (!complete && (hasNumber || hasFile))
        : false;  // no partial state for number-less docs

    final color = complete
        ? Colors.green
        : partial
        ? Colors.orange
        : Colors.grey;

    final label = complete
        ? 'Complete'
        : partial
        ? 'Partial'
        : 'Missing';

    final icon = complete
        ? Icons.check_circle_outline
        : partial
        ? Icons.error_outline
        : Icons.cancel_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final String status;
  final Map<String, dynamic> request;
  final String title;

  const _PendingBadge({
    required this.status,
    required this.request,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isUnderReview = status == 'under_review';
    final color = isUnderReview ? Colors.blue : Colors.orange;
    final label = isUnderReview ? 'Under Review' : 'Pending Review';
    final icon  = isUnderReview ? Icons.manage_search_outlined : Icons.hourglass_top_outlined;

    return GestureDetector(
      onTap: () => _showRequestDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 12, color: color.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  void _showRequestDetails(BuildContext context) async {
    final newData       = Map<String, dynamic>.from(request['new_data'] ?? {});
    final docType       = newData['document_type'] ?? '';
    final number        = newData['${docType}_number'];
    final createdAt     = request['created_at'] as String?;
    final isUnderReview = status == 'under_review';
    final color         = isUnderReview ? Colors.blue : Colors.orange;
    final isAadhaar     = docType == 'aadhaar';

    String formattedDate = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) formattedDate = Formatters.formatDateTimeDetailed(dt);
    }

    // ── Load signed URLs ───────────────────────────────────
    String? signedUrl;
    String? signedUrlFront;
    String? signedUrlBack;

    try {
      if (isAadhaar) {
        final frontPath = newData['staging_path_front'] as String?;
        final backPath  = newData['staging_path_back']  as String?;

        if (frontPath != null && frontPath.isNotEmpty) {
          signedUrlFront = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(frontPath, 3600);
        }
        if (backPath != null && backPath.isNotEmpty) {
          signedUrlBack = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(backPath, 3600);
        }
      } else {
        final staging = newData['staging_path'] as String?;
        if (staging != null && staging.isNotEmpty) {
          signedUrl = await supabase.storage
              .from('profile-documents')
              .createSignedUrl(staging, 3600);
        }
      }
    } catch (e) {
      debugPrint('Signed URL error: $e');
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUnderReview
                        ? Icons.manage_search_outlined
                        : Icons.hourglass_top_outlined,
                    color: color, size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$title Request',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(
                      isUnderReview
                          ? 'Currently being reviewed by admin'
                          : 'Waiting for admin review',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status
            _DetailRow(
              icon: Icons.circle,
              iconColor: color,
              label: 'Status',
              value: isUnderReview ? 'Under Review' : 'Pending',
            ),

            if (formattedDate.isNotEmpty)
              _DetailRow(
                icon: Icons.schedule_outlined,
                iconColor: Colors.grey,
                label: 'Submitted At',
                value: formattedDate,
              ),

            if (number != null && number.toString().isNotEmpty)
              _DetailRow(
                icon: Icons.tag,
                iconColor: Colors.grey,
                label: '${Formatters.capitalizeFirst(docType)} Number',
                value: number.toString(),
              ),

            const SizedBox(height: 16),

            // ── Bank details (cheque & passbook) ────────────────────
            if (docType == 'cheque' || docType == 'passbook') ...[
              if ((newData['account_holder'] ?? '').toString().isNotEmpty)
                _DetailRow(
                  icon: Icons.person_outlined,
                  iconColor: Colors.grey,
                  label: 'Account Holder',
                  value: newData['account_holder'].toString(),
                ),
              if ((newData['account_number'] ?? '').toString().isNotEmpty)
                _DetailRow(
                  icon: Icons.tag_outlined,
                  iconColor: Colors.grey,
                  label: 'Account Number',
                  value: newData['account_number'].toString(),
                ),
              if ((newData['account_type'] ?? '').toString().isNotEmpty)
                _DetailRow(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: Colors.grey,
                  label: 'Account Type',
                  value: Formatters.capitalizeFirst(
                      newData['account_type'].toString()),
                ),
              if ((newData['ifsc_code'] ?? '').toString().isNotEmpty)
                _DetailRow(
                  icon: Icons.code_outlined,
                  iconColor: Colors.grey,
                  label: 'IFSC Code',
                  value: newData['ifsc_code'].toString(),
                ),
              if ((newData['bank_name'] ?? '').toString().isNotEmpty)
                _DetailRow(
                  icon: Icons.account_balance_outlined,
                  iconColor: Colors.grey,
                  label: 'Bank Name',
                  value: newData['bank_name'].toString(),
                ),
              if ((newData['branch_name'] ?? '').toString().isNotEmpty)
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  iconColor: Colors.grey,
                  label: 'Branch Name',
                  value: newData['branch_name'].toString(),
                ),
            ],

            const SizedBox(height: 16),

            // ── File Preview ─────────────────────────────────
            if (isAadhaar) ...[
              if (signedUrlFront != null || signedUrlBack != null) ...[
                if (signedUrlFront != null) ...[
                  Text('Front Side',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  _buildImageThumbnail(context, signedUrlFront,
                      'Aadhaar Front (Pending)', color),
                  const SizedBox(height: 12),
                ],
                if (signedUrlBack != null) ...[
                  Text('Back Side',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  _buildImageThumbnail(context, signedUrlBack,
                      'Aadhaar Back (Pending)', color),
                ],
              ] else
                _buildUnavailableTile(),
            ] else ...[
              if (signedUrl != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentViewer(
                          url:   signedUrl!,
                          title: '$title (Pending)',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Uploaded File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 46),
                  ),
                )
              else
                _buildUnavailableTile(),
            ],

            const SizedBox(height: 16),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You cannot submit a new request until admin reviews this one.',
                      style: TextStyle(
                          color: Colors.amber.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Close
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

// ── Helpers ────────────────────────────────────────────────
  Widget _buildImageThumbnail(
      BuildContext context, String url, String label, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewer(url: url, title: label),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 130,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const SizedBox(
              height: 130,
              child: Center(child: CircularProgressIndicator())),
          errorBuilder: (_, __, ___) => _buildUnavailableTile(),
        ),
      ),
    );
  }

  Widget _buildUnavailableTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.broken_image_outlined,
              color: Colors.grey.shade400, size: 16),
          const SizedBox(width: 8),
          Text('File preview unavailable',
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }


  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────
// Detail Row (used inside bottom sheet)
// ─────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

