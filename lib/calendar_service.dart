import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/http.dart' as http;
import 'booking.dart';
import 'time_slot.dart';

class _AuthClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _inner = http.Client();

  _AuthClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Always fetch authentication — the SDK returns a cached token and only
    // hits the network when the current one is about to expire.
    final auth = await _account.authentication;
    request.headers['Authorization'] = 'Bearer ${auth.accessToken}';
    return _inner.send(request);
  }
}

class CalendarService {
  static const _scopes = [cal.CalendarApi.calendarScope];
  static const _sharedCalendarName = 'Clinical Room Booking';
  static const _roomNames = ['R1', 'R2', 'R3', 'R4'];
  static final _roomPattern = RegExp(r'\b(R[1-4])\b', caseSensitive: false);

  final _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    serverClientId:
        '383887707617-30hj9t9l64h5omhegmu6j08fjddkhums.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;
  cal.CalendarApi? _calendarApi;
  String? _sharedCalendarId;

  bool get isSignedIn => _currentUser != null;
  bool get sharedCalendarFound => _sharedCalendarId != null;
  String get calendarDisplayName =>
      _sharedCalendarId != null ? _sharedCalendarName : 'Primary Calendar';

  // Uses the shared calendar when found, falls back to primary
  String get _calendarId => _sharedCalendarId ?? 'primary';

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;
      await _initApi();
      await _findSharedCalendar();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _calendarApi = null;
    _sharedCalendarId = null;
  }

  Future<void> _initApi() async {
    _calendarApi = cal.CalendarApi(_AuthClient(_currentUser!));
  }

  Future<void> _findSharedCalendar() async {
    try {
      final list = await _calendarApi!.calendarList.list();
      final match = list.items?.where((c) {
        final name = c.summary?.toLowerCase() ?? '';
        return name.contains(_sharedCalendarName.toLowerCase());
      }).firstOrNull;
      _sharedCalendarId = match?.id;
    } catch (_) {}
  }

  Future<List<TimeSlot>> getAvailableSlots({
    required DateTime date,
    required int slotMinutes,
    int startHour = 9,
    int endHour = 18,
  }) async {
    await _ensureApi();

    final dayStart = DateTime(date.year, date.month, date.day, startHour);
    final dayEnd = DateTime(date.year, date.month, date.day, endHour);

    final result = await _calendarApi!.events.list(
      _calendarId,
      timeMin: dayStart.toUtc(),
      timeMax: dayEnd.toUtc(),
      orderBy: 'startTime',
      singleEvents: true,
      maxResults: 200,
    );

    final events = result.items ?? [];
    final roomBusy = {for (final room in _roomNames) room: <_BusyInterval>[]};

    for (final event in events) {
      final room = _extractRoomFromEvent(event);
      if (room == null) continue;
      final start = event.start?.dateTime?.toLocal();
      final end = event.end?.dateTime?.toLocal();
      if (start == null || end == null) continue;
      if (end.isBefore(dayStart) || start.isAfter(dayEnd)) continue;
      roomBusy[room]?.add(_BusyInterval(start: start, end: end));
    }

    for (final room in _roomNames) {
      roomBusy[room]?.sort((a, b) => a.start.compareTo(b.start));
    }

    final slots = <TimeSlot>[];
    var cursor = dayStart;

    while (cursor.add(Duration(minutes: slotMinutes)).isBefore(dayEnd) ||
        cursor.add(Duration(minutes: slotMinutes)) == dayEnd) {
      final slotEnd = cursor.add(Duration(minutes: slotMinutes));
      final availableRooms = _roomNames.where((room) {
        final busyIntervals = roomBusy[room]!;
        return busyIntervals.every((busy) => cursor.isAfter(busy.end) || slotEnd.isBefore(busy.start));
      }).toList();

      slots.add(TimeSlot(start: cursor, end: slotEnd, availableRooms: availableRooms));
      cursor = cursor.add(const Duration(minutes: 30));
    }

    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    return isToday ? slots.where((s) => s.end.isAfter(now)).toList() : slots;
  }

  Future<String?> createBookingEvent(
    Booking booking, {
    String? overrideCalendarId,
  }) async {
    await _ensureApi();
    final targetCalendarId = overrideCalendarId ?? _calendarId;

    final event = cal.Event(
      summary: booking.title,
      location: booking.room,
      description: 'Guest: ${booking.guestName}\n'
          'Email: ${booking.guestEmail}\n'
          'Phone: ${booking.guestPhone}\n'
          '${booking.notes != null ? 'Notes: ${booking.notes}\n' : ''}'
          '${booking.room != null ? 'Room: ${booking.room}' : ''}',
      start: cal.EventDateTime(
          dateTime: booking.startTime.toUtc(), timeZone: 'UTC'),
      end:
          cal.EventDateTime(dateTime: booking.endTime.toUtc(), timeZone: 'UTC'),
      attendees: [
        cal.EventAttendee(
            email: booking.guestEmail, displayName: booking.guestName),
      ],
      extendedProperties: cal.EventExtendedProperties(
        private: {
          'bookme_guest_phone': booking.guestPhone,
          'bookme_source': 'bookme_app',
          if (booking.room != null) 'bookme_room': booking.room!,
        },
      ),
      reminders: cal.EventReminders(
        useDefault: false,
        overrides: [
          cal.EventReminder(method: 'email', minutes: 60),
          cal.EventReminder(method: 'popup', minutes: 15),
        ],
      ),
    );

    final created = await _calendarApi!.events
        .insert(event, targetCalendarId, sendUpdates: 'all');
    return created.id;
  }

  /// All future events from the shared calendar (for Room tab).
  Future<List<cal.Event>> getCalendarEvents() async {
    await _ensureApi();

    final result = await _calendarApi!.events.list(
      _calendarId,
      timeMin: DateTime.now().toUtc(),
      maxResults: 200,
      orderBy: 'startTime',
      singleEvents: true,
    );

    return result.items ?? [];
  }

  /// All upcoming events from the signed-in user's own primary calendar.
  Future<List<cal.Event>> getMyUpcomingBookings() async {
    await _ensureApi();

    final result = await _calendarApi!.events.list(
      'primary',
      timeMin: DateTime.now().toUtc(),
      maxResults: 50,
      orderBy: 'startTime',
      singleEvents: true,
    );

    return result.items ?? [];
  }

  /// Today's events from the shared room-booking calendar only.
  Future<List<cal.Event>> getTodaysSharedEvents() async {
    await _ensureApi();
    if (_sharedCalendarId == null) return [];

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final result = await _calendarApi!.events.list(
      _sharedCalendarId!,
      timeMin: todayStart.toUtc(),
      timeMax: todayEnd.toUtc(),
      maxResults: 50,
      orderBy: 'startTime',
      singleEvents: true,
    );

    return result.items ?? [];
  }

  /// Past bookings from the shared calendar.
  Future<List<cal.Event>> getPastBookings({int days = 30}) async {
    await _ensureApi();

    final result = await _calendarApi!.events.list(
      _calendarId,
      timeMin: DateTime.now().subtract(Duration(days: days)).toUtc(),
      timeMax: DateTime.now().toUtc(),
      maxResults: 100,
      orderBy: 'startTime',
      singleEvents: true,
    );

    return result.items ?? [];
  }

  String? _extractRoomFromEvent(cal.Event event) {
    final source = [event.location, event.summary, event.description]
        .whereType<String>()
        .join(' ');
    final match = _roomPattern.firstMatch(source);
    return match?.group(1)?.toUpperCase();
  }

  Future<void> _ensureApi() async {
    if (_calendarApi == null) {
      if (_currentUser == null) throw Exception('Not signed in');
      await _initApi();
    }
  }

  
}

class _BusyInterval {
  final DateTime start;
  final DateTime end;

  _BusyInterval({required this.start, required this.end});
}
