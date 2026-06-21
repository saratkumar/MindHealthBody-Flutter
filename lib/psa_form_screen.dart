import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'booking_provider.dart';
import 'sheets_service.dart';

// Questions: each has a stem + 4 options mapped to [Facilitator, Processor, Analyser, Explorer]
const _kQuestions = [
  (
    stem: 'The personal qualities I am more aware of in myself are...',
    opts: ['Gentleness & Warmth', 'Strength & Capability', 'Consistency & Clarity', 'Spontaneity & Creativity'],
  ),
  (
    stem: 'The strongest value (principle) for me is...',
    opts: ['Relationship', 'Responsibility', 'Being Correct', 'Freedom'],
  ),
  (
    stem: 'I am attracted to people who...',
    opts: ['Are cooperative & easy to get along with', 'Are responsible & get things done', 'Are thorough & think things through', 'Are fun & unique'],
  ),
  (
    stem: 'I tend to make decisions by...',
    opts: ['Trusting my Intuition', 'Following the rules', 'Careful Analysis & Consideration', 'My Gut Reaction'],
  ),
  (
    stem: 'I get people to cooperate by...',
    opts: ['Creating Friendship & Harmony', 'Persuasion & Direction', 'Discussion & Logical Approach', 'Motivation & Creative Style'],
  ),
  (
    stem: 'I feel best about myself when I am...',
    opts: ['Helping People Feel Good', 'Getting Things Done', 'Advising People & Helping Them Think', 'Causing Things to Happen'],
  ),
  (
    stem: 'I want others to see me as...',
    opts: ['Warm & Personable', 'Reliable & Effective', 'Confident & Logical', 'Skilful & Unique'],
  ),
  (
    stem: 'When someone criticises me, I will likely...',
    opts: ['Withdraw & not deal with it', 'Defend myself', 'Analyse situation & motives', 'Ignore it and move on'],
  ),
  (
    stem: 'When I am really down on myself I see myself as...',
    opts: ['Having very little to offer', 'Incapable of doing what is needed', 'Confused & out of control', 'A loser'],
  ),
  (
    stem: 'When I am under stress I tend to...',
    opts: ['Withdraw & compromise', 'Redouble my efforts', 'Discuss & analyse', 'Challenge & confront'],
  ),
];

const _kTypes = ['Facilitator', 'Processor', 'Analyser', 'Explorer'];

class PsaFormScreen extends StatefulWidget {
  const PsaFormScreen({super.key});

  @override
  State<PsaFormScreen> createState() => _PsaFormScreenState();
}

class _PsaFormScreenState extends State<PsaFormScreen> {
  // ranks[q][opt] = rank value (1-4 or null)
  final List<List<int?>> _ranks =
      List.generate(10, (_) => List.filled(4, null));

  bool _submitting = false;
  Map<String, int>? _result;

  bool get _complete =>
      _ranks.every((row) => row.every((v) => v != null));

  String? _rowError(int q) {
    final row = _ranks[q];
    if (row.any((v) => v == null)) return null; // not fully filled yet
    final vals = row.whereType<int>().toList()..sort();
    if (vals.toString() != '[1, 2, 3, 4]') {
      return 'Each question must use 1, 2, 3 and 4 exactly once';
    }
    return null;
  }

  bool get _valid {
    if (!_complete) return false;
    for (var q = 0; q < 10; q++) {
      if (_rowError(q) != null) return false;
    }
    return true;
  }

  Map<String, int> _calculate() {
    // Sum column i across all 10 questions â†’ type i total
    final totals = List.filled(4, 0);
    for (final row in _ranks) {
      for (var i = 0; i < 4; i++) {
        totals[i] += row[i] ?? 0;
      }
    }
    return {
      'facilitator': totals[0],
      'processor': totals[1],
      'analyser': totals[2],
      'explorer': totals[3],
    };
  }

  Future<void> _submit() async {
    if (!_valid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Please complete all questions. Each row must use 1, 2, 3 and 4 exactly once.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final scores = _calculate();
      final provider = context.read<BookingProvider>();
      final email = provider.userEmail ?? '';
      final now = DateTime.now();

      final account = provider.currentAccount as GoogleSignInAccount?;
      if (account == null) {
        if (!mounted) return;
        setState(() { _result = scores; _submitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Results shown locally â€” sign in with Google to save to the shared spreadsheet.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
        return;
      }

      // Request scopes from within the button-press context (GIS requires a user gesture).
      await provider.requestApiScopes();

      await SheetsService.appendPSAResult(
        account: account,
        clientEmail: email,
        date: now,
        scores: scores,
        ranks: _ranks,
      );

      if (!mounted) return;
      setState(() {
        _result = scores;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PSA â€“ Personality Styles Assessment')),
      body: _result != null ? _buildResult() : _buildForm(),
    );
  }

  Widget _buildResult() {
    final scores = _result!;
    final sorted = _kTypes.toList()
      ..sort((a, b) =>
          (scores[b.toLowerCase()] ?? 0).compareTo(scores[a.toLowerCase()] ?? 0));
    final primary = sorted.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF34A853), size: 56),
          const SizedBox(height: 12),
          const Text('Assessment Complete',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Results saved on ${DateFormat('dd/MM/yyyy h:mm a').format(DateTime.now())}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          Text('Your Primary Style: $primary',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D49A7))),
          const SizedBox(height: 20),
          ...sorted.map((type) {
            final score = scores[type.toLowerCase()] ?? 0;
            return _ScoreBar(
              label: type,
              score: score,
              maxScore: 40,
              isPrimary: type == primary,
            );
          }),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'For each question, rank the four options from 4 to 1.\n'
              '4 = Most like me   3 = Quite like me   2 = A little like me   1 = Least like me\n'
              'Each number must be used exactly once per question.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 8),
                ..._kTypes.map((t) => Expanded(
                      child: Text(t,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D49A7))),
                    )),
              ],
            ),
          ),
          const Divider(),
          ...List.generate(10, (q) => _buildQuestion(q)),
          const SizedBox(height: 20),
          // Running totals
          if (_complete) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 8),
                ..._kTypes.asMap().entries.map((e) {
                  final total = _ranks.fold<int>(
                      0, (sum, row) => sum + (row[e.key] ?? 0));
                  return Expanded(
                    child: Column(children: [
                      Text(e.value,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('$total',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D49A7))),
                    ]),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: (_valid && !_submitting) ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Submit Assessment'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestion(int q) {
    final question = _kQuestions[q];
    final error = _rowError(q);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${q + 1}. ${question.stem}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...List.generate(4, (opt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(question.opts[opt],
                          style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _ranks[q][opt],
                        isExpanded: true,
                        hint: const Text('â€“', textAlign: TextAlign.center),
                        items: [1, 2, 3, 4]
                            .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text('$v',
                                    textAlign: TextAlign.center)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _ranks[q][opt] = v),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(error,
                    style: const TextStyle(fontSize: 11, color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;
  final bool isPrimary;

  const _ScoreBar({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final pct = score / maxScore;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight:
                          isPrimary ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14)),
              const Spacer(),
              Text('$score / $maxScore',
                  style: TextStyle(
                      color: isPrimary
                          ? const Color(0xFF1D49A7)
                          : Colors.grey.shade600,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            color: isPrimary ? const Color(0xFF1D49A7) : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}
