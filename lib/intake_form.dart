import 'dart:typed_data';

class IntakeForm {
  final String fullName;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final String occupation;
  final String address;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String presentingConcern;
  final String medicalHistory;
  final String medications;
  final String allergies;
  final bool consentAccepted;
  final Uint8List signatureBytes;
  final DateTime submittedAt;

  const IntakeForm({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.occupation,
    required this.address,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.presentingConcern,
    required this.medicalHistory,
    required this.medications,
    required this.allergies,
    required this.consentAccepted,
    required this.signatureBytes,
    required this.submittedAt,
  });
}

class SubmittedIntakeFiles {
  final String wordPath;
  final String pdfPath;

  const SubmittedIntakeFiles({
    required this.wordPath,
    required this.pdfPath,
  });
}
