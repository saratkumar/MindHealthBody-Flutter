import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionRecord {
  final String invoiceNumber;
  final DateTime sessionDate;
  final double fee;
  final double lessCHS1;

  SessionRecord({
    required this.invoiceNumber,
    required this.sessionDate,
    required this.fee,
    required this.lessCHS1,
  });

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'sessionDate': sessionDate.toIso8601String(),
        'fee': fee,
        'lessCHS1': lessCHS1,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        invoiceNumber: j['invoiceNumber'] as String,
        sessionDate: DateTime.parse(j['sessionDate'] as String),
        fee: (j['fee'] as num).toDouble(),
        lessCHS1: (j['lessCHS1'] as num).toDouble(),
      );
}

class ClientRecord {
  final String clientId; // e.g. "MBP/APR26(SK)/01" — permanent forever
  final String name;
  final String phone;
  final String monthKey; // e.g. "APR26" — month of first session
  final int clientNumber; // sequential within that month
  final List<SessionRecord> sessions;

  ClientRecord({
    required this.clientId,
    required this.name,
    required this.phone,
    required this.monthKey,
    required this.clientNumber,
    List<SessionRecord>? sessions,
  }) : sessions = sessions ?? [];

  int get sessionCount => sessions.length;

  ClientRecord addSession(SessionRecord s) => ClientRecord(
        clientId: clientId,
        name: name,
        phone: phone,
        monthKey: monthKey,
        clientNumber: clientNumber,
        sessions: [...sessions, s],
      );

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'name': name,
        'phone': phone,
        'monthKey': monthKey,
        'clientNumber': clientNumber,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory ClientRecord.fromJson(Map<String, dynamic> j) => ClientRecord(
        clientId: j['clientId'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        monthKey: j['monthKey'] as String,
        clientNumber: j['clientNumber'] as int,
        sessions: (j['sessions'] as List<dynamic>)
            .map((s) => SessionRecord.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class ClientDatabase {
  static const _prefsKey = 'mbp_clients_v1';
  static const _businessUnit = 'MBP';
  static const _therapistInitials = 'SK';

  static Future<List<ClientRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => ClientRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _saveAll(List<ClientRecord> clients) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(clients.map((c) => c.toJson()).toList()),
    );
  }

  // "APR26", "MAY26", etc.
  static String monthKey(DateTime date) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final yy = (date.year % 100).toString().padLeft(2, '0');
    return '${months[date.month - 1]}$yy';
  }

  static String _normalize(String phone) =>
      phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

  static ClientRecord? findByPhone(List<ClientRecord> all, String phone) {
    final norm = _normalize(phone);
    for (final c in all) {
      if (_normalize(c.phone) == norm) return c;
    }
    return null;
  }

  /// Looks up (or creates) a client by phone, appends a session, persists,
  /// and returns the updated client + the new invoice number.
  static Future<(ClientRecord, String)> recordSession({
    required String name,
    required String phone,
    required DateTime sessionDate,
    required double fee,
    required double lessCHS1,
  }) async {
    final clients = await loadAll();
    ClientRecord? client = findByPhone(clients, phone);
    int existingIndex = -1;

    if (client == null) {
      // New client — assign next sequential number for this month
      final key = monthKey(sessionDate);
      final countThisMonth = clients.where((c) => c.monthKey == key).length;
      final num = countThisMonth + 1;
      final id =
          '$_businessUnit/$key($_therapistInitials)/${num.toString().padLeft(2, '0')}';
      client = ClientRecord(
        clientId: id,
        name: name,
        phone: phone,
        monthKey: key,
        clientNumber: num,
      );
    } else {
      existingIndex = clients.indexWhere((c) => c.clientId == client!.clientId);
    }

    // Session number is always the next in total history (across all months)
    final sessionNum = client.sessionCount + 1;
    final invoiceNumber =
        '${client.clientId}.${sessionNum.toString().padLeft(2, '0')}';

    final updated = client.addSession(SessionRecord(
      invoiceNumber: invoiceNumber,
      sessionDate: sessionDate,
      fee: fee,
      lessCHS1: lessCHS1,
    ));

    if (existingIndex >= 0) {
      clients[existingIndex] = updated;
    } else {
      clients.add(updated);
    }

    await _saveAll(clients);
    return (updated, invoiceNumber);
  }

  static Future<ClientRecord> addManualClient({
    required String name,
    required String phone,
    required DateTime referenceDate,
  }) async {
    final clients = await loadAll();
    if (findByPhone(clients, phone) != null) {
      throw Exception('A client with this phone number already exists');
    }
    final key = monthKey(referenceDate);
    final countThisMonth = clients.where((c) => c.monthKey == key).length;
    final num = countThisMonth + 1;
    final id = '$_businessUnit/$key($_therapistInitials)/${num.toString().padLeft(2, '0')}';
    final client = ClientRecord(
      clientId: id,
      name: name,
      phone: phone,
      monthKey: key,
      clientNumber: num,
    );
    clients.add(client);
    await _saveAll(clients);
    return client;
  }

  static Future<ClientRecord> updateClient(
    String clientId, {
    String? name,
    String? phone,
  }) async {
    final clients = await loadAll();
    final idx = clients.indexWhere((c) => c.clientId == clientId);
    if (idx < 0) throw Exception('Client not found');
    final old = clients[idx];
    final updated = ClientRecord(
      clientId: old.clientId,
      name: name ?? old.name,
      phone: phone ?? old.phone,
      monthKey: old.monthKey,
      clientNumber: old.clientNumber,
      sessions: old.sessions,
    );
    clients[idx] = updated;
    await _saveAll(clients);
    return updated;
  }

  static Future<void> deleteClient(String clientId) async {
    final clients = await loadAll();
    clients.removeWhere((c) => c.clientId == clientId);
    await _saveAll(clients);
  }

  static Future<ClientRecord> deleteSession(
    String clientId,
    String invoiceNumber,
  ) async {
    final clients = await loadAll();
    final idx = clients.indexWhere((c) => c.clientId == clientId);
    if (idx < 0) throw Exception('Client not found');
    final old = clients[idx];
    final updated = ClientRecord(
      clientId: old.clientId,
      name: old.name,
      phone: old.phone,
      monthKey: old.monthKey,
      clientNumber: old.clientNumber,
      sessions: old.sessions
          .where((s) => s.invoiceNumber != invoiceNumber)
          .toList(),
    );
    clients[idx] = updated;
    await _saveAll(clients);
    return updated;
  }
}
