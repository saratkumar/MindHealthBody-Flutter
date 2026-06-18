import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'booking_provider.dart';
import 'sheets_service.dart';

const _kStatements = [
  'I focus on how others are feeling when tension rises.',
  'I feel unsettled if someone seems upset with me.',
  'I prioritise harmony, even if I disagree.',
  'I replay conversations to check if I hurt someone.',
  'I soften my stance to prevent conflict escalating.',
  'I feel responsible for repairing strained relationships.',
  'I want clear structure before moving forward.',
  'Sudden changes significantly increase my tension.',
  'I focus on logical inconsistencies in situations.',
  'I become more organised when things feel chaotic.',
  'I rely on rules or procedures to guide decisions.',
  'I prefer step-by-step solutions during conflict.',
  'I focus on getting things done quickly when pressured.',
  'I measure progress to feel more in control.',
  'I become impatient with prolonged emotional discussions.',
  'I cope by increasing productivity.',
  'I prefer solving the problem rather than analysing feelings.',
  'I judge situations by efficiency and effectiveness.',
  'I act quickly rather than deliberate when stressed.',
  'I prefer to "do something" instead of waiting.',
  'I react immediately when provoked.',
  'I feel restless when situations stall.',
  'I make fast decisions even with limited information.',
  'I rely on instinct in high-pressure situations.',
];

// Items 1-6 = O, 7-12 = S, 13-18 = T, 19-24 = A (0-indexed: 0-5, 6-11, 12-17, 18-23)
const _kQuadrantLabels = {
  'O': 'Others-Oriented',
  'S': 'Systems-Oriented',
  'T': 'Task-Oriented',
  'A': 'Action-Oriented',
};

const _kRatingLabels = ['0 – Not like me', '1 – Slightly', '2 – Mostly', '3 – Very much'];

String _quadrantFor(int idx) {
  if (idx < 6) return 'O';
  if (idx < 12) return 'S';
  if (idx < 18) return 'T';
  return 'A';
}

class AoqFormScreen extends StatefulWidget {
  const AoqFormScreen({super.key});

  @override
  State<AoqFormScreen> createState() => _AoqFormScreenState();
}

class _AoqFormScreenState extends State<AoqFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  late final List<int?> _secA;
  late final List<int?> _secB;

  bool _submitting = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _secA = List.filled(24, null);
    _secB = List.filled(24, null);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _sectionComplete(List<int?> sec) => sec.every((v) => v != null);

  // Scoring formulas (matching Excel Summary sheet)
  Map<String, int> _quadrantTotals(List<int?> sec) {
    int o = 0, s = 0, t = 0, a = 0;
    for (var i = 0; i < 24; i++) {
      final v = sec[i] ?? 0;
      if (i < 6) o += v;
      else if (i < 12) s += v;
      else if (i < 18) t += v;
      else a += v;
    }
    return {'O': o, 'S': s, 'T': t, 'A': a};
  }

  Map<String, dynamic> _computeSummary() {
    final baseline = _quadrantTotals(_secA);
    final stress   = _quadrantTotals(_secB);

    // Baseline % = total / 18 (6 items × max 3)
    final bPct = {for (final k in baseline.keys) k: baseline[k]! / 18.0};
    final sPct = {for (final k in stress.keys)   k: stress[k]!   / 18.0};
    final delta = {for (final k in bPct.keys) k: sPct[k]! - bPct[k]!};

    // OGI = max(baseline%) – min(baseline%)
    final ogi = bPct.values.reduce((a, b) => a > b ? a : b) -
                bPct.values.reduce((a, b) => a < b ? a : b);

    // SEI = max(stress%) – min(stress%)
    final sei = sPct.values.reduce((a, b) => a > b ? a : b) -
                sPct.values.reduce((a, b) => a < b ? a : b);

    String _primaryOf(Map<String, double> pct) =>
        pct.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    String _largestDelta() =>
        delta.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return {
      'baseline': baseline,
      'stress': stress,
      'baselinePct': bPct,
      'stressPct': sPct,
      'delta': delta,
      'ogi': ogi,
      'sei': sei,
      'primaryBaseline': _primaryOf(bPct),
      'primaryStress': _primaryOf(sPct),
      'largestDelta': _largestDelta(),
    };
  }

  Future<void> _submit() async {
    if (!_sectionComplete(_secA)) {
      _tabs.animateTo(0);
      _snack('Please complete all items in Section A (Baseline)');
      return;
    }
    if (!_sectionComplete(_secB)) {
      _tabs.animateTo(1);
      _snack('Please complete all items in Section B (Stress)');
      return;
    }

    setState(() => _submitting = true);
    try {
      final summary = _computeSummary();
      final provider = context.read<BookingProvider>();
      final email = provider.userEmail ?? '';
      final now = DateTime.now();

      final account = provider.currentAccount as GoogleSignInAccount?;
      if (account == null) {
        if (!mounted) return;
        setState(() { _result = summary; _submitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Results shown locally — sign in with Google to save to the shared spreadsheet.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
        return;
      }

      // Request scopes from within the button-press context (GIS requires a user gesture).
      await provider.requestApiScopes();

      await SheetsService.appendAOQResult(
        account: account,
        clientEmail: email,
        date: now,
        baseline: (summary['baseline'] as Map<String, int>),
        stress: (summary['stress'] as Map<String, int>),
        ogi: summary['ogi'] as double,
        sei: summary['sei'] as double,
        primaryBaseline: summary['primaryBaseline'] as String,
        primaryStress: summary['primaryStress'] as String,
        largestDelta: summary['largestDelta'] as String,
        rawA: _secA,
        rawB: _secB,
      );

      if (!mounted) return;
      setState(() {
        _result = summary;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('Save failed: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: error ? Colors.red : null));
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResult();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AOQ-24 Assessment'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Section A – Baseline'),
                if (_sectionComplete(_secA))
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.check_circle, size: 16, color: Color(0xFF34A853)),
                  ),
              ]),
            ),
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Section B – Stress'),
                if (_sectionComplete(_secB))
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.check_circle, size: 16, color: Color(0xFF34A853)),
                  ),
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSection(_secA, 'Rate how you usually behave when things are generally calm or normal.'),
          _buildSection(_secB, 'Rate how you usually behave when you are emotionally triggered, stressed, or upset.'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Submit Assessment'),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(List<int?> section, String instruction) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(instruction, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 8),
        // Rating legend
        Row(
          children: _kRatingLabels
              .map((l) => Expanded(
                    child: Text(l,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A73E8))),
                  ))
              .toList(),
        ),
        const Divider(height: 16),
        ...List.generate(24, (i) => _buildItem(section, i)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildItem(List<int?> section, int i) {
    final quadrant = _quadrantFor(i);
    final quadrantLabel = _kQuadrantLabels[quadrant]!;
    final isFirst = (i == 0 || _quadrantFor(i - 1) != quadrant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isFirst) ...[
          if (i > 0) const Divider(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _quadrantColor(quadrant).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$quadrant – $quadrantLabel',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _quadrantColor(quadrant),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${_kStatements[i]}',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(4, (rating) {
                    final selected = section[i] == rating;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => section[i] = rating),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? _quadrantColor(quadrant)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? _quadrantColor(quadrant)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            '$rating',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: selected ? Colors.white : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _quadrantColor(String q) {
    return switch (q) {
      'O' => const Color(0xFF1A73E8),
      'S' => const Color(0xFF34A853),
      'T' => const Color(0xFFFA7B17),
      _ => const Color(0xFF9334E6),
    };
  }

  Widget _buildResult() {
    final summary = _result!;
    final baseline = summary['baseline'] as Map<String, int>;
    final stress = summary['stress'] as Map<String, int>;
    final ogi = summary['ogi'] as double;
    final sei = summary['sei'] as double;
    final primaryB = summary['primaryBaseline'] as String;
    final primaryS = summary['primaryStress'] as String;
    final largest = summary['largestDelta'] as String;

    String _seiLabel() {
      final pct = sei * 100;
      if (pct <= 10) return 'Flexible under stress';
      if (pct <= 25) return 'Moderate directional bias';
      if (pct <= 40) return 'Strong narrowing under stress';
      return 'Rigid escalation pattern risk';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AOQ-24 Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF34A853), size: 56),
            const SizedBox(height: 12),
            const Text('Assessment Complete',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Saved ${DateFormat('dd/MM/yyyy h:mm a').format(DateTime.now())}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 24),

            // Quadrant scores
            ...['O', 'S', 'T', 'A'].map((q) {
              final bScore = baseline[q] ?? 0;
              final sScore = stress[q] ?? 0;
              final color = _quadrantColorStatic(q);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$q – ${_kQuadrantLabels[q]}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _miniBar('Baseline', bScore, color)),
                        const SizedBox(width: 12),
                        Expanded(child: _miniBar('Stress', sScore, color.withOpacity(0.6))),
                      ]),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            // Key outputs
            Card(
              color: const Color(0xFFE8F0FE),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Key Outputs',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A73E8))),
                    const SizedBox(height: 10),
                    _keyRow('Baseline OGI',
                        '${(ogi * 100).toStringAsFixed(1)}%'),
                    _keyRow('Stress Escalation Index (SEI)',
                        '${(sei * 100).toStringAsFixed(1)}%  –  ${_seiLabel()}'),
                    _keyRow('Primary Baseline Orientation',
                        '$primaryB – ${_kQuadrantLabels[primaryB]}'),
                    _keyRow('Primary Stress Orientation',
                        '$primaryS – ${_kQuadrantLabels[primaryS]}'),
                    _keyRow('Largest Delta Increase',
                        '$largest – ${_kQuadrantLabels[largest]}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Menu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBar(String label, int score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 3),
        Row(children: [
          Expanded(
            child: LinearProgressIndicator(
              value: score / 18,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text('$score/18',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ],
    );
  }

  Widget _keyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _quadrantColorStatic(String q) {
    return switch (q) {
      'O' => const Color(0xFF1A73E8),
      'S' => const Color(0xFF34A853),
      'T' => const Color(0xFFFA7B17),
      _ => const Color(0xFF9334E6),
    };
  }
}
