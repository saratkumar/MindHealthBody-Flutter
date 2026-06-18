import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'aoq_form_screen.dart';
import 'booking_provider.dart';
import 'intake_form_screen.dart';
import 'psa_form_screen.dart';
import 'sheets_service.dart';

class ClientMenuScreen extends StatefulWidget {
  final VoidCallback? onSignOut;
  const ClientMenuScreen({super.key, this.onSignOut});

  @override
  State<ClientMenuScreen> createState() => _ClientMenuScreenState();
}

class _ClientMenuScreenState extends State<ClientMenuScreen> {
  bool _intakeSubmitted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkIntakeStatus();
  }

  Future<void> _checkIntakeStatus() async {
    final provider = context.read<BookingProvider>();
    final email = provider.userEmail ?? '';
    final prefs = await SharedPreferences.getInstance();

    // Fast path: local cache
    if (prefs.getBool('intake_submitted_$email') ?? false) {
      if (!mounted) return;
      setState(() { _intakeSubmitted = true; _checking = false; });
      return;
    }

    // Fallback: check Google Sheet (survives reinstalls / new devices)
    final account = provider.currentAccount as GoogleSignInAccount?;
    if (account != null && email.isNotEmpty) {
      try {
        final found = await SheetsService.checkIntakeSubmitted(account, email);
        if (found) {
          await prefs.setBool('intake_submitted_$email', true);
          if (!mounted) return;
          setState(() { _intakeSubmitted = true; _checking = false; });
          return;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() { _intakeSubmitted = false; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Portal'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () => widget.onSignOut != null
                ? widget.onSignOut!()
                : provider.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person,
                      size: 42, color: Color(0xFF1A73E8)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Welcome',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A73E8))),
              const SizedBox(height: 4),
              const Text('The Mindbody Practice',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              if (provider.userEmail != null) ...[
                const SizedBox(height: 4),
                Text(provider.userEmail!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9AA0A6))),
              ],
              const SizedBox(height: 32),

              // ── Intake Form ────────────────────────────────────────────────
              if (_checking)
                const Center(child: CircularProgressIndicator())
              else
                _MenuCard(
                  icon: Icons.assignment_outlined,
                  title: 'Client Intake Form',
                  subtitle: _intakeSubmitted
                      ? 'Already submitted — thank you!'
                      : 'Complete your personal details, consent & signatures',
                  completed: _intakeSubmitted,
                  onTap: _intakeSubmitted
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const IntakeFormScreen()),
                          );
                          // Re-check status when returning
                          _checkIntakeStatus();
                        },
                ),

              const SizedBox(height: 12),

              // ── PSA ────────────────────────────────────────────────────────
              _MenuCard(
                icon: Icons.psychology_outlined,
                title: 'PSA – Personality Styles Assessment',
                subtitle:
                    'Rank 4 options per question to identify your primary personality style',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PsaFormScreen()),
                ),
              ),

              const SizedBox(height: 12),

              // ── AOQ-24 ─────────────────────────────────────────────────────
              _MenuCard(
                icon: Icons.radar_outlined,
                title: 'AOQ-24 – Attentional Orientation Quadrant',
                subtitle:
                    'Rate 24 statements across Baseline & Stress conditions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AoqFormScreen()),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool completed;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled && completed ? 0.65 : 1.0,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFFE6F4EA)
                        : const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    completed ? Icons.check_circle_outline : icon,
                    size: 28,
                    color: completed
                        ? const Color(0xFF34A853)
                        : const Color(0xFF1A73E8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (!completed)
                  const Icon(Icons.chevron_right, color: Color(0xFF9AA0A6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
