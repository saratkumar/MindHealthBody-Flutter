import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'intake_form.dart';

class IntakeFormService {
  static const wordMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  static Future<SubmittedIntakeFiles> submit(IntakeForm form) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('ddMMyyyy_HHmm').format(form.submittedAt);
    final safeName = _safeFileName(form.fullName);
    final wordPath = '${dir.path}/$safeName Intake Form $stamp.docx';
    final pdfPath = '${dir.path}/$safeName Intake Form $stamp.pdf';

    await _writeWord(form, wordPath);
    await _writePdf(form, pdfPath);

    return SubmittedIntakeFiles(wordPath: wordPath, pdfPath: pdfPath);
  }

  static Future<void> openWord(String path) async {
    final result = await OpenFile.open(path, type: wordMimeType);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  static Future<void> sendEmail({
    required String recipientEmail,
    required IntakeForm form,
    required SubmittedIntakeFiles files,
  }) async {
    final email = Email(
      subject: 'Signed Intake Form - ${form.fullName}',
      recipients: [recipientEmail],
      body:
          'Please find attached the signed client intake form for ${form.fullName}.\n\nSubmitted: ${DateFormat('dd/MM/yyyy h:mm a').format(form.submittedAt)}',
      attachmentPaths: [files.pdfPath],
      isHTML: false,
    );

    await FlutterEmailSender.send(email);
  }

  static Future<void> _writeWord(IntakeForm form, String path) async {
    final hasSignature = form.signatureBytes.isNotEmpty;
    final archive = Archive();

    archive.addFile(ArchiveFile.string(
      '[Content_Types].xml',
      _contentTypes(hasSignature: hasSignature),
    ));
    archive.addFile(ArchiveFile.string('_rels/.rels', _packageRels()));
    archive
        .addFile(ArchiveFile.string('word/document.xml', _documentXml(form)));
    archive.addFile(ArchiveFile.string('word/styles.xml', _stylesXml()));
    archive.addFile(ArchiveFile.string('docProps/core.xml', _coreXml(form)));
    archive.addFile(ArchiveFile.string('docProps/app.xml', _appXml()));
    archive.addFile(ArchiveFile.string(
      'word/_rels/document.xml.rels',
      _documentRels(hasSignature: hasSignature),
    ));

    if (hasSignature) {
      archive.addFile(ArchiveFile(
        'word/media/image1.png',
        form.signatureBytes.length,
        form.signatureBytes,
      ));
    }

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw Exception('Could not create Word document');

    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(bytes));
  }

  static Future<void> _writePdf(IntakeForm form, String path) async {
    final pdf = pw.Document();
    final signature = form.signatureBytes.isNotEmpty
        ? pw.MemoryImage(form.signatureBytes)
        : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'Client Intake Form',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'The Mindbody Practice',
              style: pw.TextStyle(
                fontSize: 13,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Submitted: ${DateFormat('dd/MM/yyyy h:mm a').format(form.submittedAt)}',
              style: pw.TextStyle(color: PdfColors.grey600),
            ),
            pw.Divider(),
            pw.SizedBox(height: 12),
            _pdfField('Full name', form.fullName),
            _pdfField('Email', form.email),
            _pdfField('Phone', form.phone),
            _pdfField('Date of birth', form.dateOfBirth),
            _pdfField('Gender', form.gender),
            _pdfField('Occupation', form.occupation),
            _pdfField('Address', form.address),
            _pdfField('Emergency contact', form.emergencyContactName),
            _pdfField('Emergency contact phone', form.emergencyContactPhone),
            _pdfField('Presenting concern', form.presentingConcern),
            _pdfField('Medical history', form.medicalHistory),
            _pdfField('Medications', form.medications),
            _pdfField('Allergies', form.allergies),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Declaration',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'I confirm that the information provided is true and correct. I consent to the collection and use of this information for clinical intake and appointment purposes.',
                    style: pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Consent: ${form.consentAccepted ? 'Accepted' : 'Not accepted'}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Digital Signature',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            if (signature != null)
              pw.Container(
                height: 90,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Center(
                    child: pw.Image(signature, fit: pw.BoxFit.contain)),
              )
            else
              pw.Text('No signature captured'),
          ],
        ),
      ),
    );

    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(await pdf.save());
  }

  static pw.Widget _pdfField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value.isEmpty ? '-' : value,
            style: pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static String _documentXml(IntakeForm form) {
    final submitted = DateFormat('dd/MM/yyyy h:mm a').format(form.submittedAt);
    final rows = [
      _tableRow('Full name', form.fullName),
      _tableRow('Email', form.email),
      _tableRow('Phone', form.phone),
      _tableRow('Date of birth', form.dateOfBirth),
      _tableRow('Gender', form.gender),
      _tableRow('Occupation', form.occupation),
      _tableRow('Address', form.address),
      _tableRow('Emergency contact', form.emergencyContactName),
      _tableRow('Emergency contact phone', form.emergencyContactPhone),
      _tableRow('Presenting concern', form.presentingConcern),
      _tableRow('Medical history', form.medicalHistory),
      _tableRow('Medications', form.medications),
      _tableRow('Allergies', form.allergies),
    ].join();

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${_paragraph('Client Intake Form', bold: true, center: true, size: 36)}
    ${_paragraph('The Mindbody Practice', center: true, size: 24)}
    ${_paragraph('Submitted: $submitted', center: true)}
    <w:tbl>
      <w:tblPr>
        <w:tblW w:w="0" w:type="auto"/>
        <w:tblBorders>
          <w:top w:val="single" w:sz="4" w:space="0" w:color="D9D9D9"/>
          <w:left w:val="single" w:sz="4" w:space="0" w:color="D9D9D9"/>
          <w:bottom w:val="single" w:sz="4" w:space="0" w:color="D9D9D9"/>
          <w:right w:val="single" w:sz="4" w:space="0" w:color="D9D9D9"/>
          <w:insideH w:val="single" w:sz="4" w:space="0" w:color="D9D9D9"/>
          <w:insideV w:val="single" w:sz="4" w:space="0" w:color="D9D9D9"/>
        </w:tblBorders>
      </w:tblPr>
      $rows
    </w:tbl>
    <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>
    ${_paragraph('Declaration', bold: true, size: 24)}
    ${_paragraph('I confirm that the information provided is true and correct. I consent to the collection and use of this information for clinical intake and appointment purposes.')}
    ${_paragraph('Consent: ${form.consentAccepted ? 'Accepted' : 'Not accepted'}', bold: true)}
    <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>
    ${_paragraph('Digital Signature', bold: true, size: 24)}
    ${form.signatureBytes.isNotEmpty ? _signatureDrawingXml() : _paragraph('No signature captured')}
    <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>
  </w:body>
</w:document>''';
  }

  static String _tableRow(String label, String value) {
    return '''<w:tr>
      <w:tc>
        <w:tcPr>
          <w:tcW w:w="3400" w:type="dxa"/>
          <w:shd w:fill="E8F0FE"/>
        </w:tcPr>
        <w:p><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">${_xml(label)}</w:t></w:r></w:p>
      </w:tc>
      <w:tc>
        <w:p><w:r><w:t xml:space="preserve">${_xml(value)}</w:t></w:r></w:p>
      </w:tc>
    </w:tr>''';
  }

  static String _signatureDrawingXml() {
    return '''<w:p>
      <w:r>
        <w:drawing>
          <w:inline xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" distT="0" distB="0" distL="0" distR="0">
            <w:extent cx="3600000" cy="1200000"/>
            <w:effectExtent l="0" t="0" r="0" b="0"/>
            <w:docPr id="1" name="signature.png" descr="Digital signature"/>
            <w:cNvGraphicFramePr/>
            <a:graphic>
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic>
                  <pic:nvPicPr>
                    <pic:cNvPr id="1" name="signature.png"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="rId2" cstate="print"/>
                    <a:stretch><a:fillRect/></a:stretch>
                  </pic:blipFill>
                  <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="3600000" cy="1200000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </w:inline>
        </w:drawing>
      </w:r>
    </w:p>''';
  }

  static String _paragraph(
    String text, {
    bool bold = false,
    bool center = false,
    int size = 22,
  }) {
    final justify = center ? '<w:pPr><w:jc w:val="center"/></w:pPr>' : '';
    final rPr = bold ? '<w:rPr><w:b/><w:sz w:val="$size"/></w:rPr>' : '';
    return '<w:p>$justify<w:r>$rPr<w:t xml:space="preserve">${_xml(text)}</w:t></w:r></w:p>';
  }

  static String _contentTypes({required bool hasSignature}) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>${hasSignature ? '\n  <Override PartName="/word/media/image1.png" ContentType="image/png"/>' : ''}
</Types>''';
  }

  static String _packageRels() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';
  }

  static String _documentRels({required bool hasSignature}) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>${hasSignature ? '\n  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>' : ''}
</Relationships>''';
  }

  static String _stylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="22"/></w:rPr>
  </w:style>
</w:styles>''';
  }

  static String _coreXml(IntakeForm form) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Client Intake Form</dc:title>
  <dc:creator>BookMe</dc:creator>
  <cp:lastModifiedBy>BookMe</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">${form.submittedAt.toUtc().toIso8601String()}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">${form.submittedAt.toUtc().toIso8601String()}</dcterms:modified>
  <dc:subject>${_xml(form.fullName)}</dc:subject>
</cp:coreProperties>''';
  }

  static String _appXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>BookMe</Application>
</Properties>''';
  }

  static String _safeFileName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    return safe.isEmpty ? 'Client' : safe;
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
