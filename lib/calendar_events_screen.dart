import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'booking_provider.dart';
import 'booking.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadCalendarEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<BookingProvider>().loadCalendarEvents(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          final eventsForDate = provider.calendarEvents.where((booking) {
            final sameDay = booking.startTime.year == provider.selectedDate.year &&
                booking.startTime.month == provider.selectedDate.month &&
                booking.startTime.day == provider.selectedDate.day;
            if (!sameDay) return false;
            if (provider.selectedDate.year == DateTime.now().year &&
                provider.selectedDate.month == DateTime.now().month &&
                provider.selectedDate.day == DateTime.now().day) {
              return booking.endTime.isAfter(DateTime.now());
            }
            return true;
          }).toList();

          if (provider.status == BookingStatus.loading &&
              provider.calendarEvents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async => provider.loadCalendarEvents(),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DateSelector(),
                _DateStrip(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Events — ${DateFormat('EEE, d MMM').format(provider.selectedDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (eventsForDate.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'No events for this date.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else
                  ...eventsForDate.map((booking) => _RoomEventCard(booking: booking)),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateSelector extends StatefulWidget {
  @override
  State<_DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<_DateSelector> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    final selectedDate = provider.selectedDate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Selected: ${DateFormat('EEE, d MMM').format(selectedDate)}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final provider = context.read<BookingProvider>();
              final today = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate.isBefore(today) ? today : selectedDate,
                firstDate: today,
                lastDate: today.add(const Duration(days: 365)),
                builder: (context, child) => Theme(
                  data: Theme.of(context),
                  child: child!,
                ),
              );
              if (picked == null || !mounted) return;
              provider.selectDate(picked);
            },
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text('Calendar'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
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
                  color: isSelected
                      ? const Color(0xFF1A73E8)
                      : Colors.grey.shade200,
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
                  if (i == 0)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white60
                            : const Color(0xFF1A73E8),
                        shape: BoxShape.circle,
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

class _RoomEventCard extends StatelessWidget {
  final Booking booking;
  const _RoomEventCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isNow = booking.startTime.isBefore(now) && booking.endTime.isAfter(now);
    final isToday = booking.startTime.year == now.year &&
        booking.startTime.month == now.month &&
        booking.startTime.day == now.day;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: isNow
                    ? const Color(0xFF188038)
                    : isToday
                        ? const Color(0xFF1A73E8)
                        : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      if (isNow)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4EA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Now',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF188038)),
                          ),
                        )
                      else if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF1A73E8)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('h:mm a').format(booking.startTime)} – '
                    '${DateFormat('h:mm a').format(booking.endTime)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  if (booking.room != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        booking.room!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      booking.guestName,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
