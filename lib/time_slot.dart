import 'package:intl/intl.dart';

class TimeSlot {
  final DateTime start;
  final DateTime end;
  final List<String> availableRooms;

  const TimeSlot({
    required this.start,
    required this.end,
    this.availableRooms = const [],
  });

  bool get isAvailable => availableRooms.isNotEmpty;

  String get label => DateFormat('h:mm a').format(start);

  String get roomsLabel {
    if (!isAvailable) return 'Busy';
    if (availableRooms.length <= 2) return availableRooms.join(', ');
    return '${availableRooms.take(2).join(', ')}, +${availableRooms.length - 2}';
  }
}
