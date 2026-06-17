import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'booking_provider.dart';
import 'booking.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<BookingProvider>().loadHistory(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Bookings'),
              Tab(text: 'Shared Calendar'),
            ],
          ),
        ),
        body: Consumer<BookingProvider>(
          builder: (context, provider, _) {
            if (provider.status == BookingStatus.loading &&
                provider.pastBookings.isEmpty &&
                provider.pastSharedBookings.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              children: [
                _BookingList(
                  bookings: provider.pastBookings,
                  emptyMessage: 'No past bookings from your calendar',
                ),
                _BookingList(
                  bookings: provider.pastSharedBookings,
                  emptyMessage: 'No past bookings from the shared calendar',
                ),
              ],
            );
          },
        ),
      ),
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
            Text(emptyMessage,
                style: TextStyle(color: Colors.grey.shade500)),
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
