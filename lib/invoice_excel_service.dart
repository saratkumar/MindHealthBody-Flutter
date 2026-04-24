import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'client_database.dart';

/// Manages the invoice Excel workbook kept on device.
///
/// Sheet 1 ("Sheet1"): The invoice template — filled fresh for each invoice.
/// Sheet 2 ("Clients"): Cumulative client/session history (our database).
class InvoiceExcelService {
  static const _workingFileName = 'MBP_Invoices.xlsx';
  static const _clientsSheet = 'Clients';
  static final _currFmt = NumberFormat('#,##,##0.00', 'en_IN');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  // ── File bootstrap ──────────────────────────────────────────────────────────

  /// Path to the on-device working copy of the workbook.
  static Future<String> get _workingPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_workingFileName';
  }

  /// Returns the working Excel file, copying the bundled template on first run.
  static Future<File> get workingFile async {
    final path = await _workingPath;
    final file = File(path);
    if (!file.existsSync()) {
      final bytes = await rootBundle.load('assets/invoice_template.xlsx');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      // Add the Clients sheet to the freshly copied template
      await _ensureClientsSheet(file);
    }
    return file;
  }

  static Future<void> _ensureClientsSheet(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (!excel.tables.containsKey(_clientsSheet)) {
      final sheet = excel[_clientsSheet];
      sheet.appendRow([
        TextCellValue('Client ID'),
        TextCellValue('Name'),
        TextCellValue('Phone'),
        TextCellValue('Month Key'),
        TextCellValue('Client No'),
        TextCellValue('Total Sessions'),
        TextCellValue('Last Invoice'),
        TextCellValue('Last Date'),
        TextCellValue('Fee'),
        TextCellValue('Less CHS1'),
      ]);
      await file.writeAsBytes(excel.encode()!);
    }
  }

  // ── Invoice generation ──────────────────────────────────────────────────────

  /// Fills Sheet 1 with invoice data, upserts client row in Sheet 2,
  /// and saves a named copy ("MBP Invoice - Name Date.xlsx").
  /// Returns the named invoice file.
  static Future<File> writeInvoice({
    required String invoiceNumber,
    required DateTime sessionDate,
    required String clientId,
    required String clientName,
    required String clientPhone,
    required String monthKey,
    required int clientNumber,
    required int totalSessions,
    required double fee,
    required double lessCHS1,
  }) async {
    final file = await workingFile;
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final total = fee - lessCHS1;
    final dateStr = _dateFmt.format(sessionDate);

    // ── Sheet 1: Fill invoice cells ──────────────────────────────────────────
    // The template's first sheet name may be "Sheet1" or "Invoice" — use first.
    final sheetName = excel.tables.keys.first;
    final inv = excel[sheetName];

    _setCell(inv, 'F4', invoiceNumber);
    _setCell(inv, 'H4', dateStr);
    _setCell(inv, 'A9', clientName);
    _setCell(inv, 'A10', 'HP: $clientPhone');
    _setNum(inv, 'G16', fee);
    _setNum(inv, 'H16', fee);
    _setNum(inv, 'G17', -lessCHS1);
    _setNum(inv, 'H17', -lessCHS1);
    // Update totals (rows 31 & 34 in the template)
    _setNum(inv, 'H31', total);
    _setNum(inv, 'H34', total);

    // ── Sheet 2: Upsert client row ───────────────────────────────────────────
    await _ensureClientsSheet(file); // noop if already present
    final cl = excel[_clientsSheet];
    int existingRow = -1;
    for (int i = 1; i < cl.rows.length; i++) {
      if (cl.rows[i].isNotEmpty &&
          cl.rows[i][0]?.value?.toString() == clientId) {
        existingRow = i;
        break;
      }
    }

    final rowData = <CellValue>[
      TextCellValue(clientId),
      TextCellValue(clientName),
      TextCellValue(clientPhone),
      TextCellValue(monthKey),
      IntCellValue(clientNumber),
      IntCellValue(totalSessions),
      TextCellValue(invoiceNumber),
      TextCellValue(dateStr),
      DoubleCellValue(fee),
      DoubleCellValue(lessCHS1),
    ];

    if (existingRow >= 0) {
      for (int col = 0; col < rowData.length; col++) {
        cl.cell(CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: existingRow,
        )).value = rowData[col];
      }
    } else {
      cl.appendRow(rowData);
    }

    // ── Save master workbook ─────────────────────────────────────────────────
    final encoded = excel.encode()!;
    await file.writeAsBytes(encoded);

    // ── Save named invoice copy ──────────────────────────────────────────────
    final dir = await getApplicationDocumentsDirectory();
    final tag = DateFormat('ddMMyy').format(sessionDate);
    final safe = clientName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    final copy = File('${dir.path}/MBP Invoice - $safe $tag.xlsx');
    await copy.writeAsBytes(encoded);

    return copy;
  }

  // ── Clients sheet sync ──────────────────────────────────────────────────────

  /// Rewrites the entire Clients sheet from the current client list.
  /// Call this after any CRUD operation on clients.
  static Future<void> syncClientsSheet(List<ClientRecord> clients) async {
    final file = await workingFile;
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    excel.delete(_clientsSheet);
    final cl = excel[_clientsSheet];

    cl.appendRow([
      TextCellValue('Client ID'),
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Month Key'),
      TextCellValue('Client No'),
      TextCellValue('Total Sessions'),
      TextCellValue('Last Invoice'),
      TextCellValue('Last Date'),
      TextCellValue('Fee'),
      TextCellValue('Less CHS1'),
    ]);

    for (final client in clients) {
      final last = client.sessions.isNotEmpty ? client.sessions.last : null;
      cl.appendRow([
        TextCellValue(client.clientId),
        TextCellValue(client.name),
        TextCellValue(client.phone),
        TextCellValue(client.monthKey),
        IntCellValue(client.clientNumber),
        IntCellValue(client.sessionCount),
        TextCellValue(last?.invoiceNumber ?? ''),
        TextCellValue(last != null ? _dateFmt.format(last.sessionDate) : ''),
        DoubleCellValue(last?.fee ?? 0),
        DoubleCellValue(last?.lessCHS1 ?? 0),
      ]);
    }

    await file.writeAsBytes(excel.encode()!);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static void _setCell(Sheet sheet, String ref, String value) {
    sheet.cell(CellIndex.indexByString(ref)).value = TextCellValue(value);
  }

  static void _setNum(Sheet sheet, String ref, double value) {
    sheet.cell(CellIndex.indexByString(ref)).value = DoubleCellValue(value);
  }

  // ignore: unused_element
  static String _fmt(double v) => '₹${_currFmt.format(v)}';
}
