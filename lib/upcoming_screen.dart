import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'booking_provider.dart';
import 'booking.dart';
import 'whatsapp_service.dart';
import 'client_registry_service.dart';
import 'invoice_pdf_generator.dart';
import 'invoice_excel_service.dart';

class UpcomingScreen extends StatefulWidget {
  const UpcomingScreen({super.key});

  @override
  State<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends State<UpcomingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1) {
        context.read<BookingProvider>().loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UpcomingBody(),
          _HistoryBody(),
        ],
      ),
    );
  }
}

class _UpcomingBody extends StatelessWidget {
  const _UpcomingBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
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
                title: 'Room Schedule — Today',
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
    );
  }
}

// -- History (formerly the standalone History tab) ----------------------------

class _HistoryBody extends StatefulWidget {
  const _HistoryBody();

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  String _filter = 'mine'; // 'mine' | 'shared'

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
      builder: (context, provider, _) {
        if (provider.status == BookingStatus.loading &&
            provider.pastBookings.isEmpty &&
            provider.pastSharedBookings.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings =
            _filter == 'mine' ? provider.pastBookings : provider.pastSharedBookings;
        final emptyMessage = _filter == 'mine'
            ? 'No past bookings from your calendar'
            : 'No past bookings from the shared calendar';

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _HistoryFilterButton(
                      label: 'My Bookings',
                      selected: _filter == 'mine',
                      onTap: () => setState(() => _filter = 'mine'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HistoryFilterButton(
                      label: 'Shared Calendar',
                      selected: _filter == 'shared',
                      onTap: () => setState(() => _filter = 'shared'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => context.read<BookingProvider>().loadHistory(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _BookingList(bookings: bookings, emptyMessage: emptyMessage),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryFilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HistoryFilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF023047) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF023047) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ── Invoice helpers ───────────────────────────────────────────────────────────

void _showInvoiceDialog(BuildContext context, Booking booking) {
  showDialog(
    context: context,
    builder: (ctx) => _InvoiceDialog(booking: booking, parentContext: context),
  );
}

Future<void> _generateAndShare(
  BuildContext context,
  Booking booking, {
  required List<InvoiceItem> items,
}) async {
  final total = items.fold<double>(0, (s, i) => s + i.amount);
  final messenger = ScaffoldMessenger.of(context);
  final account =
      context.read<BookingProvider>().currentAccount as GoogleSignInAccount?;

  if (account == null) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Sign in with Google to generate invoices'),
    ));
    return;
  }

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
    final (client, invoiceNumber) = await ClientRegistryService.recordSession(
      account,
      name: booking.guestName,
      email: booking.guestEmail,
      phone: booking.guestPhone,
      sessionDate: booking.startTime,
      fee: total,
      lessCHS1: 0,
    );

    final excelBytes = await InvoiceExcelService.writeInvoice(
      invoiceNumber: invoiceNumber,
      sessionDate: booking.startTime,
      clientId: client.clientId,
      clientName: booking.guestName,
      clientPhone: booking.guestPhone,
      fee: total,
      lessCHS1: 0,
    );

    final pdfBytes = await InvoicePdfGenerator.generate(
      invoiceNumber: invoiceNumber,
      invoiceDate: booking.startTime,
      clientName: booking.guestName,
      clientPhone: booking.guestPhone,
      clientId: client.clientId,
      items: items,
    );

    loadingBar.close();

    await Share.shareXFiles(
      [
        XFile.fromData(
          pdfBytes,
          name: InvoicePdfGenerator.filename(booking.guestName, booking.startTime),
          mimeType: 'application/pdf',
        ),
        XFile.fromData(
          excelBytes,
          name: InvoiceExcelService.filename(booking.guestName, booking.startTime),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
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

// ── Invoice dialog ────────────────────────────────────────────────────────────

class _LineItem {
  final descCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  double get amount {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    return qty * price;
  }

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _InvoiceDialog extends StatefulWidget {
  final Booking booking;
  final BuildContext parentContext;
  const _InvoiceDialog({required this.booking, required this.parentContext});

  @override
  State<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<_InvoiceDialog> {
  final List<_LineItem> _items = [];

  @override
  void initState() {
    super.initState();
    _items.add(_LineItem());
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.amount);

  List<InvoiceItem> _collectItems() {
    return _items
        .where((i) => i.descCtrl.text.trim().isNotEmpty)
        .map((i) => InvoiceItem(
              description: i.descCtrl.text.trim(),
              qty: double.tryParse(i.qtyCtrl.text) ?? 1,
              unitPrice: double.tryParse(i.priceCtrl.text) ?? 0,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Invoice'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.booking.guestName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (widget.booking.guestPhone.isNotEmpty)
              Text(
                widget.booking.guestPhone,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 14),
            // Column headers
            Row(
              children: [
                const Expanded(
                  flex: 5,
                  child: Text('Description',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 38,
                  child: Text('Qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 64,
                  child: Text('Unit Price',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 64,
                  child: Text('Amount',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600)),
                ),
                const SizedBox(width: 28),
              ],
            ),
            const SizedBox(height: 6),
            // Scrollable item rows
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < _items.length; i++)
                      _buildItemRow(i),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_LineItem())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Item', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    '₹ ${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final invoiceItems = _collectItems();
            if (invoiceItems.isEmpty || _total <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Add at least one item with a valid amount')),
              );
              return;
            }
            Navigator.pop(context);
            _generateAndShare(widget.parentContext, widget.booking,
                items: invoiceItems);
          },
          icon: const Icon(Icons.picture_as_pdf, size: 16),
          label: const Text('Generate & Send'),
        ),
      ],
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    final amt = item.amount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: item.descCtrl,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                border: OutlineInputBorder(),
                hintText: 'Description',
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 38,
            child: TextField(
              controller: item.qtyCtrl,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 64,
            child: TextField(
              controller: item.priceCtrl,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 64,
            child: Text(
              amt > 0 ? amt.toStringAsFixed(2) : '',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 28,
            child: _items.length > 1
                ? IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      item.dispose();
                      _items.removeAt(index);
                    }),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
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

class _BookingList extends StatelessWidget {
  final List<Booking> bookings;
  final String emptyMessage;

  const _BookingList({required this.bookings, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyMessage, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    final grouped = <String, List<Booking>>{};
    for (final b in bookings) {
      final key = DateFormat('MMMM yyyy').format(b.startTime);
      grouped.putIfAbsent(key, () => []).add(b);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...entry.value.map((b) => _HistoryTile(booking: b)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Booking booking;
  const _HistoryTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${booking.startTime.day}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
        title: Text(
          booking.title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          '${booking.guestName}  ·  ${DateFormat("h:mm a").format(booking.startTime)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            booking.durationLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ),
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
                            : const Color(0xFF023047),
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
                        color: Color(0xFF023047)),
                    label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFF023047)),
                      foregroundColor: const Color(0xFF023047),
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
