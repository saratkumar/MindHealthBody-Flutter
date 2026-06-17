import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'booking_provider.dart';
import 'intake_form.dart';
import 'intake_form_service.dart';

class IntakeFormScreen extends StatefulWidget {
  const IntakeFormScreen({super.key});

  @override
  State<IntakeFormScreen> createState() => _IntakeFormScreenState();
}

class _IntakeFormScreenState extends State<IntakeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _recipientEmailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _concernCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _signatureKey = GlobalKey<SignaturePadState>();
  bool _consentAccepted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _recipientEmailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _occupationCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _concernCtrl.dispose();
    _historyCtrl.dispose();
    _medicationsCtrl.dispose();
    _allergiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    final signature = _signatureKey.currentState;
    if (signature == null || !signature.hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign the intake form')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_consentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the consent declaration')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final form = IntakeForm(
        fullName: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        gender: _genderCtrl.text.trim(),
        occupation: _occupationCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        emergencyContactName: _emergencyNameCtrl.text.trim(),
        emergencyContactPhone: _emergencyPhoneCtrl.text.trim(),
        presentingConcern: _concernCtrl.text.trim(),
        medicalHistory: _historyCtrl.text.trim(),
        medications: _medicationsCtrl.text.trim(),
        allergies: _allergiesCtrl.text.trim(),
        consentAccepted: _consentAccepted,
        signatureBytes: await signature.toImageBytes(),
        submittedAt: DateTime.now(),
      );

      final files = await IntakeFormService.submit(form);
      await IntakeFormService.sendEmail(
        recipientEmail: _recipientEmailCtrl.text.trim(),
        form: form,
        files: files,
      );
      await IntakeFormService.openWord(files.wordPath);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(this.context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Intake form submitted. PDF emailed and Word opened.'),
          backgroundColor: Color(0xFF188038),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(this.context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not submit intake form: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dobCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Intake Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () => context.read<BookingProvider>().signOut(),
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
              _SectionTitle(title: 'Client details'),
              const SizedBox(height: 12),
              _Field(
                controller: _fullNameCtrl,
                label: 'Full name',
                hint: 'Jane Smith',
                validator: _required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _emailCtrl,
                      label: 'Client email',
                      hint: 'jane@example.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: _email,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _phoneCtrl,
                      label: 'Phone',
                      hint: '+60 12 345 6789',
                      keyboardType: TextInputType.phone,
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(context),
                      child: AbsorbPointer(
                        child: _Field(
                          controller: _dobCtrl,
                          label: 'Date of birth',
                          hint: 'dd/MM/yyyy',
                          validator: _required,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _genderCtrl,
                      label: 'Gender',
                      hint: 'Female / Male / Other',
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _occupationCtrl,
                label: 'Occupation',
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _addressCtrl,
                label: 'Address',
                hint: 'Full residential address',
                maxLines: 2,
                validator: _required,
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Emergency contact'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _emergencyNameCtrl,
                      label: 'Name',
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _emergencyPhoneCtrl,
                      label: 'Phone',
                      keyboardType: TextInputType.phone,
                      validator: _required,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Clinical intake'),
              const SizedBox(height: 12),
              _Field(
                controller: _concernCtrl,
                label: 'Presenting concern',
                maxLines: 4,
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _historyCtrl,
                label: 'Relevant medical / mental health history',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _medicationsCtrl,
                label: 'Current medications',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _allergiesCtrl,
                label: 'Allergies',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Submission'),
              const SizedBox(height: 12),
              _Field(
                controller: _recipientEmailCtrl,
                label: 'Email to receive form',
                hint: 'admin@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: _email,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _consentAccepted,
                onChanged: (value) {
                  setState(() => _consentAccepted = value == true);
                },
                title: const Text(
                  'I confirm the information is true and consent to its use for clinical intake and appointment purposes.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              const Text(
                'Digital signature',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SignaturePad(key: _signatureKey),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : () => _submit(context),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit signed intake form'),
              ),
              const SizedBox(height: 8),
              Text(
                'The editable Word copy opens after submission. The generated PDF is emailed to the address above.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!value.contains('@')) return 'Invalid email';
    return null;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A73E8),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];

  bool get hasSignature => _strokes.any((stroke) => stroke.length > 1);

  void _onPanStart(DragStartDetails details) {
    setState(() => _strokes.add([details.localPosition]));
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_strokes.isEmpty) {
        _strokes.add([details.localPosition]);
      } else {
        _strokes.last.add(details.localPosition);
      }
    });
  }

  void clear() {
    setState(() => _strokes.clear());
  }

  Future<Uint8List> toImageBytes() async {
    if (!hasSignature) return Uint8List(0);

    final width = context.size?.width ?? 320;
    final height = context.size?.height ?? 160;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = _SignaturePainter(_strokes);
    painter.paint(canvas, Size(width, height));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();

    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              child: CustomPaint(
                painter: _SignaturePainter(_strokes),
                child: Container(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: clear,
            child: const Text('Clear signature'),
          ),
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
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
