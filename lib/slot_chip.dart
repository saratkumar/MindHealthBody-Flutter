import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'time_slot.dart';

class SlotChip extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const SlotChip({
    super.key,
    required this.slot,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = slot.isAvailable;

    final Color bgColor;
    final Color borderColor;
    final Color timeColor;
    final Color roomColor;

    if (isSelected) {
      bgColor = const Color(0xFF023047);
      borderColor = const Color(0xFF023047);
      timeColor = Colors.white;
      roomColor = Colors.white70;
    } else if (available) {
      bgColor = const Color(0xFFF0FBF4);
      borderColor = const Color(0xFFA8D5B5);
      timeColor = Colors.black87;
      roomColor = const Color(0xFF188038);
    } else {
      bgColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade200;
      timeColor = Colors.grey.shade400;
      roomColor = Colors.grey.shade400;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${DateFormat('h:mm').format(slot.start)}–${DateFormat('h:mm a').format(slot.end)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: timeColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              available ? slot.roomsLabel : 'Fully booked',
              style: TextStyle(
                fontSize: 11,
                color: roomColor,
                decoration: !available ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
