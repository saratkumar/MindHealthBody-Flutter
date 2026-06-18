import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SheetsService {
  static const _spreadsheetId =
      '1o_Ul5dtFUa3DN_1YVuyevF4LiseDq4A5MXyT06cwdF4';

  static const _psaSheet    = 'PSA Results';
  static const _aoqSheet    = 'AOQ Results';
  static const _intakeSheet = 'Intake Submissions';

  static const _intakeHeaders = ['Date', 'Client Email', 'Status'];

  static const _psaHeaders = [
    'Date', 'Client Email',
    'Facilitator', 'Processor', 'Analyser', 'Explorer',
    'Q1_F', 'Q1_P', 'Q1_A', 'Q1_E',
    'Q2_F', 'Q2_P', 'Q2_A', 'Q2_E',
    'Q3_F', 'Q3_P', 'Q3_A', 'Q3_E',
    'Q4_F', 'Q4_P', 'Q4_A', 'Q4_E',
    'Q5_F', 'Q5_P', 'Q5_A', 'Q5_E',
    'Q6_F', 'Q6_P', 'Q6_A', 'Q6_E',
    'Q7_F', 'Q7_P', 'Q7_A', 'Q7_E',
    'Q8_F', 'Q8_P', 'Q8_A', 'Q8_E',
    'Q9_F', 'Q9_P', 'Q9_A', 'Q9_E',
    'Q10_F','Q10_P','Q10_A','Q10_E',
  ];

  static const _aoqHeaders = [
    'Date', 'Client Email',
    'Baseline_O', 'Baseline_S', 'Baseline_T', 'Baseline_A',
    'Stress_O',   'Stress_S',   'Stress_T',   'Stress_A',
    'OGI_%', 'SEI_%',
    'Primary_Baseline', 'Primary_Stress', 'Largest_Delta',
    // raw A items 1-24
    'A1','A2','A3','A4','A5','A6','A7','A8','A9','A10',
    'A11','A12','A13','A14','A15','A16','A17','A18','A19','A20',
    'A21','A22','A23','A24',
    // raw B items 1-24
    'B1','B2','B3','B4','B5','B6','B7','B8','B9','B10',
    'B11','B12','B13','B14','B15','B16','B17','B18','B19','B20',
    'B21','B22','B23','B24',
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<void> appendPSAResult({
    required GoogleSignInAccount account,
    required String clientEmail,
    required DateTime date,
    required Map<String, int> scores,
    required List<List<int?>> ranks,
  }) async {
    final api = await _api(account);
    await _ensureSheet(api, _psaSheet, _psaHeaders);

    final flat = ranks.expand((r) => r.map((v) => (v ?? 0).toString())).toList();
    final row = [
      DateFormat('dd/MM/yyyy HH:mm').format(date),
      clientEmail,
      '${scores['facilitator'] ?? 0}',
      '${scores['processor'] ?? 0}',
      '${scores['analyser'] ?? 0}',
      '${scores['explorer'] ?? 0}',
      ...flat,
    ];

    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [row]),
      _spreadsheetId,
      "'$_psaSheet'!A:A",
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<void> appendAOQResult({
    required GoogleSignInAccount account,
    required String clientEmail,
    required DateTime date,
    required Map<String, int> baseline,
    required Map<String, int> stress,
    required double ogi,
    required double sei,
    required String primaryBaseline,
    required String primaryStress,
    required String largestDelta,
    required List<int?> rawA,
    required List<int?> rawB,
  }) async {
    final api = await _api(account);
    await _ensureSheet(api, _aoqSheet, _aoqHeaders);

    final row = [
      DateFormat('dd/MM/yyyy HH:mm').format(date),
      clientEmail,
      '${baseline['O'] ?? 0}', '${baseline['S'] ?? 0}',
      '${baseline['T'] ?? 0}', '${baseline['A'] ?? 0}',
      '${stress['O'] ?? 0}',   '${stress['S'] ?? 0}',
      '${stress['T'] ?? 0}',   '${stress['A'] ?? 0}',
      (ogi * 100).toStringAsFixed(1),
      (sei * 100).toStringAsFixed(1),
      primaryBaseline,
      primaryStress,
      largestDelta,
      ...rawA.map((v) => (v ?? 0).toString()),
      ...rawB.map((v) => (v ?? 0).toString()),
    ];

    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [row]),
      _spreadsheetId,
      "'$_aoqSheet'!A:A",
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<void> recordIntakeSubmission({
    required GoogleSignInAccount account,
    required String clientEmail,
    required DateTime date,
  }) async {
    final api = await _api(account);
    await _ensureSheet(api, _intakeSheet, _intakeHeaders);
    await api.spreadsheets.values.append(
      sheets.ValueRange(values: [
        [DateFormat('dd/MM/yyyy HH:mm').format(date), clientEmail, 'Submitted'],
      ]),
      _spreadsheetId,
      "'$_intakeSheet'!A:A",
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<bool> checkIntakeSubmitted(
      GoogleSignInAccount account, String clientEmail) async {
    final api = await _api(account);
    final spreadsheet = await api.spreadsheets.get(_spreadsheetId);
    final exists = spreadsheet.sheets
            ?.any((s) => s.properties?.title == _intakeSheet) ??
        false;
    if (!exists) return false;

    final resp = await api.spreadsheets.values.get(
      _spreadsheetId,
      "'$_intakeSheet'!B:B",
    );
    return (resp.values ?? [])
        .any((row) => row.isNotEmpty && row[0].toString() == clientEmail);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<sheets.SheetsApi> _api(GoogleSignInAccount account) async {
    return sheets.SheetsApi(_AuthClient(account));
  }

  static Future<void> _ensureSheet(
    sheets.SheetsApi api,
    String title,
    List<String> headers,
  ) async {
    final spreadsheet =
        await api.spreadsheets.get(_spreadsheetId);
    final existing = spreadsheet.sheets
            ?.map((s) => s.properties?.title ?? '')
            .toList() ??
        [];

    if (!existing.contains(title)) {
      // Create the tab
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
      // Write header row
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: [headers]),
        _spreadsheetId,
        "'$title'!A1",
        valueInputOption: 'RAW',
      );
    }
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
