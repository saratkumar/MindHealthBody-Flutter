import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'download_helper.dart';
import 'gmail_service.dart';
import 'intake_form.dart';

// R=0x1A G=0x4B B=0x8C → brand navy blue
const _kBrandBlue = PdfColor(0x1A / 255, 0x4B / 255, 0x8C / 255);

class IntakeFormService {
  /// Sends the PDF by email (to practitioner + CC client) when a Google
  /// account is available.  Falls back to browser download in test mode.
  static Future<void> generateAndSend(
    IntakeForm form, {
    GoogleSignInAccount? account,
  }) async {
    final bytes = await _buildPdf(form);
    final stamp = DateFormat('ddMMyyyy_HHmm').format(form.submittedAt);
    final safe = _safe(form.patientName);
    final filename = '$safe Intake Form $stamp.pdf';

    if (account != null) {
      await GmailService.sendIntakeFormEmail(
        account: account,
        patientName: form.patientName,
        clientEmail: form.email,
        practitionerEmail: form.practitionerEmail,
        practitionerName: form.practitionerName,
        pdfBytes: bytes,
        filename: filename,
        submittedAt: form.submittedAt,
      );
    } else {
      // Test-mode fallback: no Google account available, download PDF instead
      await downloadFile(bytes, filename, 'application/pdf');
    }
  }

  static Future<Uint8List> _buildPdf(IntakeForm form) async {
    final doc = pw.Document();
    final sig1 = form.signatureBytes.isNotEmpty ? pw.MemoryImage(form.signatureBytes) : null;
    final sig2 = form.signature2Bytes.isNotEmpty ? pw.MemoryImage(form.signature2Bytes) : null;

    // Load logo
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/image2.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    // ── Page 1 ──────────────────────────────────────────────────────────────
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header with logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 56, height: 56),
                pw.SizedBox(width: 12),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('The MindBody Practice',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: _kBrandBlue)),
                  pw.SizedBox(height: 3),
                  pw.Text('Client Intake Form',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'All information is strictly confidential and protected by PDPA',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: _kBrandBlue, thickness: 1.5),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Row(children: [
              pw.Text('[Official use – Patient ID: ________________  MHP ID No: ________]',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ]),
          ),
          pw.SizedBox(height: 10),
          _row2('Patient\'s Name (as per NRIC/Passport)', form.patientName,
              'NRIC/ID No', form.nricId),
          _line('Address', form.address),
          _row3('Country', form.country, 'Postal Code', form.postalCode, 'Phone (Mobile)', form.phone),
          _row2('Occupation', form.occupation, 'E-mail', form.email),
          _row3('Birth Date', form.birthDate, 'Sex', form.sex, 'Race', form.race),
          pw.SizedBox(height: 6),
          pw.Text('How were you referred:', style: pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 3),
          pw.Row(children: [
            _checkbox(form.refWebSearch), pw.Text('  Web Search  ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(form.refDoctor),
            pw.Text('  Doctor (Name): ${form.refDoctorName}    ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(form.refFriend),
            pw.Text('  Friend (Name): ${form.refFriendName}', style: pw.TextStyle(fontSize: 9)),
          ]),
          pw.SizedBox(height: 2),
          pw.Row(children: [
            _checkbox(form.refOther), pw.Text('  Other: ${form.refOtherDetails}', style: pw.TextStyle(fontSize: 9)),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('Are you under a GP/Psychiatrist\'s care?  ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(form.underGpCare), pw.Text('  Yes   ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(!form.underGpCare), pw.Text('  No', style: pw.TextStyle(fontSize: 9)),
          ]),
          if (form.underGpCare) ...[
            pw.SizedBox(height: 2),
            pw.Text('  Details: ${form.gpCareDetails}', style: pw.TextStyle(fontSize: 9)),
            _line('Doctor\'s Name', form.gpDoctorName),
          ],
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('Are you taking medication?  ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(!form.takingMedication), pw.Text('  No   ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(form.takingMedication), pw.Text('  Yes, for: ${form.medicationDetails}', style: pw.TextStyle(fontSize: 9)),
          ]),
          pw.SizedBox(height: 4),
          _line('What do you want to accomplish using Psychotherapy?', form.psychotherapyGoals),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('Have you ever been through hypnotherapy in the past?  ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(!form.hadHypnotherapy), pw.Text('  No   ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(form.hadHypnotherapy), pw.Text('  Yes: ${form.hypnotherapyDetails}', style: pw.TextStyle(fontSize: 9)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Text('Do you have any fears/phobias?  ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(!form.hasFearsPhobias), pw.Text('  No   ', style: pw.TextStyle(fontSize: 9)),
            _checkbox(form.hasFearsPhobias), pw.Text('  Yes for: ${form.fearsPhobiasDetails}', style: pw.TextStyle(fontSize: 9)),
          ]),
          pw.SizedBox(height: 8),
          // Contact lenses notice
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _kBrandBlue, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              color: PdfColor.fromInt(0xFFEEF3FB),
            ),
            child: pw.Text(
              'IF YOU WEAR CONTACT LENSES AND CANNOT COMFORTABLY CLOSE YOUR EYES FOR APPROXIMATELY '
              '½ HOUR WITH THEM IN YOUR EYES, PLEASE REMOVE THEM.',
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _kBrandBlue),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(
                'THE SUCCESS OF PSYCHOLOGICAL INTERVENTION WILL REST ON YOUR PERSISTENCE WITH THE PROCESS '
                'AND THE RECOMMENDATION OF YOUR MENTAL HEALTH PROFESSIONAL. I DO AGREE TO PAY S\$180 per '
                'session*/or _____per session as FEE FOR SERVICES RENDERED. SERVICE FEE WILL BE COLLECTED '
                'AT THE END OF EACH SESSION, UNLESS OTHERWISE PREVIOUSLY AGREED UPON WITH THE MENTAL HEALTH '
                'PROFESSIONAL. (*House call will be at \$280/hour)',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'I AGREE TO PAY A \$30.00 CHARGE IF I DO NOT GIVE 24 HOUR NOTICE OF CANCELLATION OF MY '
                'APPOINTMENT, AND THE FULL PRICE OF THE SESSION FOR A NO CALL / NO SHOW.',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('PLEASE INITIAL: ${form.initials}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'I, ${form.consentClientName}, gives permission to the Mental Health Professional (MHP) to work with '
            'me on my mental health condition(s) for the required number of sessions. I indemnify the appointed '
            'MHP against any professional mishap during and after each session. I understand that if I have any '
            'issues with my MHP, I can address it with the General Manager of the Mind body Health Practice at '
            'help@psychologyclinic.sg',
            style: pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Client Signature:', style: pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 4),
                if (sig1 != null)
                  pw.Container(
                    width: 180, height: 60,
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                    child: pw.Image(sig1, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Container(
                    width: 180, height: 60,
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  ),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Date:', style: pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 4),
                pw.Text(form.date, style: pw.TextStyle(fontSize: 10)),
              ]),
            ],
          ),
        ],
      ),
    ));

    // ── Page 2: Confidentiality & Safety Statement ───────────────────────────
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 40, height: 40),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('The MindBody Practice',
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: _kBrandBlue)),
                  pw.Text('Confidentiality & Safety Statement',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: _kBrandBlue, thickness: 1.5),
          pw.SizedBox(height: 10),
          pw.Text(
            'Your privacy is important to us. All information shared during your sessions will be kept strictly '
            'confidential and used only to support your care.',
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'We will not share your information with anyone without your written consent, except in the following situations:',
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 4),
          _bullet('If there is a risk of harm to yourself or others'),
          _bullet('If disclosure is required by law or a court order'),
          _bullet('For professional consultation or supervision (with identifying details kept to a minimum)'),
          pw.SizedBox(height: 8),
          pw.Text(
            'For the safety and protection of both clients and practitioners, video recording (without audio) may '
            'be in place within the consultation room. Cameras are positioned to minimise facial capture (typically '
            'capturing the back or side profile), and facial identification is kept to a minimum.',
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Access to these recordings is restricted solely to the Principal Psychologist. Recordings are securely '
            'stored and will be automatically deleted within 96 hours, unless required for safety, incident review, '
            'or legal obligations.',
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'If you prefer not to be recorded, you may request for the recording system to be turned off prior to '
            'the session. Please note that this may limit our ability to review events in the unlikely situation of '
            'a safety concern.',
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          pw.Text('All records are stored securely in line with professional and ethical standards.',
              style: pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 8),
          pw.Text(
            'By signing below, you acknowledge that you understand and agree to the above.',
            style: pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 24),
          pw.Text('Client Name: ${form.confidentialityClientName}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Text('Signature:', style: pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          if (sig2 != null)
            pw.Container(
              width: 220, height: 70,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Image(sig2, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              width: 220, height: 70,
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
            ),
          pw.Spacer(),
          pw.Text(
            'Submitted: ${DateFormat('dd/MM/yyyy h:mm a').format(form.submittedAt)}  '
            '|  Sent to: ${form.practitionerName} <${form.practitionerEmail}>',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    ));

    return doc.save();
  }

  // ── PDF helpers ─────────────────────────────────────────────────────────────

  static pw.Widget _row2(String l1, String v1, String l2, String v2) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(children: [
        pw.Expanded(child: _field(l1, v1)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _field(l2, v2)),
      ]),
    );
  }

  static pw.Widget _row3(String l1, String v1, String l2, String v2, String l3, String v3) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(children: [
        pw.Expanded(child: _field(l1, v1)),
        pw.SizedBox(width: 6),
        pw.Expanded(child: _field(l2, v2)),
        pw.SizedBox(width: 6),
        pw.Expanded(child: _field(l3, v3)),
      ]),
    );
  }

  static pw.Widget _line(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: _field(label, value),
    );
  }

  static pw.Widget _field(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400))),
          child: pw.Text(value.isEmpty ? ' ' : value, style: pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  static pw.Widget _checkbox(bool checked) {
    return pw.Container(
      width: 10, height: 10,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
        color: checked ? PdfColors.black : PdfColors.white,
      ),
      child: checked
          ? pw.Center(
              child: pw.Text('✓',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.white)))
          : null,
    );
  }

  static pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 16, bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontSize: 9)),
          pw.Expanded(child: pw.Text(text, style: pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static String _safe(String value) {
    final s = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
    return s.isEmpty ? 'Client' : s;
  }
}
