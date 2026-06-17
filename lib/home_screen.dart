import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'booking_provider.dart';
import 'book_screen.dart';
import 'upcoming_screen.dart';
import 'history_screen.dart';
import 'calendar_events_screen.dart';
import 'clients_screen.dart';
import 'intake_form_screen.dart';

enum HomeRole { client, practitioner }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  HomeRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookingProvider>();

    if (!provider.isSignedIn) {
      return _SignInPage(
        isLoading: provider.status == BookingStatus.loading,
        onSignIn: provider.signIn,
        errorMessage: provider.errorMessage,
      );
    }

    if (_selectedRole == null) {
      return _RoleSelectionPage(
        onRoleSelected: (role) => setState(() => _selectedRole = role),
        onSignOut: provider.signOut,
      );
    }

    if (_selectedRole == HomeRole.client) {
      return const IntakeFormScreen();
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          BookScreen(),
          UpcomingScreen(),
          RoomScreen(),
          HistoryScreen(),
          ClientsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
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
        ],
      ),
    );
  }
}

class _RoleSelectionPage extends StatelessWidget {
  final ValueChanged<HomeRole> onRoleSelected;
  final Future<void> Function() onSignOut;

  const _RoleSelectionPage({
    required this.onRoleSelected,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.calendar_month,
                size: 72,
                color: Color(0xFF1A73E8),
              ),
              const SizedBox(height: 16),
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
                'Choose how you want to use BookMe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const Spacer(),
              _RoleCard(
                icon: Icons.person_outline,
                title: 'Client',
                subtitle: 'Submit a signed intake form',
                onTap: () => onRoleSelected(HomeRole.client),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.medical_services_outlined,
                title: 'Practitioner',
                subtitle: 'Use the current booking and calendar flow',
                onTap: () => onRoleSelected(HomeRole.practitioner),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: const Color(0xFF1A73E8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInPage extends StatelessWidget {
  final bool isLoading;
  final Future<bool> Function() onSignIn;
  final String? errorMessage;

  const _SignInPage({
    required this.isLoading,
    required this.onSignIn,
    this.errorMessage,
  });

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
                'Schedule meetings via Google Calendar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 48),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
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
            ],
          ),
        ),
      ),
    );
  }
}
