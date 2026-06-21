import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'booking_provider.dart';

class BookingFormSheet extends StatefulWidget {
  const BookingFormSheet({super.key});

  @override
  State<BookingFormSheet> createState() => _BookingFormSheetState();
}

class _BookingFormSheetState extends State<BookingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final provider = context.read<BookingProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await provider.confirmBooking(
      guestName: _nameCtrl.text.trim(),
      guestEmail: _emailCtrl.text.trim(),
      guestPhone: _phoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Slot booked! Calendar invite sent. Opening WhatsApp...'),
            ],
          ),
          backgroundColor: const Color(0xFF188038),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final slot = provider.selectedSlot;
    if (slot == null) return const SizedBox();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Slot summary banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF023047)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${DateFormat("EEE, d MMM").format(slot.start)}  ·  '
                      '${DateFormat("h:mm a").format(slot.start)} – ${DateFormat("h:mm a").format(slot.end)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF023047),
                      ),
                    ),
                  ),
                  if (provider.selectedRoom != null)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F0FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.selectedRoom!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF023047)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Guest name + email row
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _nameCtrl,
                    label: 'Guest name',
                    hint: 'Jane Smith',
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'jane@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Phone (for WhatsApp)
            _Field(
              controller: _phoneCtrl,
              label: 'WhatsApp number',
              hint: '+60 12 345 6789',
              keyboardType: TextInputType.phone,
              prefix: const Icon(Icons.phone, size: 16, color: Color(0xFF25D366)),
              validator: (v) => v!.isEmpty ? 'Required for WhatsApp' : null,
            ),
            const SizedBox(height: 10),

            if (provider.selectedSlot!.availableRooms.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: provider.selectedRoom,
                    items: provider.selectedSlot!.availableRooms
                        .map((room) => DropdownMenuItem(value: room, child: Text(room)))
                        .toList(),
                    onChanged: (room) {
                      if (room != null) provider.selectRoom(room);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Select a room',
                    ),
                    validator: (value) => value == null ? 'Select a room' : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ),

            // Notes
            _Field(
              controller: _notesCtrl,
              label: 'Notes (optional)',
              hint: 'Agenda, video link, etc.',
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Notification preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const _NotifBadge(icon: Icons.calendar_month, color: Color(0xFF023047), label: 'Calendar invite'),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 28, color: Colors.grey.shade200),
                  const SizedBox(width: 8),
                  const _NotifBadge(icon: Icons.chat, color: Color(0xFF25D366), label: 'WhatsApp message'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Submit
            ElevatedButton(
              onPressed: _submitting ? null : () => _submit(context),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm booking & notify guest'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final Widget? prefix;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
          ),
        ),
      ],
    );
  }
}

class _NotifBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _NotifBadge({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
