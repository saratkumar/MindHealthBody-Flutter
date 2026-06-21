import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'booking_provider.dart';
import 'user_registry.dart';

/// Client-facing reservation form. The client freely picks their preferred
/// date and time — no calendar-availability check or slot restriction — and
/// this emails the practitioner directly so they can confirm or adjust.
class AppointmentRequestScreen extends StatefulWidget {
  const AppointmentRequestScreen({super.key});

  @override
  State<AppointmentRequestScreen> createState() => _AppointmentRequestScreenState();
}

class _AppointmentRequestScreenState extends State<AppointmentRequestScreen> {
  List<AppUser> _practitioners = [];
  AppUser? _selectedPractitioner;
  bool _loadingPractitioners = true;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _loadPractitioners();
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
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime? get _preferredStart {
    if (_date == null || _time == null) return null;
    return DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final preferredStart = _preferredStart;
    if (preferredStart == null) {
      _snack('Please pick a preferred date and time', error: true);
      return;
    }
    if (_practitioners.isEmpty) {
      _snack('No practitioners registered. Please contact the admin.', error: true);
      return;
    }
    final practitioner = _selectedPractitioner ?? _practitioners.first;
    if (_practitioners.length > 1 && _selectedPractitioner == null) {
      _snack('Please select a practitioner', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final provider = context.read<BookingProvider>();
      final clientEmail = provider.userEmail ?? '';
      final account = provider.currentAccount as GoogleSignInAccount?;
      final clientName = account?.displayName ?? clientEmail;
      final ok = await provider.reserveAppointment(
        practitionerEmail: practitioner.email,
        practitionerName: practitioner.name,
        clientName: clientName,
        clientEmail: clientEmail,
        clientPhone: '',
        preferredStart: preferredStart,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      if (ok) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Appointment Reserved'),
            content: Text(
              'Your reservation request has been sent to ${practitioner.name} for '
              '${DateFormat('EEE, d MMM yyyy').format(preferredStart)} at '
              '${DateFormat('h:mm a').format(preferredStart)}. '
              'They will contact you to confirm.',
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
      } else {
        _snack(provider.errorMessage ?? 'Could not send reservation', error: true);
      }
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
    final preferredStart = _preferredStart;

    return Scaffold(
      appBar: AppBar(title: const Text('Reserve an Appointment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_loadingPractitioners)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_practitioners.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<AppUser>(
                initialValue: _selectedPractitioner,
                hint: const Text('Choose your practitioner'),
                items: _practitioners
                    .map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.email})')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPractitioner = v),
              ),
            ),
          Text(
            'Pick your preferred date and time. There is no need to check '
            'availability — your practitioner will contact you to confirm.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          _PickerTile(
            icon: Icons.calendar_today_outlined,
            label: 'Preferred date',
            value: _date == null ? 'Choose a date' : DateFormat('EEE, d MMM yyyy').format(_date!),
            onTap: _pickDate,
          ),
          const SizedBox(height: 10),
          _PickerTile(
            icon: Icons.schedule_outlined,
            label: 'Preferred time',
            value: _time == null ? 'Choose a time' : _time!.format(context),
            onTap: _pickTime,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Anything the practitioner should know',
            ),
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
                : Text(
                    preferredStart == null
                        ? 'Reserve Appointment'
                        : 'Reserve ${DateFormat("d MMM, h:mm a").format(preferredStart)}',
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF023047)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
