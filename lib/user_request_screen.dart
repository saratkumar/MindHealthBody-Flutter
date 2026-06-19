import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'booking_provider.dart';
import 'gmail_service.dart';
import 'user_registry.dart';
import 'user_request_service.dart';

/// Practitioner-facing form to request a new user (client or practitioner)
/// be added. Notifies all admins by email; an admin must approve it.
class UserRequestScreen extends StatefulWidget {
  const UserRequestScreen({super.key});

  @override
  State<UserRequestScreen> createState() => _UserRequestScreenState();
}

class _UserRequestScreenState extends State<UserRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _role = 'client';
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<BookingProvider>();
    final account = provider.currentAccount as GoogleSignInAccount?;
    final requesterEmail = provider.userEmail;
    if (account == null || requesterEmail == null) {
      _snack('You must be signed in to submit a request', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final admins = await UserRegistryService.getAdmins();

      await UserRequestService.submit(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _role,
        note: _noteCtrl.text.trim(),
        requestedByName: requesterEmail,
        requestedByEmail: requesterEmail,
      );

      if (admins.isNotEmpty) {
        await GmailService.sendUserRequestNotification(
          account: account,
          adminEmails: admins.map((a) => a.email).toList(),
          requesterName: requesterEmail,
          requesterEmail: requesterEmail,
          newUserName: _nameCtrl.text.trim(),
          newUserEmail: _emailCtrl.text.trim(),
          newUserPhone: _phoneCtrl.text.trim(),
          newUserRole: _role,
          note: _noteCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      _snack(admins.isEmpty
          ? 'Request submitted. No admins are registered yet to notify.'
          : 'Request submitted. Admins have been notified.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _snack('Could not submit request: $e', error: true);
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
      appBar: AppBar(title: const Text('Request New User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submit details for a new client or practitioner. An admin '
                'will review and approve before they can sign in.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Role',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'client', label: Text('Client'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(
                      value: 'practitioner',
                      label: Text('Practitioner'),
                      icon: Icon(Icons.medical_services_outlined)),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note to admin',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
