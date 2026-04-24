import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'booking.dart';

class WhatsAppService {
  /// Opens WhatsApp with a pre-filled booking confirmation message.
  /// Sends FROM your own number — no API, no cost.
  static Future<bool> sendBookingConfirmation(Booking booking) async {
    final message = _buildMessage(booking);
    return _openWhatsApp(phone: booking.guestPhone, message: message);
  }

  /// Opens WhatsApp with a reminder message (call before the meeting)
  static Future<bool> sendReminder(Booking booking) async {
    final message = _buildReminder(booking);
    return _openWhatsApp(phone: booking.guestPhone, message: message);
  }

  static Future<bool> _openWhatsApp({
    required String phone,
    required String message,
  }) async {
    // Normalise phone: strip spaces/dashes, ensure + prefix
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final encodedMsg = Uri.encodeComponent(message);

    // wa.me deep link — opens WhatsApp directly on Android
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }

    // Fallback: WhatsApp intent URI
    final intentUri = Uri.parse('intent://send/$cleanPhone#Intent;'
        'scheme=smsto;package=com.whatsapp;action=android.intent.action.SENDTO;end');
    if (await canLaunchUrl(intentUri)) {
      await launchUrl(intentUri);
      return true;
    }

    return false;
  }

  static String _buildMessage(Booking booking) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(booking.startTime);
    final timeStr = DateFormat('h:mm a').format(booking.startTime);
    final endStr = DateFormat('h:mm a').format(booking.endTime);

    return '''Hi ${booking.guestName}! 👋

Your booking is *confirmed* ✅

📅 *Date:* $dateStr
🕐 *Time:* $timeStr – $endStr (${booking.durationLabel})
📋 *Meeting:* ${booking.title}
${booking.notes != null && booking.notes!.isNotEmpty ? '📝 *Notes:* ${booking.notes}' : ''}

A calendar invite has been sent to ${booking.guestEmail}.

Looking forward to meeting you! 🙌''';
  }

  static String _buildReminder(Booking booking) {
    final timeStr = DateFormat('h:mm a').format(booking.startTime);

    return '''Hi ${booking.guestName}! 👋

Just a friendly reminder — we have *${booking.title}* today at *$timeStr*.

See you soon! 😊''';
  }
}
