import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'booking_provider.dart';
import 'booking.dart';
import 'slot_chip.dart';
import 'booking_form_sheet.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1) {
        context.read<BookingProvider>().loadCalendarEvents();
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
        title: const Text('Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<BookingProvider>(),
                child: const _SettingsDialog(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => context.read<BookingProvider>().signOut(),
            tooltip: 'Sign out',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available Slots'),
            Tab(text: 'Day Schedule'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BookBody(),
          _DaySchedule(),
        ],
      ),
    );
  }
}

class _BookBody extends StatelessWidget {
  const _BookBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return RefreshIndicator(
      onRefresh: provider.loadSlots,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          const _DateSelector(),
          const _DateStrip(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Booking from: ${provider.calendarDisplayName}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          _DurationToggle(),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Available slots — ${_dateLabel(provider.selectedDate)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SlotsGrid(),
          if (provider.selectedSlot != null) _BookingFormTrigger(),
        ],
      ),
    );
  }

  String _dateLabel(DateTime d) {
    final today = DateTime.now();
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'today';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
      return 'tomorrow';
    }
    return DateFormat('EEE, d MMM').format(d);
  }
}

class _DateSelector extends StatefulWidget {
  const _DateSelector();

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
              'Selected date: ${DateFormat('EEE, d MMM').format(selectedDate)}',
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
              if (picked == null) return;
              if (!mounted) return;
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
  const _DateStrip();

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
                color: isSelected
                    ? const Color(0xFF023047)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF023047)
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
                        color: isSelected ? Colors.white60 : const Color(0xFF023047),
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

class _DurationToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Text(
            'Slot duration:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 10),
          _SegmentedButton(
            options: const {'60': '1 hr', '90': '1.5 hr'},
            selected: provider.slotDurationMinutes.toString(),
            onSelect: (v) => provider.setDuration(int.parse(v)),
          ),
        ],
      ),
    );
  }
}

class _SegmentedButton extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentedButton({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.entries.map((e) {
          final isSelected = e.key == selected;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF023047) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          );
        }).toList(),
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
          child: Text(
            'No slots available',
            style: TextStyle(color: Colors.grey.shade500),
          ),
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

class _BookingFormTrigger extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final slot = context.watch<BookingProvider>().selectedSlot!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: ElevatedButton.icon(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => ChangeNotifierProvider.value(
              value: context.read<BookingProvider>(),
              child: const BookingFormSheet(),
            ),
          );
        },
        icon: const Icon(Icons.edit_calendar_outlined),
        label: Text(
          'Book ${DateFormat("h:mm a").format(slot.start)} – ${DateFormat("h:mm a").format(slot.end)} • ${slot.roomsLabel}',
        ),
      ),
    );
  }
}

// -- Day Schedule (formerly the standalone Room tab) --------------------------

class _DaySchedule extends StatefulWidget {
  const _DaySchedule();

  @override
  State<_DaySchedule> createState() => _DayScheduleState();
}

class _DayScheduleState extends State<_DaySchedule> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadCalendarEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingProvider>(
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
              const _DateSelector(),
              const _DateStrip(),
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
                        ? const Color(0xFF023047)
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
                                fontSize: 11, color: Color(0xFF023047)),
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

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();
    return AlertDialog(
      title: const Text('Settings'),
      content: SwitchListTile(
        title: const Text('Book on shared calendar'),
        subtitle: Text(
          provider.useSharedCalendar
              ? 'Events added to: ${provider.calendarDisplayName}'
              : 'Events created for sender & receiver only',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        value: provider.useSharedCalendar,
        onChanged: provider.setUseSharedCalendar,
        contentPadding: EdgeInsets.zero,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
