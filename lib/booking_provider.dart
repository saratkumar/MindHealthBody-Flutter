import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'booking.dart';
import 'time_slot.dart';
import 'calendar_service.dart';
import 'whatsapp_service.dart';

enum BookingStatus { idle, loading, success, error }

class BookingProvider extends ChangeNotifier {
  final CalendarService _calendarService = CalendarService();

  // State
  BookingStatus status = BookingStatus.idle;
  bool useSharedCalendar = true;

  BookingProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    useSharedCalendar = prefs.getBool('use_shared_calendar') ?? true;
    notifyListeners();
  }

  Future<void> setUseSharedCalendar(bool value) async {
    useSharedCalendar = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_shared_calendar', value);
  }
  String? errorMessage;
  bool get isSignedIn => _calendarService.isSignedIn;

  DateTime selectedDate = DateTime.now();
  int slotDurationMinutes = 90; // 60 or 90
  int workStartHour = 0;
  int workEndHour = 24;

  List<TimeSlot> slots = [];
  TimeSlot? selectedSlot;
  String? selectedRoom;

  List<Booking> myUpcomingBookings = [];
  List<Booking> othersUpcomingBookings = [];
  List<Booking> pastBookings = [];
  List<Booking> pastSharedBookings = [];
  List<Booking> calendarEvents = [];

  // ─── Auth ────────────────────────────────────────────────
  Future<bool> signIn() async {
    _setStatus(BookingStatus.loading);
    final ok = await _calendarService.signIn();
    if (ok) {
      _setStatus(BookingStatus.idle);
      await loadSlots();
      await loadUpcoming();
      await loadCalendarEvents();
    } else {
      _setStatus(BookingStatus.error, 'Sign-in failed. Please try again.');
    }
    return ok;
  }

  Future<void> signOut() async {
    await _calendarService.signOut();
    slots = [];
    selectedSlot = null;
    selectedRoom = null;
    myUpcomingBookings = [];
    othersUpcomingBookings = [];
    pastBookings = [];
    pastSharedBookings = [];
    calendarEvents = [];
    status = BookingStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  // ─── Slots ───────────────────────────────────────────────
  Future<void> loadSlots() async {
    if (!isSignedIn) return;
    _setStatus(BookingStatus.loading);
    try {
      slots = await _calendarService.getAvailableSlots(
        date: selectedDate,
        slotMinutes: slotDurationMinutes,
        startHour: workStartHour,
        endHour: workEndHour,
      );
      selectedSlot = null;
      selectedRoom = null;
      _setStatus(BookingStatus.idle);
    } catch (e) {
      _setStatus(BookingStatus.error, 'Could not load slots: $e');
    }
  }

  void selectDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    selectedRoom = null;
    loadSlots();
  }

  void selectSlot(TimeSlot slot) {
    selectedSlot = slot;
    selectedRoom = slot.availableRooms.isNotEmpty ? slot.availableRooms.first : null;
    notifyListeners();
  }

  void selectRoom(String room) {
    selectedRoom = room;
    notifyListeners();
  }

  void setDuration(int minutes) {
    slotDurationMinutes = minutes;
    loadSlots();
  }

  // ─── Booking ─────────────────────────────────────────────
  Future<bool> confirmBooking({
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    String? notes,
  }) async {
    if (selectedSlot == null || selectedRoom == null) return false;

    _setStatus(BookingStatus.loading);

    final booking = Booking(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _buildEventTitle(selectedRoom!, guestName),
      guestName: guestName,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
      startTime: selectedSlot!.start,
      endTime: selectedSlot!.end,
      notes: notes,
      room: selectedRoom,
    );

    try {
      // 1. Create Google Calendar event (sends invite automatically)
      final eventId = await _calendarService.createBookingEvent(
        booking,
        overrideCalendarId: useSharedCalendar ? null : 'primary',
      );
      final confirmedBooking = booking.copyWith(
        confirmed: true,
        calendarEventId: eventId,
      );

      // 2. Open WhatsApp with pre-filled message
      await WhatsAppService.sendBookingConfirmation(confirmedBooking);

      // 3. Refresh data
      await loadSlots();
      await loadUpcoming();
      await loadCalendarEvents();

      _setStatus(BookingStatus.success);
      return true;
    } catch (e) {
      _setStatus(BookingStatus.error, 'Booking failed: $e');
      return false;
    }
  }

  // ─── History / Upcoming ──────────────────────────────────
  Future<void> loadUpcoming() async {
    if (!isSignedIn) return;
    try {
      // My Bookings: all upcoming events from the signed-in user's primary calendar
      final myEvents = await _calendarService.getMyUpcomingBookings();
      myUpcomingBookings = myEvents.map((e) => _eventToBooking(e)).toList();

      // Others' Appointments: shared calendar, today only
      final sharedEvents = await _calendarService.getTodaysSharedEvents();
      othersUpcomingBookings = sharedEvents.map((e) => _eventToBooking(e)).toList();

      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadHistory() async {
    if (!isSignedIn) return;
    try {
      final myEvents = await _calendarService.getPastMyBookings();
      pastBookings = myEvents.map((e) => _eventToBooking(e)).toList();

      final sharedEvents = await _calendarService.getPastSharedBookings();
      pastSharedBookings = sharedEvents.map((e) => _eventToBooking(e)).toList();

      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadCalendarEvents() async {
    if (!isSignedIn) return;
    try {
      final events = await _calendarService.getCalendarEvents();
      calendarEvents = events.map((e) => _eventToBooking(e)).toList();
      notifyListeners();
    } catch (_) {}
  }

  String get calendarDisplayName => _calendarService.calendarDisplayName;

  Booking _eventToBooking(dynamic event) {
    final desc = event.description ?? '';
    final room = event.location ??
        event.extendedProperties?.private?['bookme_room'] ??
        _extractRoom(desc);

    return Booking(
      id: event.id ?? '',
      title: event.summary ?? 'Meeting',
      guestName: _extractField(desc, 'Guest') ?? 'Guest',
      guestEmail: _extractField(desc, 'Email') ?? '',
      guestPhone: event.extendedProperties?.private?['bookme_guest_phone'] ?? '',
      startTime: event.start?.dateTime?.toLocal() ?? DateTime.now(),
      endTime: event.end?.dateTime?.toLocal() ?? DateTime.now(),
      notes: _extractField(desc, 'Notes'),
      confirmed: true,
      calendarEventId: event.id,
      room: room,
    );
  }

  String? _extractRoom(String desc) {
    final match = RegExp(r'\b(R[1-4])\b', caseSensitive: false).firstMatch(desc);
    return match?.group(1)?.toUpperCase();
  }

  String? _extractField(String desc, String field) {
    final line = desc.split('\n').firstWhere(
      (l) => l.startsWith('$field:'),
      orElse: () => '',
    );
    if (line.isEmpty) return null;
    return line.substring('$field:'.length).trim();
  }

  String _buildEventTitle(String room, String guestName) {
    const therapist = 'SK';
    final client = _clientInitials(guestName);
    return '$room ($therapist) - ($client)';
  }

  String _clientInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final n = name.trim();
    return (n.length >= 4 ? n.substring(0, 4) : n).toUpperCase();
  }

  void _setStatus(BookingStatus s, [String? msg]) {
    status = s;
    errorMessage = msg;
    notifyListeners();
  }
}
