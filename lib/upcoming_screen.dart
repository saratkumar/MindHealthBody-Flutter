import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'booking_provider.dart';
import 'booking.dart';
import 'whatsapp_service.dart';
import 'client_database.dart';
import 'invoice_pdf_generator.dart';
import 'invoice_excel_service.dart';

class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming')),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          if (provider.status == BookingStatus.loading &&
              provider.myUpcomingBookings.isEmpty &&
              provider.othersUpcomingBookings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.myUpcomingBookings.isEmpty &&
              provider.othersUpcomingBookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No upcoming appointments',
                      style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: provider.loadUpcoming,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadUpcoming,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  title: 'My Bookings',
                  count: provider.myUpcomingBookings.length,
                ),
                const SizedBox(height: 8),
                if (provider.myUpcomingBookings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'No upcoming bookings made through this app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  )
                else
                  ...provider.myUpcomingBookings.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BookingCard(booking: b, showActions: true),
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: "Room Schedule — Today",
                  count: provider.othersUpcomingBookings.length,
                ),
                const SizedBox(height: 8),
                if (provider.othersUpcomingBookings.isEmpty)
                  Text(
                    'No other appointments on the calendar.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  )
                else
                  ...provider.othersUpcomingBookings.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BookingCard(booking: b, showActions: false),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Invoice helpers (top-level so both StatelessWidget and dialogs can use them)

void _showInvoiceDialog(BuildContext context, Booking booking) {
  final feeCtrl = TextEditingController();
  final discountCtrl = TextEditingController(text: '0');

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Generate Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.guestName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (booking.guestPhone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 14),
                child: Text(
                  booking.guestPhone,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              )
            else
              const SizedBox(height: 14),
            TextField(
              controller: feeCtrl,
              decoration: const InputDecoration(
                labelText: 'Fee (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: discountCtrl,
              decoration: const InputDecoration(
                labelText: 'Less CHS1 (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
                helperText: 'Discount / concession amount',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final fee = double.tryParse(feeCtrl.text.trim()) ?? 0;
              if (fee <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid fee')),
                );
                return;
              }
              final discount = double.tryParse(discountCtrl.text.trim()) ?? 0;
              Navigator.pop(ctx);
              _generateAndShare(context, booking, fee: fee, lessCHS1: discount);
            },
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Generate & Send'),
          ),
        ],
      );
    },
  );
}

Future<void> _generateAndShare(
  BuildContext context,
  Booking booking, {
  required double fee,
  required double lessCHS1,
}) async {
  // Show loading indicator
  final messenger = ScaffoldMessenger.of(context);
  final loadingBar = messenger.showSnackBar(
    const SnackBar(
      duration: Duration(minutes: 1),
      content: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 14),
          Text('Generating invoice…'),
        ],
      ),
    ),
  );

  try {
    // 1. Record session → get client record + invoice number
    final (client, invoiceNumber) = await ClientDatabase.recordSession(
      name: booking.guestName,
      phone: booking.guestPhone,
      sessionDate: booking.startTime,
      fee: fee,
      lessCHS1: lessCHS1,
    );

    // 2. Update Excel workbook (Sheet 1 filled, Sheet 2 upserted, named copy saved)
    await InvoiceExcelService.writeInvoice(
      invoiceNumber: invoiceNumber,
      sessionDate: booking.startTime,
      clientId: client.clientId,
      clientName: booking.guestName,
      clientPhone: booking.guestPhone,
      monthKey: client.monthKey,
      clientNumber: client.clientNumber,
      totalSessions: client.sessionCount,
      fee: fee,
      lessCHS1: lessCHS1,
    );

    // 3. Generate PDF matching Sheet 1 layout
    final pdfFile = await InvoicePdfGenerator.generate(
      invoiceNumber: invoiceNumber,
      invoiceDate: booking.startTime,
      clientName: booking.guestName,
      clientPhone: booking.guestPhone,
      clientId: client.clientId,
      fee: fee,
      lessCHS1: lessCHS1,
    );

    loadingBar.close();

    // 4. Open system share sheet (user selects WhatsApp or saves to Downloads)
    await Share.shareXFiles(
      [XFile(pdfFile.path, mimeType: 'application/pdf')],
      subject: 'Invoice $invoiceNumber — ${booking.guestName}',
      text: 'Hi ${booking.guestName}, please find your invoice attached.',
    );
  } catch (e) {
    loadingBar.close();
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to generate invoice: $e')),
      );
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final bool showActions;
  const _BookingCard({required this.booking, required this.showActions});

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(booking.startTime);
    final isSoon = booking.startTime.difference(DateTime.now()).inHours < 2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSoon
                          ? const Color(0xFFFCEBEB)
                          : const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSoon ? 'Soon' : 'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isSoon
                            ? const Color(0xFFA32D2D)
                            : const Color(0xFF1A73E8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _MetaRow(
              icon: Icons.schedule,
              text: '${DateFormat("EEE, d MMM").format(booking.startTime)}  ·  '
                  '${DateFormat("h:mm a").format(booking.startTime)} – '
                  '${DateFormat("h:mm a").format(booking.endTime)}',
            ),
            if (booking.room != null)
              _MetaRow(icon: Icons.meeting_room_outlined, text: booking.room!),
            _MetaRow(icon: Icons.person_outline, text: booking.guestName),
            if (booking.guestEmail.isNotEmpty)
              _MetaRow(icon: Icons.email_outlined, text: booking.guestEmail),
            if (showActions) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // Reminder button
                  OutlinedButton.icon(
                    onPressed: () => WhatsAppService.sendReminder(booking),
                    icon: const Icon(Icons.chat, size: 14, color: Color(0xFF25D366)),
                    label: const Text('Reminder', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFF25D366)),
                      foregroundColor: const Color(0xFF25D366),
                    ),
                  ),
                  // Generate Invoice button
                  OutlinedButton.icon(
                    onPressed: () => _showInvoiceDialog(context, booking),
                    icon: const Icon(Icons.receipt_long, size: 14,
                        color: Color(0xFF1A73E8)),
                    label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFF1A73E8)),
                      foregroundColor: const Color(0xFF1A73E8),
                    ),
                  ),
                  // Calendar button
                  if (booking.calendarEventId != null)
                    OutlinedButton.icon(
                      onPressed: () => _openCalendar(booking),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Calendar', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openCalendar(Booking booking) async {
    final uri = Uri.parse(
      'https://calendar.google.com/calendar/event?eid=${booking.calendarEventId}',
    );
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
