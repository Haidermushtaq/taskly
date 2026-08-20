// widgets/social_sign_in_buttons.dart
// The "or continue with" divider plus the Google and Facebook buttons, shared
// by the login and signup screens so both offer the same options and look the
// same. Social sign-in doesn't distinguish signing up from logging in — the
// first time you use a provider Supabase creates the account for you — so one
// widget serves both screens.
//
// It owns its own `_loading` flag: while a provider button is being tapped
// both buttons are disabled and a spinner replaces them. Errors come back
// through authErrorMessage() in a SnackBar, the same as the email forms.
// On success nothing happens here: the browser sends the user back through
// the app's deep link and AuthGate swaps the screen.

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SocialSignInButtons extends StatefulWidget {
  // True while the parent screen's own email form is busy, so the social
  // buttons grey out too and the user can't start two logins at once.
  final bool parentBusy;

  const SocialSignInButtons({super.key, this.parentBusy = false});

  @override
  State<SocialSignInButtons> createState() => _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends State<SocialSignInButtons> {
  final _authService = AuthService();

  bool _loading = false;

  // Runs one of the two provider sign-ins, showing a spinner while the
  // browser is being opened and a SnackBar if it fails.
  Future<void> _signIn(Future<void> Function() providerSignIn) async {
    setState(() => _loading = true);
    try {
      await providerSignIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Disabled when either this widget or the parent form is working.
    final busy = _loading || widget.parentBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        // "or continue with" between two hairlines.
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'or continue with',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: _ProviderButton(
                  label: 'Google',
                  // Material Icons has no Google logo, so we draw its
                  // recognisable blue "G" as text instead.
                  icon: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  onPressed:
                      busy ? null : () => _signIn(_authService.signInWithGoogle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProviderButton(
                  label: 'Facebook',
                  icon: const Icon(
                    Icons.facebook,
                    color: Color(0xFF1877F2),
                    size: 20,
                  ),
                  onPressed: busy
                      ? null
                      : () => _signIn(_authService.signInWithFacebook),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// One outlined provider button: a brand-colored mark and the provider name.
// Purely presentational — the parent decides what tapping it does.
class _ProviderButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey.shade300),
        foregroundColor: Colors.black87,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 22, child: Center(child: icon)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
