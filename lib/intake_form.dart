import 'dart:typed_data';

class IntakeForm {
  final String patientName; // as per NRIC/Passport
  final String nricId;
  final String address;
  final String country;
  final String postalCode;
  final String phone;
  final String occupation;
  final String email;
  final String birthDate;
  final String sex; // 'M' | 'F' | ''
  final String race;

  // Referral
  final bool refWebSearch;
  final bool refDoctor;
  final String refDoctorName;
  final bool refFriend;
  final String refFriendName;
  final bool refOther;
  final String refOtherDetails;

  // Medical
  final bool underGpCare;
  final String gpCareDetails;
  final String gpDoctorName;
  final bool takingMedication;
  final String medicationDetails;

  // Goals & history
  final String psychotherapyGoals;
  final bool hadHypnotherapy;
  final String hypnotherapyDetails;
  final bool hasFearsPhobias;
  final String fearsPhobiasDetails;

  // Consent page 1
  final String initials;
  final String consentClientName;
  final String date;
  final Uint8List signatureBytes;

  // Confidentiality page 2
  final String confidentialityClientName;
  final Uint8List signature2Bytes;

  final DateTime submittedAt;
  final String practitionerEmail;
  final String practitionerName;

  const IntakeForm({
    required this.patientName,
    required this.nricId,
    required this.address,
    required this.country,
    required this.postalCode,
    required this.phone,
    required this.occupation,
    required this.email,
    required this.birthDate,
    required this.sex,
    required this.race,
    required this.refWebSearch,
    required this.refDoctor,
    required this.refDoctorName,
    required this.refFriend,
    required this.refFriendName,
    required this.refOther,
    required this.refOtherDetails,
    required this.underGpCare,
    required this.gpCareDetails,
    required this.gpDoctorName,
    required this.takingMedication,
    required this.medicationDetails,
    required this.psychotherapyGoals,
    required this.hadHypnotherapy,
    required this.hypnotherapyDetails,
    required this.hasFearsPhobias,
    required this.fearsPhobiasDetails,
    required this.initials,
    required this.consentClientName,
    required this.date,
    required this.signatureBytes,
    required this.confidentialityClientName,
    required this.signature2Bytes,
    required this.submittedAt,
    required this.practitionerEmail,
    required this.practitionerName,
  });
}
