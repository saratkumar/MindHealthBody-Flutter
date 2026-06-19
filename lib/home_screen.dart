import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'booking_provider.dart';
import 'book_screen.dart';
import 'upcoming_screen.dart';
import 'history_screen.dart';
import 'calendar_events_screen.dart';
import 'clients_screen.dart';
import 'client_menu_screen.dart';
import 'admin_login_screen.dart';
import 'admin_requests_screen.dart';
import 'uam_screen.dart';
import 'user_registry.dart';
import 'user_request_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  _UserRole? _role;
  _UserRole? _testRole; // static test account bypass
  bool _checkingRegistry = false;
  String? _authError;
  bool _listenerAdded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerAdded) {
      _listenerAdded = true;
      context.read<BookingProvider>().addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    try {
      context.read<BookingProvider>().removeListener(_onProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final provider = context.read<BookingProvider>();
    if (provider.isSignedIn && !_isAdmin && _role == null && !_checkingRegistry) {
      _checkRegistry(provider);
    }
    if (!provider.isSignedIn && !_isAdmin) {
      setState(() {
        _role = null;
        _checkingRegistry = false;
      });
    }
  }

  Future<void> _checkRegistry(BookingProvider provider) async {
    final email = provider.userEmail;
    if (email == null) {
      await provider.signOut();
      if (!mounted) return;
      setState(() => _authError =
          'Could not determine your account email. Please try again.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _checkingRegistry = true;
      _authError = null;
    });

    final user = await UserRegistryService.findByEmail(email);

    if (!mounted) return;
    if (user == null) {
      await provider.signOut();
      if (!mounted) return;
      setState(() {
        _checkingRegistry = false;
        _authError =
            'User is not registered.\nPlease contact Psychology Clinics.';
      });
    } else {
      setState(() {
        _checkingRegistry = false;
        _role = switch (user.role) {
          'client' => _UserRole.client,
          'admin' => _UserRole.admin,
          _ => _UserRole.practitioner,
        };
        _authError = null;
      });
    }
  }

  void _enterAdmin() {
    setState(() { _isAdmin = true; _selectedIndex = 0; });
  }

  void _exitAdmin() {
    setState(() { _isAdmin = false; _selectedIndex = 0; });
  }

  void _enterTestRole(_UserRole role) {
    setState(() { _testRole = role; _selectedIndex = 0; _authError = null; });
  }

  void _exitTestRole() {
    setState(() { _testRole = null; _selectedIndex = 0; });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    // ── Admin mode ──────────────────────────────────────────────
    if (_isAdmin) {
      return _AdminScaffold(
        selectedIndex: _selectedIndex,
        onIndexChanged: (i) => setState(() => _selectedIndex = i),
        onSignOut: _exitAdmin,
      );
    }

    // ── Test account (static bypass) ─────────────────────────────
    if (_testRole == _UserRole.client) {
      return ClientMenuScreen(onSignOut: _exitTestRole);
    }
    if (_testRole == _UserRole.practitioner) {
      return _PractitionerScaffold(
        selectedIndex: _selectedIndex,
        onIndexChanged: (i) => setState(() => _selectedIndex = i),
        onSignOut: _exitTestRole,
      );
    }

    // ── Not signed in ────────────────────────────────────────────
    if (!provider.isSignedIn) {
      return _SignInPage(
        isLoading: provider.status == BookingStatus.loading || _checkingRegistry,
        onSignIn: provider.signIn,
        onAdminLogin: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminLoginScreen(onSuccess: () {
              Navigator.pop(context);
              _enterAdmin();
            }),
          ),
        ),
        onTestLogin: _enterTestRole,
        errorMessage: _authError ?? provider.errorMessage,
      );
    }

    // ── Checking registry ─────────────────────────────────────────
    if (_checkingRegistry || _role == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying your access…'),
            ],
          ),
        ),
      );
    }

    // ── Client (Google) ──────────────────────────────────────────
    if (_role == _UserRole.client) {
      return const ClientMenuScreen();
    }

    // ── Admin (Google) ───────────────────────────────────────────
    if (_role == _UserRole.admin) {
      return _AdminScaffold(
        selectedIndex: _selectedIndex,
        onIndexChanged: (i) => setState(() => _selectedIndex = i),
        onSignOut: () => provider.signOut(),
      );
    }

    // ── Practitioner (Google) ────────────────────────────────────
    return _PractitionerScaffold(
      selectedIndex: _selectedIndex,
      onIndexChanged: (i) => setState(() => _selectedIndex = i),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role enum (internal to this file)
// ─────────────────────────────────────────────────────────────────────────────

enum _UserRole { client, practitioner, admin }

// ─────────────────────────────────────────────────────────────────────────────
// Admin scaffold — 6 tabs (all practitioner tabs + Users/UAM)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onSignOut;

  const _AdminScaffold({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          const BookScreen(),
          const UpcomingScreen(),
          const RoomScreen(),
          const HistoryScreen(),
          const ClientsScreen(),
          UamScreen(onSignOut: onSignOut),
          const AdminRequestsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onIndexChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Book',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Upcoming',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: 'Room',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Requests',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Practitioner scaffold — 5 tabs + Account tab (with sign-out)
// ─────────────────────────────────────────────────────────────────────────────

class _PractitionerScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback? onSignOut;

  const _PractitionerScaffold({
    required this.selectedIndex,
    required this.onIndexChanged,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          const BookScreen(),
          const UpcomingScreen(),
          const RoomScreen(),
          const HistoryScreen(),
          const ClientsScreen(),
          _AccountTab(
            email: provider.userEmail,
            onSignOut: onSignOut != null
                ? () async => onSignOut!()
                : provider.signOut,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onIndexChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Book',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Upcoming',
          ),
          NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: 'Room',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account tab for practitioners
// ─────────────────────────────────────────────────────────────────────────────

class _AccountTab extends StatelessWidget {
  final String? email;
  final Future<void> Function() onSignOut;

  const _AccountTab({this.email, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFE8F0FE),
                child: const Icon(
                  Icons.medical_services,
                  size: 40,
                  color: Color(0xFF1A73E8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Practitioner',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (email != null) ...[
              const SizedBox(height: 4),
              Text(
                email!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Psychology Clinics',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserRequestScreen()),
              ),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Request New User'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sign-in page
// ─────────────────────────────────────────────────────────────────────────────

class _SignInPage extends StatelessWidget {
  final bool isLoading;
  final Future<bool> Function() onSignIn;
  final VoidCallback onAdminLogin;
  final ValueChanged<_UserRole> onTestLogin;
  final String? errorMessage;

  const _SignInPage({
    required this.isLoading,
    required this.onSignIn,
    required this.onAdminLogin,
    required this.onTestLogin,
    this.errorMessage,
  });

  void _showTestLogin(BuildContext context) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Test Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'client / 1234\npractitioner / 1234',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final u = userCtrl.text.trim().toLowerCase();
                final p = passCtrl.text.trim();
                if (p != '1234') {
                  setState(() => error = 'Incorrect password');
                  return;
                }
                if (u == 'client') {
                  Navigator.pop(ctx);
                  onTestLogin(_UserRole.client);
                } else if (u == 'practitioner') {
                  Navigator.pop(ctx);
                  onTestLogin(_UserRole.practitioner);
                } else {
                  setState(() => error = 'Unknown username');
                }
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.calendar_month,
                size: 72,
                color: Color(0xFF1A73E8),
              ),
              const SizedBox(height: 24),
              const Text(
                'BookMe',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A73E8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Psychology Clinics',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 48),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => onSignIn(),
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isLoading ? null : onAdminLogin,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin Login'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _showTestLogin(context),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Test Login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  side: BorderSide(color: Colors.orange.shade300),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
