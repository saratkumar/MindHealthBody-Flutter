import 'package:cloud_firestore/cloud_firestore.dart';

class UserRequest {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'client' | 'practitioner'
  final String note;
  final String requestedByName;
  final String requestedByEmail;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decidedByEmail;

  const UserRequest({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.note,
    required this.requestedByName,
    required this.requestedByEmail,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.decidedByEmail,
  });
}

class UserRequestService {
  static final _col = FirebaseFirestore.instance.collection('user_requests');

  static Future<void> submit({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String note,
    required String requestedByName,
    required String requestedByEmail,
  }) async {
    await _col.add({
      'name': name,
      'email': email.toLowerCase(),
      'phone': phone,
      'role': role,
      'note': note,
      'requestedByName': requestedByName,
      'requestedByEmail': requestedByEmail.toLowerCase(),
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });
  }

  static Future<List<UserRequest>> getPending() async {
    final snapshot = await _col
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  static Future<List<UserRequest>> getAll() async {
    final snapshot = await _col.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  static Future<void> approve(UserRequest request, String decidedByEmail) async {
    await _col.doc(request.id).update({
      'status': 'approved',
      'decidedAt': Timestamp.now(),
      'decidedByEmail': decidedByEmail.toLowerCase(),
    });
  }

  static Future<void> reject(UserRequest request, String decidedByEmail) async {
    await _col.doc(request.id).update({
      'status': 'rejected',
      'decidedAt': Timestamp.now(),
      'decidedByEmail': decidedByEmail.toLowerCase(),
    });
  }

  static UserRequest _fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserRequest(
      id: doc.id,
      name: d['name'] as String,
      email: d['email'] as String,
      phone: d['phone'] as String,
      role: d['role'] as String,
      note: d['note'] as String? ?? '',
      requestedByName: d['requestedByName'] as String,
      requestedByEmail: d['requestedByEmail'] as String,
      status: d['status'] as String,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      decidedByEmail: d['decidedByEmail'] as String?,
    );
  }
}
