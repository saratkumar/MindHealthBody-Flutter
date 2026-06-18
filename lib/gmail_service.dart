import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class GmailService {
  static Future<void> sendIntakeFormEmail({
    required GoogleSignInAccount account,
    required String patientName,
    required String clientEmail,
    required String practitionerEmail,
    required String practitionerName,
    required Uint8List pdfBytes,
    required String filename,
    required DateTime submittedAt,
  }) async {
    final api = gmail.GmailApi(_GmailAuthClient(account));

    final boundary = 'intake_${DateTime.now().millisecondsSinceEpoch}';
    final pdfBase64 = _wrapBase64(base64.encode(pdfBytes));
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(submittedAt);

    final bodyText =
        'Dear $practitionerName,\r\n\r\n'
        'Please find attached the completed Client Intake Form for $patientName.\r\n\r\n'
        'Submitted: $dateStr\r\n'
        'Client email: $clientEmail\r\n\r\n'
        'This form was submitted electronically via The MindBody Practice portal.\r\n\r\n'
        'Regards,\r\n'
        '$patientName';

    // CC both the signed-in Google address and the email the client wrote in the form
    final ccSet = <String>{account.email, clientEmail}
        .where((e) => e.trim().isNotEmpty)
        .toSet();
    final ccLine = ccSet.join(', ');

    final mime =
        'MIME-Version: 1.0\r\n'
        'From: ${account.email}\r\n'
        'To: $practitionerEmail\r\n'
        'Cc: $ccLine\r\n'
        'Subject: Client Intake Form – $patientName\r\n'
        'Content-Type: multipart/mixed; boundary="$boundary"\r\n'
        '\r\n'
        '--$boundary\r\n'
        'Content-Type: text/plain; charset="UTF-8"\r\n'
        '\r\n'
        '$bodyText\r\n'
        '\r\n'
        '--$boundary\r\n'
        'Content-Type: application/pdf; name="$filename"\r\n'
        'Content-Disposition: attachment; filename="$filename"\r\n'
        'Content-Transfer-Encoding: base64\r\n'
        '\r\n'
        '$pdfBase64\r\n'
        '--$boundary--';

    // Gmail API needs the raw MIME as base64url without padding
    final raw = base64Url.encode(utf8.encode(mime)).replaceAll('=', '');

    await api.users.messages.send(
      gmail.Message(raw: raw),
      'me',
    );
  }

  static String _wrapBase64(String s) {
    const w = 76;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i += w) {
      final end = (i + w < s.length) ? i + w : s.length;
      buf.writeln(s.substring(i, end));
    }
    return buf.toString().trimRight();
  }
}

class _GmailAuthClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _inner = http.Client();

  _GmailAuthClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final auth = await _account.authentication;
    request.headers['Authorization'] = 'Bearer ${auth.accessToken}';
    return _inner.send(request);
  }
}
