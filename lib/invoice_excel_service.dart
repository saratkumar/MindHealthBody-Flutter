import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Fills the MBP invoice Excel template (Sheet 1) with invoice data and
/// returns the resulting workbook as bytes — no file-system access, so this
/// works on every platform including Flutter Web.
class InvoiceExcelService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static Future<Uint8List> writeInvoice({
    required String invoiceNumber,
    required DateTime sessionDate,
    required String clientId,
    required String clientName,
    required String clientPhone,
    required double fee,
    required double lessCHS1,
  }) async {
    final templateBytes = await rootBundle.load('assets/invoice_template.xlsx');
    final excel = Excel.decodeBytes(templateBytes.buffer.asUint8List());

    final total = fee - lessCHS1;
    final dateStr = _dateFmt.format(sessionDate);

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

    return Uint8List.fromList(excel.encode()!);
  }

  /// Filename to use when sharing/downloading the generated invoice workbook.
  static String filename(String clientName, DateTime sessionDate) {
    final tag = DateFormat('ddMMyy').format(sessionDate);
    final safe = clientName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    return 'MBP Invoice - $safe $tag.xlsx';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static void _setCell(Sheet sheet, String ref, String value) {
    sheet.cell(CellIndex.indexByString(ref)).value = TextCellValue(value);
  }

  static void _setNum(Sheet sheet, String ref, double value) {
    sheet.cell(CellIndex.indexByString(ref)).value = DoubleCellValue(value);
  }
}
