import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'booking_provider.dart';
import 'client_registry_service.dart';
import 'intake_form.dart';
import 'intake_form_service.dart';
import 'sheets_service.dart';
import 'user_registry.dart';

enum _ClientIdStatus { idle, checking, found, newClient, signInRequired, error }

class IntakeFormScreen extends StatefulWidget {
  const IntakeFormScreen({super.key});

  @override
  State<IntakeFormScreen> createState() => _IntakeFormScreenState();
}

class _IntakeFormScreenState extends State<IntakeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sig1Key = GlobalKey<SignaturePadState>();
  final _sig2Key = GlobalKey<SignaturePadState>();

  // Personal
  final _nameCtrl = TextEditingController();
  final _nricCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _sex = '';
  final _raceCtrl = TextEditingController();

  // Referral
  bool _refWebSearch = false;
  bool _refDoctor = false;
  final _refDoctorNameCtrl = TextEditingController();
  bool _refFriend = false;
  final _refFriendNameCtrl = TextEditingController();
  bool _refOther = false;
  final _refOtherCtrl = TextEditingController();

  // Medical
  bool? _underGpCare;
  final _gpDetailsCtrl = TextEditingController();
  final _gpDoctorCtrl = TextEditingController();
  bool? _takingMedication;
  final _medicationCtrl = TextEditingController();

  // Goals
  final _goalsCtrl = TextEditingController();

  // History
  bool? _hadHypno;
  final _hypnoCtrl = TextEditingController();
  bool? _hasFears;
  final _fearsCtrl = TextEditingController();

  // Consent
  final _initialsCtrl = TextEditingController();
  final _consentNameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _confNameCtrl = TextEditingController();

  // Practitioner
  List<AppUser> _practitioners = [];
  AppUser? _selectedPractitioner;
  bool _loadingPractitioners = true;

  bool _submitting = false;

  // Client ID (autofilled for returning clients, looked up by email)
  final _emailFocus = FocusNode();
  String? _clientId;
  _ClientIdStatus _clientIdStatus = _ClientIdStatus.idle;

  @override
  void initState() {
    super.initState();
    _loadPractitioners();
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _lookupClientId();
    });
    // Pre-fill email from signed-in user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final email = context.read<BookingProvider>().userEmail ?? '';
      _emailCtrl.text = email;
      _lookupClientId();
    });
  }

  Future<void> _lookupClientId() async {
    final account =
        context.read<BookingProvider>().currentAccount as GoogleSignInAccount?;
    if (account == null) {
      setState(() {
        _clientId = null;
        _clientIdStatus = _ClientIdStatus.signInRequired;
      });
      return;
    }

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    setState(() => _clientIdStatus = _ClientIdStatus.checking);
    try {
      final client = await ClientRegistryService.findByEmail(account, email);
      if (!mounted) return;
      setState(() {
        _clientId = client?.clientId;
        _clientIdStatus =
            client != null ? _ClientIdStatus.found : _ClientIdStatus.newClient;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clientId = null;
        _clientIdStatus = _ClientIdStatus.error;
      });
    }
  }

  Future<void> _loadPractitioners() async {
    final list = await UserRegistryService.getPractitioners();
    if (!mounted) return;
    setState(() {
      _practitioners = list;
      _selectedPractitioner = list.length == 1 ? list.first : null;
      _loadingPractitioners = false;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _nricCtrl, _addressCtrl, _countryCtrl, _postalCtrl, _phoneCtrl,
      _occupationCtrl, _emailCtrl, _dobCtrl, _raceCtrl, _refDoctorNameCtrl,
      _refFriendNameCtrl, _refOtherCtrl, _gpDetailsCtrl, _gpDoctorCtrl,
      _medicationCtrl, _goalsCtrl, _hypnoCtrl, _fearsCtrl, _initialsCtrl,
      _consentNameCtrl, _dateCtrl, _confNameCtrl,
    ]) {
      c.dispose();
    }
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    _dobCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
  }

  Future<void> _submit() async {
    if (_loadingPractitioners) return;
    if (_practitioners.isEmpty) {
      _snack('No practitioners registered. Please contact the admin.', error: true);
      return;
    }
    if (_practitioners.length > 1 && _selectedPractitioner == null) {
      _snack('Please select a practitioner', error: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_underGpCare == null) { _snack('Please answer the GP/Psychiatrist question', error: true); return; }
    if (_takingMedication == null) { _snack('Please answer the medication question', error: true); return; }
    if (_hadHypno == null) { _snack('Please answer the hypnotherapy question', error: true); return; }
    if (_hasFears == null) { _snack('Please answer the fears/phobias question', error: true); return; }

    final sig1 = _sig1Key.currentState;
    final sig2 = _sig2Key.currentState;
    if (sig1 == null || !sig1.hasSignature) {
      _snack('Please sign the consent on page 1', error: true); return;
    }
    if (sig2 == null || !sig2.hasSignature) {
      _snack('Please sign the confidentiality statement on page 2', error: true); return;
    }

    setState(() => _submitting = true);
    try {
      final provider = context.read<BookingProvider>();
      final account = provider.currentAccount as GoogleSignInAccount?;

      // Request Gmail + Sheets scopes directly from button-press context
      if (account != null) await provider.requestApiScopes();

      final practitioner = _selectedPractitioner ?? _practitioners.first;
      final now = DateTime.now();

      // Assign (or look up) the client's permanent MBP ID right at intake,
      // so it's already in the shared registry by the time invoicing happens.
      String? clientId;
      if (account != null) {
        try {
          final client = await ClientRegistryService.findOrCreateClient(
            account,
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            referenceDate: now,
          );
          clientId = client.clientId;
        } catch (_) {}
      }

      final form = IntakeForm(
        patientName: _nameCtrl.text.trim(),
        nricId: _nricCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        occupation: _occupationCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        birthDate: _dobCtrl.text.trim(),
        sex: _sex,
        race: _raceCtrl.text.trim(),
        refWebSearch: _refWebSearch,
        refDoctor: _refDoctor,
        refDoctorName: _refDoctorNameCtrl.text.trim(),
        refFriend: _refFriend,
        refFriendName: _refFriendNameCtrl.text.trim(),
        refOther: _refOther,
        refOtherDetails: _refOtherCtrl.text.trim(),
        underGpCare: _underGpCare == true,
        gpCareDetails: _gpDetailsCtrl.text.trim(),
        gpDoctorName: _gpDoctorCtrl.text.trim(),
        takingMedication: _takingMedication == true,
        medicationDetails: _medicationCtrl.text.trim(),
        psychotherapyGoals: _goalsCtrl.text.trim(),
        hadHypnotherapy: _hadHypno == true,
        hypnotherapyDetails: _hypnoCtrl.text.trim(),
        hasFearsPhobias: _hasFears == true,
        fearsPhobiasDetails: _fearsCtrl.text.trim(),
        initials: _initialsCtrl.text.trim(),
        consentClientName: _consentNameCtrl.text.trim(),
        date: _dateCtrl.text.trim(),
        signatureBytes: await sig1.toImageBytes(),
        confidentialityClientName: _confNameCtrl.text.trim(),
        signature2Bytes: await sig2.toImageBytes(),
        submittedAt: now,
        practitionerEmail: practitioner.email,
        practitionerName: practitioner.name,
      );

      await IntakeFormService.generateAndSend(
        form,
        account: account,
        clientId: clientId,
      );

      // Mark as submitted locally and in Google Sheets (best-effort)
      final email = provider.userEmail ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('intake_submitted_$email', true);
      if (account != null) {
        try {
          await SheetsService.recordIntakeSubmission(
            account: account,
            clientEmail: email,
            date: now,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      final viaMail = account != null;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(viaMail ? 'Form Sent' : 'Form Downloaded'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: viaMail
                ? [
                    const Text('Your intake form has been emailed to:'),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.email_outlined,
                          size: 16, color: Color(0xFF023047)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: SelectableText(
                          practitioner.email,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF023047)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('A copy was also sent to your email.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    if (clientId != null) ...[
                      const SizedBox(height: 10),
                      Text('Your Client ID: $clientId',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ]
                : [
                    const Text('Your intake form PDF has been downloaded.'),
                    const SizedBox(height: 10),
                    Text('Please email it manually to your practitioner:',
                        style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    SelectableText(practitioner.email,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF023047))),
                  ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Could not send form: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Intake Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () async {
              Navigator.of(context).popUntil((r) => r.isFirst);
              await context.read<BookingProvider>().signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header with logo ───────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Image.asset('assets/image2.png', height: 80),
                    const SizedBox(height: 8),
                    const Text(
                      'The MindBody Practice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF023047),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Client Intake Form',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All information is strictly confidential and protected by PDPA',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // ── Practitioner selection ─────────────────────────────────────
              if (_loadingPractitioners)
                const Center(child: CircularProgressIndicator())
              else if (_practitioners.length > 1) ...[
                _sectionTitle('Select Practitioner'),
                const SizedBox(height: 8),
                DropdownButtonFormField<AppUser>(
                  value: _selectedPractitioner,
                  hint: const Text('Choose your practitioner'),
                  items: _practitioners
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.email})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPractitioner = v),
                  validator: (v) => v == null ? 'Please select a practitioner' : null,
                ),
                const SizedBox(height: 20),
              ],

              // ── Personal details ───────────────────────────────────────────
              _sectionTitle('Patient Details'),
              const SizedBox(height: 12),
              if (_clientIdStatus != _ClientIdStatus.idle) ...[
                _ClientIdBadge(clientId: _clientId, status: _clientIdStatus),
                const SizedBox(height: 12),
              ],
              _field(_nameCtrl, 'Patient\'s Name (as per NRIC/Passport)', required: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_nricCtrl, 'NRIC / ID No', required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_raceCtrl, 'Race')),
              ]),
              const SizedBox(height: 10),
              _field(_addressCtrl, 'Address', maxLines: 2, required: true),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(_countryCtrl, 'Country', required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_postalCtrl, 'Postal Code', required: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(_phoneCtrl, 'Phone (Mobile)',
                        keyboard: TextInputType.phone, required: true)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _field(_occupationCtrl, 'Occupation', required: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(_emailCtrl, 'E-mail',
                        keyboard: TextInputType.emailAddress,
                        required: true,
                        focusNode: _emailFocus)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                        child: _field(_dobCtrl, 'Birth Date', required: true)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Sex'),
                      Row(children: [
                        Radio<String>(
                            value: 'M',
                            groupValue: _sex,
                            onChanged: (v) => setState(() => _sex = v!)),
                        const Text('M'),
                        const SizedBox(width: 16),
                        Radio<String>(
                            value: 'F',
                            groupValue: _sex,
                            onChanged: (v) => setState(() => _sex = v!)),
                        const Text('F'),
                      ]),
                    ],
                  ),
                ),
              ]),

              // ── Referral ───────────────────────────────────────────────────
              const SizedBox(height: 20),
              _sectionTitle('How were you referred?'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 0, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                      value: _refWebSearch,
                      onChanged: (v) => setState(() => _refWebSearch = v!)),
                  const Text('Web Search'),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                      value: _refFriend,
                      onChanged: (v) => setState(() => _refFriend = v!)),
                  const Text('Friend'),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                      value: _refDoctor,
                      onChanged: (v) => setState(() => _refDoctor = v!)),
                  const Text('Doctor'),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Checkbox(
                      value: _refOther,
                      onChanged: (v) => setState(() => _refOther = v!)),
                  const Text('Other'),
                ]),
              ]),
              if (_refDoctor) ...[
                const SizedBox(height: 6),
                _field(_refDoctorNameCtrl, 'Doctor\'s Name'),
              ],
              if (_refFriend) ...[
                const SizedBox(height: 6),
                _field(_refFriendNameCtrl, 'Friend\'s Name'),
              ],
              if (_refOther) ...[
                const SizedBox(height: 6),
                _field(_refOtherCtrl, 'Other details'),
              ],

              // ── Medical ────────────────────────────────────────────────────
              const SizedBox(height: 20),
              _sectionTitle('Medical History'),
              const SizedBox(height: 8),
              _yesNoRow(
                'Are you under a GP/Psychiatrist\'s care?',
                _underGpCare,
                (v) => setState(() => _underGpCare = v),
              ),
              if (_underGpCare == true) ...[
                const SizedBox(height: 8),
                _field(_gpDetailsCtrl, 'Please elaborate'),
                const SizedBox(height: 8),
                _field(_gpDoctorCtrl, 'Doctor\'s Name'),
              ],
              const SizedBox(height: 10),
              _yesNoRow(
                'Are you taking medication?',
                _takingMedication,
                (v) => setState(() => _takingMedication = v),
                yesLabel: 'Yes, for:',
              ),
              if (_takingMedication == true) ...[
                const SizedBox(height: 8),
                _field(_medicationCtrl, 'Medication details'),
              ],

              // ── Goals & history ────────────────────────────────────────────
              const SizedBox(height: 20),
              _sectionTitle('Goals & Background'),
              const SizedBox(height: 8),
              _field(_goalsCtrl,
                  'What do you want to accomplish using Psychotherapy?',
                  maxLines: 3, required: true),
              const SizedBox(height: 10),
              _yesNoRow(
                'Have you ever been through hypnotherapy in the past?',
                _hadHypno,
                (v) => setState(() => _hadHypno = v),
              ),
              if (_hadHypno == true) ...[
                const SizedBox(height: 8),
                _field(_hypnoCtrl, 'Please describe'),
              ],
              const SizedBox(height: 10),
              _yesNoRow(
                'Do you have any fears/phobias?',
                _hasFears,
                (v) => setState(() => _hasFears = v),
              ),
              if (_hasFears == true) ...[
                const SizedBox(height: 8),
                _field(_fearsCtrl, 'Please describe'),
              ],

              // ── Contact lenses notice ──────────────────────────────────────
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF023047), width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: Color(0xFFEEF3FB),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF023047)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: const Text(
                        'IF YOU WEAR CONTACT LENSES AND CANNOT COMFORTABLY CLOSE YOUR EYES '
                        'FOR APPROXIMATELY ½ HOUR WITH THEM IN YOUR EYES, PLEASE REMOVE THEM.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF023047),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Page 1 consent ─────────────────────────────────────────────
              const SizedBox(height: 24),
              _sectionTitle('Consent & Fee Agreement (Page 1)'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: const Text(
                  'THE SUCCESS OF PSYCHOLOGICAL INTERVENTION WILL REST ON YOUR PERSISTENCE WITH THE PROCESS '
                  'AND THE RECOMMENDATION OF YOUR MENTAL HEALTH PROFESSIONAL. I DO AGREE TO PAY S\$180 per '
                  'session*/or ___ per session as FEE FOR SERVICES RENDERED. SERVICE FEE WILL BE COLLECTED '
                  'AT THE END OF EACH SESSION.\n\n'
                  'I AGREE TO PAY A \$30.00 CHARGE IF I DO NOT GIVE 24 HOUR NOTICE OF CANCELLATION OF MY '
                  'APPOINTMENT, AND THE FULL PRICE OF THE SESSION FOR A NO CALL / NO SHOW.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                    width: 120,
                    child: _field(_initialsCtrl, 'Please Initial', required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_dateCtrl, 'Date', required: true)),
              ]),
              const SizedBox(height: 10),
              _field(_consentNameCtrl, 'I, (your full name)', required: true),
              const SizedBox(height: 8),
              const Text(
                '…gives permission to the Mental Health Professional (MHP) to work with me on my mental '
                'health condition(s) for the required number of sessions.',
                style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 12),
              _label('Client Signature (Page 1)'),
              const SizedBox(height: 6),
              SignaturePad(key: _sig1Key),

              // ── Page 2 confidentiality ─────────────────────────────────────
              const SizedBox(height: 24),
              _sectionTitle('Confidentiality & Safety Statement (Page 2)'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: const Text(
                  'Your privacy is important to us. All information shared during your sessions will be kept '
                  'strictly confidential and used only to support your care. We will not share your information '
                  'without your written consent, except when required by law, risk of harm, or professional '
                  'supervision.\n\n'
                  'Video recording (without audio) may be in place within the consultation room to minimise '
                  'facial capture. Recordings are deleted within 96 hours unless required for safety or legal '
                  'obligations.\n\n'
                  'By signing below, you acknowledge that you understand and agree to the above.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              _field(_confNameCtrl, 'Client Name (Page 2)', required: true),
              const SizedBox(height: 8),
              _label('Client Signature (Page 2)'),
              const SizedBox(height: 6),
              SignaturePad(key: _sig2Key),

              // ── Submit ─────────────────────────────────────────────────────
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit & Send Form'),
              ),
              const SizedBox(height: 8),
              Text(
                'The form will be emailed to your practitioner and a copy sent to you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF023047)));
  }

  Widget _label(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500));
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    bool required = false,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          maxLines: maxLines,
          keyboardType: keyboard,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }

  Widget _yesNoRow(String question, bool? value, ValueChanged<bool?> onChanged,
      {String yesLabel = 'Yes', String noLabel = 'No'}) {
    return Row(
      children: [
        Expanded(
            child: Text(question, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 8),
        Row(children: [
          Radio<bool>(
              value: true, groupValue: value, onChanged: onChanged),
          Text(yesLabel, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Radio<bool>(
              value: false, groupValue: value, onChanged: onChanged),
          Text(noLabel, style: const TextStyle(fontSize: 13)),
        ]),
      ],
    );
  }
}

// ── Client ID badge ────────────────────────────────────────────────────

class _ClientIdBadge extends StatelessWidget {
  final String? clientId;
  final _ClientIdStatus status;
  const _ClientIdBadge({this.clientId, required this.status});

  String get _message => switch (status) {
        _ClientIdStatus.checking => 'Checking your client ID…',
        _ClientIdStatus.found => 'Client ID: $clientId',
        _ClientIdStatus.newClient =>
          'New client — your ID will be assigned on submission',
        _ClientIdStatus.signInRequired =>
          'Sign in with Google to look up or assign your client ID',
        _ClientIdStatus.error =>
          'Could not check client ID right now — it will still be assigned on submission',
        _ClientIdStatus.idle => '',
      };

  bool get _emphasized => status == _ClientIdStatus.found;

  @override
  Widget build(BuildContext context) {
    final checking = status == _ClientIdStatus.checking;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF023047).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF023047)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: _emphasized ? FontWeight.w700 : FontWeight.w500,
                color: _emphasized ? const Color(0xFF023047) : Colors.grey.shade700,
              ),
            ),
          ),
          if (checking)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

// ── Signature pad ────────────────────────────────────────────────────────────

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];

  bool get hasSignature => _strokes.any((s) => s.length > 1);

  void clear() => setState(() => _strokes.clear());

  Future<Uint8List> toImageBytes() async {
    if (!hasSignature) return Uint8List(0);
    final w = context.size?.width ?? 320;
    final h = context.size?.height ?? 160;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _SignaturePainter(_strokes).paint(canvas, Size(w, h));
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    return data?.buffer.asUint8List() ?? Uint8List(0);
  }

  void _startStroke(DragStartDetails d) =>
      setState(() => _strokes.add([d.localPosition]));

  void _extendStroke(DragUpdateDetails d) => setState(() {
        if (_strokes.isEmpty) {
          _strokes.add([d.localPosition]);
        } else {
          _strokes.last.add(d.localPosition);
        }
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            // Use separate V + H drag recognizers so the child wins the
            // gesture arena against the parent SingleChildScrollView.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: _startStroke,
              onVerticalDragUpdate: _extendStroke,
              onHorizontalDragStart: _startStroke,
              onHorizontalDragUpdate: _extendStroke,
              child: CustomPaint(
                foregroundPainter: _SignaturePainter(_strokes),
                child: Container(color: Colors.white),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
              onPressed: clear, child: const Text('Clear')),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      for (var i = 1; i < stroke.length; i++) {
        canvas.drawLine(stroke[i - 1], stroke[i], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
