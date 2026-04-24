import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'client_database.dart';
import 'invoice_excel_service.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  List<ClientRecord> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final clients = await ClientDatabase.loadAll();
    clients.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) setState(() { _clients = clients; _loading = false; });
  }

  Future<void> _syncExcel() async {
    await InvoiceExcelService.syncClientsSheet(_clients);
  }

  Future<void> _exportExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await InvoiceExcelService.workingFile;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'MBP Client Database',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _openDetail(ClientRecord client) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(
          initialClient: client,
          onUpdate: (clientId, {String? name, String? phone}) async {
            await ClientDatabase.updateClient(clientId, name: name, phone: phone);
            await _load();
            await _syncExcel();
          },
          onDeleteSession: (clientId, invoiceNumber) async {
            await ClientDatabase.deleteSession(clientId, invoiceNumber);
            await _load();
            await _syncExcel();
          },
        ),
      ),
    );
    _load();
  }

  void _showEditDialog(ClientRecord client) {
    final nameCtrl = TextEditingController(text: client.name);
    final phoneCtrl = TextEditingController(text: client.phone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ClientDatabase.updateClient(
                client.clientId,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              await _load();
              await _syncExcel();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ClientRecord client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text(
          'Remove ${client.name} and all ${client.sessionCount} '
          'session${client.sessionCount == 1 ? '' : 's'}? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ClientDatabase.deleteClient(client.clientId);
              await _load();
              await _syncExcel();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'Jane Smith'),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone', hintText: '+91 98765 43210'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ClientDatabase.addManualClient(
                  name: name,
                  phone: phone,
                  referenceDate: DateTime.now(),
                );
                await _load();
                await _syncExcel();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clients${_clients.isEmpty ? '' : ' (${_clients.length})'}'),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share), onPressed: _exportExcel, tooltip: 'Export Excel'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No clients yet',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        'Clients appear here automatically when you\ngenerate an invoice, or tap + to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _clients.length,
                  itemBuilder: (ctx, i) => _ClientCard(
                    client: _clients[i],
                    onTap: () => _openDetail(_clients[i]),
                    onEdit: () => _showEditDialog(_clients[i]),
                    onDelete: () => _confirmDelete(_clients[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'Add client',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// ── Client list card ──────────────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  final ClientRecord client;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final _dateFmt = DateFormat('dd MMM yy');
  static final _currFmt = NumberFormat('#,##,##0.00', 'en_IN');

  const _ClientCard({
    required this.client,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final last = client.sessions.isNotEmpty ? client.sessions.last : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: avatar + name + actions
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE8F0FE),
                    child: Text(
                      client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF1A73E8),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 1),
                        Text(client.phone,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: Colors.grey.shade500,
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red.shade300,
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Row 2: client ID + sessions + last invoice
              Row(
                children: [
                  _Chip(label: client.clientId, color: const Color(0xFF1A73E8)),
                  const SizedBox(width: 8),
                  _Chip(
                    label: '${client.sessionCount} session${client.sessionCount == 1 ? '' : 's'}',
                    color: Colors.grey.shade600,
                  ),
                ],
              ),

              if (last != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Last: ${last.invoiceNumber}  ·  ${_dateFmt.format(last.sessionDate)}  ·  ₹${_currFmt.format(last.fee - last.lessCHS1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('View history',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right,
                      size: 14, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Detail screen ─────────────────────────────────────────────────────────────

class ClientDetailScreen extends StatefulWidget {
  final ClientRecord initialClient;
  final Future<void> Function(String clientId, {String? name, String? phone}) onUpdate;
  final Future<void> Function(String clientId, String invoiceNumber) onDeleteSession;

  const ClientDetailScreen({
    super.key,
    required this.initialClient,
    required this.onUpdate,
    required this.onDeleteSession,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late ClientRecord _client;

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _currFmt = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _client = widget.initialClient;
  }

  Future<void> _reload() async {
    final all = await ClientDatabase.loadAll();
    final updated = all.firstWhere(
      (c) => c.clientId == _client.clientId,
      orElse: () => _client,
    );
    if (mounted) setState(() => _client = updated);
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: _client.name);
    final phoneCtrl = TextEditingController(text: _client.phone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onUpdate(
                _client.clientId,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              await _reload();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSession(SessionRecord session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Remove invoice ${session.invoiceNumber}?\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onDeleteSession(_client.clientId, session.invoiceNumber);
              await _reload();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _client.sessions.fold(0.0, (sum, s) => sum + s.fee - s.lessCHS1);

    return Scaffold(
      appBar: AppBar(
        title: Text(_client.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFE8F0FE),
                        child: Text(
                          _client.name.isNotEmpty ? _client.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_client.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(_client.phone,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _DetailRow(label: 'Client ID', value: _client.clientId),
                  const SizedBox(height: 8),
                  _DetailRow(label: 'Member Since', value: _client.monthKey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Stats row ──
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Sessions',
                  value: '${_client.sessionCount}',
                  icon: Icons.event_note_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Total Revenue',
                  value: '₹${_currFmt.format(totalRevenue)}',
                  icon: Icons.currency_rupee,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Invoice history header ──
          const Text('Invoice History',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          if (_client.sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No sessions recorded yet.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else ...[
            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(flex: 3, child: _ColHeader('Invoice ID')),
                  const Expanded(flex: 2, child: _ColHeader('Date')),
                  const Expanded(flex: 2, child: _ColHeader('Fee', right: true)),
                  const Expanded(flex: 2, child: _ColHeader('Discount', right: true)),
                  const Expanded(flex: 2, child: _ColHeader('Total', right: true)),
                  const SizedBox(width: 32), // space for delete button
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Session rows (newest first)
            ..._client.sessions.reversed.map((s) {
              final total = s.fee - s.lessCHS1;
              return Container(
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(s.invoiceNumber,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A73E8))),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_dateFmt.format(s.sessionDate),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('₹${_currFmt.format(s.fee)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          s.lessCHS1 > 0 ? '−₹${_currFmt.format(s.lessCHS1)}' : '—',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              color: s.lessCHS1 > 0
                                  ? Colors.orange.shade700
                                  : Colors.grey.shade400),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('₹${_currFmt.format(total)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        color: Colors.red.shade300,
                        tooltip: 'Delete session',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => _confirmDeleteSession(s),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1A73E8)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final bool right;
  const _ColHeader(this.text, {this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A73E8),
      ),
    );
  }
}
