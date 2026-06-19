import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'booking_provider.dart';
import 'slot_chip.dart';
import 'user_registry.dart';

/// Client-facing slot picker that emails a request to the practitioner.
/// Unlike the practitioner's BookScreen, this never writes to Calendar —
/// the practitioner follows up with the client directly.
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

  @override
  void initState() {
    super.initState();
    _loadPractitioners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadSlots();
    });
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

  Future<void> _submit() async {
    final provider = context.read<BookingProvider>();
    if (provider.selectedSlot == null) {
      _snack('Please pick a time slot', error: true);
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
      final clientEmail = provider.userEmail ?? '';
      final account = provider.currentAccount as GoogleSignInAccount?;
      final clientName = account?.displayName ?? clientEmail;
      final ok = await provider.requestAppointment(
        practitionerEmail: practitioner.email,
        practitionerName: practitioner.name,
        clientName: clientName,
        clientEmail: clientEmail,
        clientPhone: '',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      if (ok) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Request Sent'),
            content: Text(
              'Your appointment request has been sent to ${practitioner.name}. '
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
        _snack(provider.errorMessage ?? 'Could not send request', error: true);
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
    final provider = context.watch<BookingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Request an Appointment')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (_loadingPractitioners)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_practitioners.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: DropdownButtonFormField<AppUser>(
                initialValue: _selectedPractitioner,
                hint: const Text('Choose your practitioner'),
                items: _practitioners
                    .map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.email})')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPractitioner = v),
              ),
            ),
          _DateStrip(),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Available slots — ${DateFormat('EEE, d MMM').format(provider.selectedDate)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SlotsGrid(),
          if (provider.selectedSlot != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Anything the practitioner should know',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Request ${DateFormat("h:mm a").format(provider.selectedSlot!.start)} – '
                        '${DateFormat("h:mm a").format(provider.selectedSlot!.end)}',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final today = DateTime.now();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 14,
        itemBuilder: (context, i) {
          final date = today.add(Duration(days: i));
          final isSelected = date.year == provider.selectedDate.year &&
              date.month == provider.selectedDate.month &&
              date.day == provider.selectedDate.day;

          return GestureDetector(
            onTap: () => provider.selectDate(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1A73E8) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    if (provider.status == BookingStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text('No slots available', style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: provider.slots.map((slot) {
          return SlotChip(
            slot: slot,
            isSelected: provider.selectedSlot == slot,
            onTap: slot.isAvailable ? () => provider.selectSlot(slot) : null,
          );
        }).toList(),
      ),
    );
  }
}
