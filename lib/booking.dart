class Booking {
  final String id;
  final String title;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final DateTime startTime;
  final DateTime endTime;
  final String? notes;
  final String? room;
  final bool confirmed;
  final String? calendarEventId;

  const Booking({
    required this.id,
    required this.title,
    required this.guestName,
    required this.guestEmail,
    required this.guestPhone,
    required this.startTime,
    required this.endTime,
    this.notes,
    this.room,
    this.confirmed = false,
    this.calendarEventId,
  });

  String get durationLabel {
    final minutes = endTime.difference(startTime).inMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainder = minutes % 60;
      return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
    }
    return '${minutes}m';
  }

  Booking copyWith({
    String? id,
    String? title,
    String? guestName,
    String? guestEmail,
    String? guestPhone,
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
    String? room,
    bool? confirmed,
    String? calendarEventId,
  }) {
    return Booking(
      id: id ?? this.id,
      title: title ?? this.title,
      guestName: guestName ?? this.guestName,
      guestEmail: guestEmail ?? this.guestEmail,
      guestPhone: guestPhone ?? this.guestPhone,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      room: room ?? this.room,
      confirmed: confirmed ?? this.confirmed,
      calendarEventId: calendarEventId ?? this.calendarEventId,
    );
  }
}
