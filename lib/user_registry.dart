import 'firebase_registry_service.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'client' | 'practitioner'
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  AppUser copyWith({String? name, String? email, String? role}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        createdAt: createdAt,
      );
}

/// All calls go to Firestore via [FirebaseRegistryService].
class UserRegistryService {
  static Future<List<AppUser>> getAll() =>
      FirebaseRegistryService.getAll();

  static Future<void> add(AppUser user) =>
      FirebaseRegistryService.add(user);

  static Future<void> update(AppUser updated) =>
      FirebaseRegistryService.update(updated);

  static Future<void> delete(String id) =>
      FirebaseRegistryService.delete(id);

  static Future<AppUser?> findByEmail(String email) =>
      FirebaseRegistryService.findByEmail(email);

  static Future<List<AppUser>> getPractitioners() async {
    final all = await getAll();
    return all.where((u) => u.role == 'practitioner').toList();
  }

  static Future<List<AppUser>> getAdmins() async {
    final all = await getAll();
    return all.where((u) => u.role == 'admin').toList();
  }
}
