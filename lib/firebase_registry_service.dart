import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_registry.dart';

class FirebaseRegistryService {
  static final _col =
      FirebaseFirestore.instance.collection('mbp_users');

  static Future<List<AppUser>> getAll() async {
    final snapshot = await _col.orderBy('createdAt').get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  static Future<void> add(AppUser user) async {
    await _col.doc(user.id).set(_toMap(user));
  }

  static Future<void> update(AppUser updated) async {
    await _col.doc(updated.id).update(_toMap(updated));
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  static Future<AppUser?> findByEmail(String email) async {
    final lower = email.toLowerCase().trim();
    final snapshot = await _col
        .where('email', isEqualTo: lower)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _fromDoc(snapshot.docs.first);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static AppUser _fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: d['name'] as String,
      email: d['email'] as String,
      role: d['role'] as String,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  static Map<String, dynamic> _toMap(AppUser u) => {
        'name': u.name,
        'email': u.email.toLowerCase(),
        'role': u.role,
        'createdAt': Timestamp.fromDate(u.createdAt),
      };
}
