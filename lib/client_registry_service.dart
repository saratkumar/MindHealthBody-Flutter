import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SessionRecord {
  final String invoiceNumber;
  final DateTime sessionDate;
  final double fee;
  final double lessCHS1;

  SessionRecord({
    required this.invoiceNumber,
    required this.sessionDate,
    required this.fee,
    required this.lessCHS1,
  });
}

class ClientRecord {
  final String clientId; // e.g. "MBP/APR26(SK)/01" — permanent forever
  final String name;
  final String email;
  final String phone;
  final String monthKey; // e.g. "APR26" — month of first session
  final int clientNumber; // sequential within that month
  final List<SessionRecord> sessions;

  ClientRecord({
    required this.clientId,
    required this.name,
    required this.email,
    required this.phone,
    required this.monthKey,
    required this.clientNumber,
    List<SessionRecord>? sessions,
  }) : sessions = sessions ?? [];

  int get sessionCount => sessions.length;
}

/// Client + session registry backed by the shared Google Sheet (Sheets API),
/// so the client ID assigned at intake is visible from any device/account
/// that later generates an invoice for that client.
class ClientRegistryService {
  static const _spreadsheetId =
      '1P8gxkIBHyElXHvinY97JsR8O3gH4CFr1fwZzPhwWV4k';

  static const _clientsSheet = 'Clients';
  static const _sessionsSheet = 'Sessions';
  static const _businessUnit = 'MBP';
  static const _therapistInitials = 'SK';

  static const _clientsHeaders = [
    'Client ID', 'Name', 'Email', 'Phone', 'Month Key', 'Client No',
  ];
  static const _sessionsHeaders = [
    'Client ID', 'Invoice Number', 'Session Date', 'Fee', 'Less CHS1',
  ];

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  // ── Month key ────────────────────────────────────────────────────────────────

  static String monthKey(DateTime date) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final yy = (date.year % 100).toString().padLeft(2, '0');
    return '${months[date.month - 1]}$yy';
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Looks up a client by email only — never creates a row. Used to autofill
  /// an existing Client ID (e.g. on the intake form) without minting a new
  /// permanent ID for someone who hasn't submitted anything yet.
  static Future<ClientRecord?> findByEmail(
    GoogleSignInAccount account,
    String email,
  ) async {
    final api = await _api(account);
    await _ensureSheet(api, _clientsSheet, _clientsHeaders);
    final rows = await _readRows(api, _clientsSheet, _clientsHeaders.length);
    final norm = _normalizeEmail(email);

    for (final row in rows) {
      if (_normalizeEmail(row[2]) == norm) {
        return ClientRecord(
          clientId: row[0],
          name: row[1],
          email: row[2],
          phone: row[3],
          monthKey: row[4],
          clientNumber: int.tryParse(row[5]) ?? 0,
        );
      }
    }
    return null;
  }

  /// Looks up a client by email, creating one (with a fresh MBP ID) if none
  /// exists yet. Does not record a session.
  static Future<ClientRecord> findOrCreateClient(
    GoogleSignInAccount account, {
    required String name,
    required String email,
    required String phone,
    required DateTime referenceDate,
  }) async {
    final api = await _api(account);
    await _ensureSheet(api, _clientsSheet, _clientsHeaders);

    final rows = await _readRows(api, _clientsSheet, _clientsHeaders.length);
    final norm = _normalizeEmail(email);

    for (final row in rows) {
      if (_normalizeEmail(row[2]) == norm) {
        return ClientRecord(
          clientId: row[0],
          name: row[1],
          email: row[2],
          phone: row[3],
          monthKey: row[4],
          clientNumber: int.tryParse(row[5]) ?? 0,
        );
      }
    }

    final key = monthKey(referenceDate);
    final countThisMonth = rows.where((r) => r[4] == key).length;
    final num = countThisMonth + 1;
    final id =
        '$_businessUnit/$key($_therapistInitials)/${num.toString().padLeft(2, '0')}';

    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [
        [id, name, email, phone, key, num.toString()],
      ]),
      _spreadsheetId,
      "'$_clientsSheet'!A:A",
      valueInputOption: 'USER_ENTERED',
    );

    return ClientRecord(
      clientId: id,
      name: name,
      email: email,
      phone: phone,
      monthKey: key,
      clientNumber: num,
    );
  }

  /// Looks up (or creates) a client by email, appends a session, and returns
  /// the updated client (with full session history) + the new invoice number.
  static Future<(ClientRecord, String)> recordSession(
    GoogleSignInAccount account, {
    required String name,
    required String email,
    required String phone,
    required DateTime sessionDate,
    required double fee,
    required double lessCHS1,
  }) async {
    final client = await findOrCreateClient(
      account,
      name: name,
      email: email,
      phone: phone,
      referenceDate: sessionDate,
    );

    final api = await _api(account);
    await _ensureSheet(api, _sessionsSheet, _sessionsHeaders);

    final rows = await _readRows(api, _sessionsSheet, _sessionsHeaders.length);
    final existingSessions = rows
        .where((r) => r[0] == client.clientId)
        .map(_sessionFromRow)
        .toList();

    final sessionNum = existingSessions.length + 1;
    final invoiceNumber =
        '${client.clientId}.${sessionNum.toString().padLeft(2, '0')}';

    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [
        [
          client.clientId,
          invoiceNumber,
          _dateFmt.format(sessionDate),
          fee.toString(),
          lessCHS1.toString(),
        ],
      ]),
      _spreadsheetId,
      "'$_sessionsSheet'!A:A",
      valueInputOption: 'USER_ENTERED',
    );

    final updated = ClientRecord(
      clientId: client.clientId,
      name: client.name,
      email: client.email,
      phone: client.phone,
      monthKey: client.monthKey,
      clientNumber: client.clientNumber,
      sessions: [
        ...existingSessions,
        SessionRecord(
          invoiceNumber: invoiceNumber,
          sessionDate: sessionDate,
          fee: fee,
          lessCHS1: lessCHS1,
        ),
      ],
    );

    return (updated, invoiceNumber);
  }

  /// Reads every client and joins in their full session history.
  static Future<List<ClientRecord>> getAllWithSessions(
    GoogleSignInAccount account,
  ) async {
    final api = await _api(account);
    await _ensureSheet(api, _clientsSheet, _clientsHeaders);
    await _ensureSheet(api, _sessionsSheet, _sessionsHeaders);

    final clientRows = await _readRows(api, _clientsSheet, _clientsHeaders.length);
    final sessionRows = await _readRows(api, _sessionsSheet, _sessionsHeaders.length);

    return clientRows.map((row) {
      final clientId = row[0];
      final sessions = sessionRows
          .where((r) => r[0] == clientId)
          .map(_sessionFromRow)
          .toList();
      return ClientRecord(
        clientId: clientId,
        name: row[1],
        email: row[2],
        phone: row[3],
        monthKey: row[4],
        clientNumber: int.tryParse(row[5]) ?? 0,
        sessions: sessions,
      );
    }).toList();
  }

  static Future<ClientRecord> updateClient(
    GoogleSignInAccount account,
    String clientId, {
    String? name,
    String? phone,
  }) async {
    final api = await _api(account);
    final rows = await _readRows(api, _clientsSheet, _clientsHeaders.length);
    final idx = rows.indexWhere((r) => r[0] == clientId);
    if (idx < 0) throw Exception('Client not found');

    final updatedRow = [
      rows[idx][0],
      name ?? rows[idx][1],
      rows[idx][2],
      phone ?? rows[idx][3],
      rows[idx][4],
      rows[idx][5],
    ];
    rows[idx] = updatedRow;
    await _rewriteSheet(api, _clientsSheet, _clientsHeaders, rows);

    return ClientRecord(
      clientId: updatedRow[0],
      name: updatedRow[1],
      email: updatedRow[2],
      phone: updatedRow[3],
      monthKey: updatedRow[4],
      clientNumber: int.tryParse(updatedRow[5]) ?? 0,
    );
  }

  static Future<void> deleteClient(
    GoogleSignInAccount account,
    String clientId,
  ) async {
    final api = await _api(account);

    final clientRows = await _readRows(api, _clientsSheet, _clientsHeaders.length);
    clientRows.removeWhere((r) => r[0] == clientId);
    await _rewriteSheet(api, _clientsSheet, _clientsHeaders, clientRows);

    final sessionRows = await _readRows(api, _sessionsSheet, _sessionsHeaders.length);
    sessionRows.removeWhere((r) => r[0] == clientId);
    await _rewriteSheet(api, _sessionsSheet, _sessionsHeaders, sessionRows);
  }

  static Future<void> deleteSession(
    GoogleSignInAccount account,
    String clientId,
    String invoiceNumber,
  ) async {
    final api = await _api(account);
    final rows = await _readRows(api, _sessionsSheet, _sessionsHeaders.length);
    rows.removeWhere((r) => r[0] == clientId && r[1] == invoiceNumber);
    await _rewriteSheet(api, _sessionsSheet, _sessionsHeaders, rows);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static Future<sheets.SheetsApi> _api(GoogleSignInAccount account) async {
    return sheets.SheetsApi(_AuthClient(account));
  }

  static SessionRecord _sessionFromRow(List<String> r) => SessionRecord(
        invoiceNumber: r[1],
        sessionDate: _parseDate(r[2]),
        fee: double.tryParse(r[3]) ?? 0,
        lessCHS1: double.tryParse(r[4]) ?? 0,
      );

  static DateTime _parseDate(String s) {
    try {
      return _dateFmt.parseStrict(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  static Future<void> _ensureSheet(
    sheets.SheetsApi api,
    String title,
    List<String> headers,
  ) async {
    final spreadsheet = await api.spreadsheets.get(_spreadsheetId);
    final existing = spreadsheet.sheets
            ?.map((s) => s.properties?.title ?? '')
            .toList() ??
        [];

    if (!existing.contains(title)) {
      await api.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(title: title),
            ),
          ),
        ]),
        _spreadsheetId,
      );
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: [headers]),
        _spreadsheetId,
        "'$title'!A1",
        valueInputOption: 'RAW',
      );
    }
  }

  /// Reads all data rows (excluding the header) as lists of strings, padded
  /// to [width] columns.
  static Future<List<List<String>>> _readRows(
    sheets.SheetsApi api,
    String title,
    int width,
  ) async {
    final resp = await api.spreadsheets.values.get(_spreadsheetId, "'$title'!A2:${_colLetter(width)}");
    final values = resp.values ?? [];
    return values.map((row) {
      final cells = row.map((v) => v?.toString() ?? '').toList();
      while (cells.length < width) {
        cells.add('');
      }
      return cells;
    }).toList();
  }

  static Future<void> _rewriteSheet(
    sheets.SheetsApi api,
    String title,
    List<String> headers,
    List<List<String>> rows,
  ) async {
    final lastCol = _colLetter(headers.length);
    await api.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      _spreadsheetId,
      "'$title'!A2:$lastCol",
    );
    if (rows.isNotEmpty) {
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: rows),
        _spreadsheetId,
        "'$title'!A2",
        valueInputOption: 'USER_ENTERED',
      );
    }
  }

  static String _colLetter(int count) {
    // 1-indexed column letter for column number `count` (A, B, ... Z, AA, ...)
    var n = count;
    var s = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      s = String.fromCharCode(65 + rem) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }
}

class _AuthClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _inner = http.Client();

  _AuthClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final auth = await _account.authentication;
    request.headers['Authorization'] = 'Bearer ${auth.accessToken}';
    return _inner.send(request);
  }
}
