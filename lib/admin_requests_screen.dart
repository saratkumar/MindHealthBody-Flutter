import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'booking_provider.dart';
import 'gmail_service.dart';
import 'user_registry.dart';
import 'user_request_service.dart';

/// Admin-facing list of pending new-user requests, with approve/reject.
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<UserRequest> _pending = [];
  bool _loading = true;
  String? _busyRequestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pending = await UserRequestService.getPending();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _loading = false;
    });
  }

  GoogleSignInAccount? get _account =>
      context.read<BookingProvider>().currentAccount as GoogleSignInAccount?;

  Future<void> _approve(UserRequest request) async {
    final account = _account;
    final adminEmail = context.read<BookingProvider>().userEmail;
    if (account == null || adminEmail == null) return;

    setState(() => _busyRequestId = request.id);
    try {
      await UserRegistryService.add(AppUser(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: request.name,
        email: request.email,
        role: request.role,
        createdAt: DateTime.now(),
      ));
      await UserRequestService.approve(request, adminEmail);

      await GmailService.sendRequestApprovedEmail(
        account: account,
        practitionerEmail: request.requestedByEmail,
        practitionerName: request.requestedByName,
        newUserName: request.name,
        newUserRole: request.role,
      );
      await GmailService.sendEnrollmentEmail(
        account: account,
        newUserEmail: request.email,
        newUserName: request.name,
      );

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${request.name} approved and notified')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _reject(UserRequest request) async {
    final adminEmail = context.read<BookingProvider>().userEmail;
    if (adminEmail == null) return;

    setState(() => _busyRequestId = request.id);
    try {
      await UserRequestService.reject(request, adminEmail);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reject failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Requests${_pending.isEmpty ? '' : ' (${_pending.length})'}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No pending requests',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RequestCard(
                    request: _pending[i],
                    busy: _busyRequestId == _pending[i].id,
                    onApprove: () => _approve(_pending[i]),
                    onReject: () => _reject(_pending[i]),
                  ),
                ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final UserRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isPractitioner = request.role == 'practitioner';
    final roleColor = isPractitioner ? const Color(0xFFD93025) : const Color(0xFF023047);
    final roleBg = isPractitioner ? const Color(0xFFFCE8E6) : const Color(0xFFE8F0FE);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(request.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    isPractitioner ? 'Practitioner' : 'Client',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(request.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(request.phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            if (request.note.isNotEmpty) ...[
              Text('Note: ${request.note}', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
            ],
            Text(
              'Requested by ${request.requestedByName} · '
              '${DateFormat('dd MMM yyyy').format(request.createdAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            if (busy)
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
