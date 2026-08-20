// screens/profile/settings_screen.dart
// "Edit profile & settings", opened from the pencil icon on the profile
// screen. Two independent sections, each with its own Save button:
//   1. Profile — change my display name (writes to the profiles table; RLS
//      only lets me touch my own row). The new name then shows up wherever
//      the app reads profiles: teams, task cards, chat.
//   2. Password — set a new password on the session I'm already signed in
//      with. This is the in-app change, separate from the forgot-password
//      flow: there I have to prove who I am with an emailed code first,
//      here I'm already logged in, so it's a single updateUser call.
// Uses setState only. Pops back with `true` when the name changed, so the
// profile screen knows to reload.

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  // The name to prefill the field with, passed in by the profile screen so
  // this screen doesn't have to fetch the profile again.
  final String currentName;

  const SettingsScreen({super.key, required this.currentName});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();

  late final TextEditingController _nameController =
      TextEditingController(text: widget.currentName);
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _savingName = false;
  bool _savingPassword = false;
  // True once the name was saved, so we can tell the profile screen to reload.
  bool _nameChanged = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // --- Section 1: save the display name ---
  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('Name cannot be empty.');
      return;
    }

    setState(() => _savingName = true);
    try {
      await _authService.updateMyName(name);
      if (mounted) {
        _nameChanged = true;
        _toast('Name updated.');
      }
    } catch (e) {
      if (mounted) _toast(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // --- Section 2: save a new password ---
  Future<void> _savePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // Same rules as signup: at least 6 characters, and typed twice to catch
    // typos (you can't see what you're typing).
    if (password.length < 6) {
      _toast('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _toast('The two passwords do not match.');
      return;
    }

    setState(() => _savingPassword = true);
    try {
      await _authService.updatePassword(newPassword: password);
      if (mounted) {
        _passwordController.clear();
        _confirmController.clear();
        _toast('Password changed.');
      }
    } catch (e) {
      if (mounted) _toast(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope reports back whether the name changed, whichever way the user
    // leaves the screen (Save then back, or the app bar arrow).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_nameChanged);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Profile section ---
            const _SectionTitle(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'This is the name your teammates see.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 8),
            // Email is shown but not editable: changing it would mean
            // re-confirming the address, which is out of scope here.
            TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: _authService.myEmail,
              ),
            ),
            const SizedBox(height: 12),
            _savingName
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: _saveName,
                    child: const Text('Save name'),
                  ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // --- Password section ---
            const _SectionTitle(
              icon: Icons.lock_outline,
              title: 'Change password',
              subtitle: 'You are already signed in, so no email code is '
                  'needed here.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
            ),
            const SizedBox(height: 12),
            _savingPassword
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: _savePassword,
                    child: const Text('Change password'),
                  ),
          ],
        ),
      ),
    );
  }
}

// Small header used above each section: icon, bold title, grey explanation.
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
