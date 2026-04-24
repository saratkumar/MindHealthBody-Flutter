import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Generates a PDF that reproduces the MBP Invoice Excel Sheet 1 layout.
///
/// Exact cell mapping from the template:
///   F4  = invoiceNumber   H4  = invoiceDate
///   A9  = clientName      A10 = 'HP: ' + clientPhone
///   G16 = fee             H16 = fee
///   G17 = -lessCHS1       H17 = -lessCHS1
///   H31 = total           H34 = total
class InvoicePdfGenerator {
  static final _numFmt = NumberFormat('#,##0.00', 'en_SG');

  static Future<File> generate({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String clientName,
    required String clientPhone,
    required String clientId,      // MHP ID (e.g. MBP/APR26(SK)/01)
    required double fee,
    required double lessCHS1,
  }) async {
    final total = fee - lessCHS1;
    final dateStr = DateFormat('dd/MM/yyyy').format(invoiceDate);

    // Load both images from assets
    final logoBytes = await rootBundle.load('assets/image2.png');
    final qrBytes = await rootBundle.load('assets/image1.jpeg');
    final logoImg = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final qrImg = pw.MemoryImage(qrBytes.buffer.asUint8List());

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 28),
        build: (ctx) => _buildPage(
          logoImg: logoImg,
          qrImg: qrImg,
          invoiceNumber: invoiceNumber,
          invoiceDate: dateStr,
          clientName: clientName,
          clientPhone: clientPhone,
          clientId: clientId,
          fee: fee,
          lessCHS1: lessCHS1,
          total: total,
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final tag = DateFormat('ddMMyy').format(invoiceDate);
    final safe = clientName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    final file = File('${dir.path}/MBP Invoice - $safe $tag.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _buildPage({
    required pw.MemoryImage logoImg,
    required pw.MemoryImage qrImg,
    required String invoiceNumber,
    required String invoiceDate,
    required String clientName,
    required String clientPhone,
    required String clientId,
    required double fee,
    required double lessCHS1,
    required double total,
  }) {
    const blue = PdfColor.fromInt(0xFF1A5CA8);
    const lightGrey = PdfColor.fromInt(0xFFE8E8E8);
    const darkText = PdfColor.fromInt(0xFF1A1A1A);

    final headerLabel = pw.TextStyle(
      fontSize: 7.5,
      color: PdfColors.grey600,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 0.5,
    );
    final headerValue = pw.TextStyle(fontSize: 9, color: darkText);
    final boldValue = pw.TextStyle(
      fontSize: 9,
      color: darkText,
      fontWeight: pw.FontWeight.bold,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Row 1: Logo (left) + "INVOICE" title (right) ────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logoImg, width: 70, height: 70),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'The Mindbody Practice',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: blue,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey300,
                letterSpacing: 2,
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 10),
        pw.Divider(color: blue, thickness: 1.5),
        pw.SizedBox(height: 8),

        // ── Rows 3-5 (left) + Rows 3-4 invoice meta (right) ────────────────
        // This matches: B3=address, F3="INVOICE #", H3="DATE"
        //               F4=invoiceNumber, H4=date
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: business address
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('11 Sin Ming Road, #B1-10, Thomson V Two',
                      style: pw.TextStyle(fontSize: 8.5, color: darkText)),
                  pw.Text('Singapore 575629',
                      style: pw.TextStyle(fontSize: 8.5, color: darkText)),
                  pw.Text('Phone: +65 6492 8697',
                      style: pw.TextStyle(fontSize: 8.5, color: darkText)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            // Right: invoice number (F4) + date (H4)
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    _metaRow('INVOICE #', invoiceNumber,
                        labelStyle: headerLabel, valueStyle: boldValue),
                    pw.SizedBox(height: 5),
                    _metaRow('DATE', invoiceDate,
                        labelStyle: headerLabel, valueStyle: headerValue),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 12),
        pw.Divider(color: lightGrey, thickness: 1),
        pw.SizedBox(height: 8),

        // ── Rows 7-10: BILL TO (left) + MHP ID / TERMS (right) ─────────────
        // A7="BILL TO", F7="MHP ID", H7="TERMS"
        // A9=clientName, A10="HP: phone"
        // F8=clientId, H8="COD"
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BILL TO',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600,
                        letterSpacing: 0.8,
                      )),
                  pw.SizedBox(height: 5),
                  // A9: Client Name
                  pw.Text(clientName,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: darkText,
                      )),
                  // A10: Client phone
                  pw.Text('HP: $clientPhone',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      )),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    _metaRow('MHP ID', clientId,
                        labelStyle: headerLabel, valueStyle: headerValue),
                    pw.SizedBox(height: 5),
                    _metaRow('TERMS', 'COD',
                        labelStyle: headerLabel, valueStyle: headerValue),
                  ],
                ),
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 14),

        // ── Row 15: Table header ─────────────────────────────────────────────
        pw.Container(
          color: blue,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 6,
                child: pw.Text('DESCRIPTION',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5)),
              ),
              pw.SizedBox(
                width: 40,
                child: pw.Text('QTY',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(
                width: 70,
                child: pw.Text('UNIT PRICE',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(
                width: 70,
                child: pw.Text('AMOUNT',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
        ),

        // ── Row 16: Professional Intervention Fee ────────────────────────────
        _tableRow(
          'Professional Intervention Fee',
          qty: '1',
          unitPrice: _numFmt.format(fee),
          amount: _numFmt.format(fee),
          bg: PdfColors.white,
        ),

        // ── Row 17: Less CHS1 ────────────────────────────────────────────────
        _tableRow(
          'Less CHS1',
          qty: '1',
          unitPrice: '(${_numFmt.format(lessCHS1)})',
          amount: '(${_numFmt.format(lessCHS1)})',
          bg: PdfColor.fromInt(0xFFFAFAFA),
        ),

        // Empty rows 18-30 area
        pw.Container(
          height: 20,
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: const pw.BorderSide(color: lightGrey),
              right: const pw.BorderSide(color: lightGrey),
              bottom: const pw.BorderSide(color: lightGrey),
            ),
          ),
        ),

        pw.SizedBox(height: 8),
        pw.Divider(color: lightGrey, thickness: 1),
        pw.SizedBox(height: 8),

        // ── Rows 31-34: Summary (left: notes, right: totals) ─────────────────
        // Row 31: A31="Thank you!", F31="SUBTOTAL", H31=total
        // Row 32: A32=PayNow note, F32="GST RATE", H32=0
        // Row 33: A33=" ", F33="GST", H33=0
        // Row 34: A34=UEN, F34="TOTAL", H34=total
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left: thank you + payment notes
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Thank you!',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: blue,
                      )),
                  pw.SizedBox(height: 4),
                  pw.Text('Payments can be made via PayNow',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text('UEN: 53396439CTV2',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            // Right: SUBTOTAL, GST, TOTAL
            pw.SizedBox(
              width: 220,
              child: pw.Table(
                border: pw.TableBorder(
                  top: const pw.BorderSide(color: lightGrey),
                  bottom: pw.BorderSide(color: blue, width: 1.5),
                  horizontalInside: const pw.BorderSide(color: lightGrey),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  _summaryRow('SUBTOTAL', _numFmt.format(total)),
                  _summaryRow('GST RATE', '0%'),
                  _summaryRow('GST', '0.00'),
                  _summaryRow('TOTAL', _numFmt.format(total), bold: true),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 12),
        pw.Divider(color: lightGrey, thickness: 1),
        pw.SizedBox(height: 6),

        // ── Row 35: Org note ─────────────────────────────────────────────────
        pw.Text(
          'The Mindbody Practice is an entity associated with The Psychology Clinic (Singapore)',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),

        // ── Rows 37-38: Contact ──────────────────────────────────────────────
        pw.Text(
          'If you have any questions about this invoice, please contact',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.Text(
          '[The Admin Manager, help@psychologyclinic.sg]',
          style: pw.TextStyle(fontSize: 7.5, color: blue),
        ),

        pw.Spacer(),

        // ── Row 41: Remarks + PayNow QR ──────────────────────────────────────
        pw.Divider(color: lightGrey, thickness: 1),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Remarks:',
                    style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text('_______________________________',
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey400)),
                pw.SizedBox(height: 4),
                pw.Text('_______________________________',
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey400)),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(qrImg, width: 70, height: 70),
                pw.SizedBox(height: 3),
                pw.Text('Scan to PayNow',
                    style: pw.TextStyle(
                        fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Layout helpers ──────────────────────────────────────────────────────────

  static pw.Widget _metaRow(
    String label,
    String value, {
    required pw.TextStyle labelStyle,
    required pw.TextStyle valueStyle,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: labelStyle),
        pw.Text(value, style: valueStyle),
      ],
    );
  }

  static pw.Widget _tableRow(
    String description, {
    required String qty,
    required String unitPrice,
    required String amount,
    required PdfColor bg,
  }) {
    const style = pw.TextStyle(fontSize: 8.5);
    return pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 6, child: pw.Text(description, style: style)),
          pw.SizedBox(
              width: 40,
              child: pw.Text(qty,
                  textAlign: pw.TextAlign.center, style: style)),
          pw.SizedBox(
              width: 70,
              child: pw.Text(unitPrice,
                  textAlign: pw.TextAlign.right, style: style)),
          pw.SizedBox(
              width: 70,
              child: pw.Text(amount,
                  textAlign: pw.TextAlign.right, style: style)),
        ],
      ),
    );
  }

  static pw.TableRow _summaryRow(String label, String value,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 9.5 : 8.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: bold
          ? PdfColor.fromInt(0xFF1A5CA8)
          : PdfColor.fromInt(0xFF333333),
    );
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(label, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(value,
              textAlign: pw.TextAlign.right, style: style),
        ),
      ],
    );
  }
}
