// widgets/logout_button.dart
// Reusable app-bar logout button, used on both the admin and employee landing
// screens. Asks for confirmation, then calls AuthService.signOut. It does NOT
// navigate itself: the AuthGate in main.dart listens to auth state and swaps
// back to the LoginScreen automatically once the session is cleared. Errors
// (rare for sign-out) are surfaced via a SnackBar.

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService().signOut();
      // No navigation here — AuthGate reacts to the cleared session.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not log out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Log out',
      onPressed: () => _confirmAndLogout(context),
    );
  }
}
