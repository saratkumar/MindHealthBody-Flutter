import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class InvoiceItem {
  final String description;
  final double qty;
  final double unitPrice;

  const InvoiceItem({
    required this.description,
    required this.qty,
    required this.unitPrice,
  });

  double get amount => qty * unitPrice;
}

/// Generates a PDF that reproduces the MBP Invoice Excel Sheet 1 layout.
class InvoicePdfGenerator {
  static final _numFmt = NumberFormat('#,##0.00', 'en_SG');

  /// Returns the rendered invoice PDF as bytes (no file-system access, so
  /// this works on every platform including Flutter Web).
  static Future<Uint8List> generate({
    required String invoiceNumber,
    required DateTime invoiceDate,
    required String clientName,
    required String clientPhone,
    required String clientId,
    required List<InvoiceItem> items,
  }) async {
    final total = items.fold<double>(0, (s, i) => s + i.amount);
    final dateStr = DateFormat('dd/MM/yyyy').format(invoiceDate);

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
          items: items,
          total: total,
        ),
      ),
    );

    return pdf.save();
  }

  /// Filename to use when sharing/downloading the generated invoice PDF.
  static String filename(String clientName, DateTime invoiceDate) {
    final tag = DateFormat('ddMMyy').format(invoiceDate);
    final safe = clientName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    return 'MBP Invoice - $safe $tag.pdf';
  }

  static pw.Widget _buildPage({
    required pw.MemoryImage logoImg,
    required pw.MemoryImage qrImg,
    required String invoiceNumber,
    required String invoiceDate,
    required String clientName,
    required String clientPhone,
    required String clientId,
    required List<InvoiceItem> items,
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
        // ── Logo + INVOICE title ─────────────────────────────────────────────
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

        // ── Business address + Invoice meta ──────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
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
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

        // ── BILL TO + MHP ID / TERMS ─────────────────────────────────────────
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
                  pw.Text(clientName,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: darkText,
                      )),
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
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

        // ── Table header ─────────────────────────────────────────────────────
        pw.Container(
          color: blue,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

        // ── Dynamic item rows ────────────────────────────────────────────────
        ...items.asMap().entries.map((entry) => _tableRow(
              entry.value.description,
              qty: _numFmt.format(entry.value.qty),
              unitPrice: _numFmt.format(entry.value.unitPrice),
              amount: _numFmt.format(entry.value.amount),
              bg: entry.key.isEven
                  ? PdfColors.white
                  : PdfColor.fromInt(0xFFFAFAFA),
            )),

        pw.Container(
          height: 12,
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

        // ── Totals section ───────────────────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
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
                      style:
                          pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text('UEN: 53396439CTV2',
                      style:
                          pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
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

        pw.Text(
          'The Mindbody Practice is an entity associated with The Psychology Clinic (Singapore)',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'If you have any questions about this invoice, please contact',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.Text(
          '[The Admin Manager, help@psychologyclinic.sg]',
          style: pw.TextStyle(fontSize: 7.5, color: blue),
        ),

        pw.Spacer(),

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
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
                pw.SizedBox(height: 4),
                pw.Text('_______________________________',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(qrImg, width: 70, height: 70),
                pw.SizedBox(height: 3),
                pw.Text('Scan to PayNow',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      ],
    );
  }

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
              child:
                  pw.Text(qty, textAlign: pw.TextAlign.center, style: style)),
          pw.SizedBox(
              width: 70,
              child: pw.Text(unitPrice,
                  textAlign: pw.TextAlign.right, style: style)),
          pw.SizedBox(
              width: 70,
              child:
                  pw.Text(amount, textAlign: pw.TextAlign.right, style: style)),
        ],
      ),
    );
  }

  static pw.TableRow _summaryRow(String label, String value,
      {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 9.5 : 8.5,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: bold ? PdfColor.fromInt(0xFF1A5CA8) : PdfColor.fromInt(0xFF333333),
    );
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(label, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(value, textAlign: pw.TextAlign.right, style: style),
        ),
      ],
    );
  }
}
