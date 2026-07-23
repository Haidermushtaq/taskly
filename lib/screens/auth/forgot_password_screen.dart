// screens/auth/forgot_password_screen.dart
// The "forgot password" flow, reached from a link on the login screen. It is
// one screen with three internal steps (tracked by setState), all sharing the
// same brand-gradient + floating card look as login/signup:
//   Step 1 (email):    collect the email, call sendPasswordResetCode, which
//                      emails a 6-digit recovery code (no deep links).
//   Step 2 (code):     collect the 6-digit code, call verifyPasswordResetCode
//                      (verifyOTP with recovery), which establishes a session.
//   Step 3 (password): collect + confirm a new password, call updatePassword.
// On success we pop this screen: the recovery session already exists, so the
// AuthGate has swapped the screen underneath us to the normal role routing.
// Each step shows a spinner while its network call runs and a SnackBar on error.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

// The three stages of the flow.
enum _Step { email, code, password }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();

  // Which step we're currently showing.
  _Step _step = _Step.email;

  // One form key per step so we can validate just the visible fields.
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // True while any of the three network calls is running.
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Simple email shape check: something@something.something
  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  // Show a friendly error in a SnackBar (guarded by mounted for async safety).
  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(authErrorMessage(error))),
    );
  }

  // Step 1: email the recovery code, then advance to the code step.
  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _authService.sendPasswordResetCode(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('We emailed you a 6-digit code.')),
        );
        setState(() => _step = _Step.code);
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Step 2: verify the code (creates a recovery session), then advance.
  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _authService.verifyPasswordResetCode(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
      );
      if (mounted) setState(() => _step = _Step.password);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Step 3: set the new password. On success we pop: the recovery session is
  // already live, so the AuthGate underneath has routed into the app.
  Future<void> _setNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _authService.updatePassword(
        newPassword: _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // On the password step the recovery session is already live, so leaving
  // without setting a password would drop the user into the app mid-reset.
  // Confirm the exit and sign out first, so they land back on login instead.
  Future<void> _confirmLeavePasswordStep() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel password reset?'),
        content: const Text(
          "You haven't set a new password yet. Leaving now will sign you "
          'out and return you to the login screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel reset'),
          ),
        ],
      ),
    );
    if (shouldLeave == true) {
      await _authService.signOut();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block back-out only on the password step (system back + app bar arrow);
    // the earlier steps can be left freely. A successful save pops imperatively,
    // which bypasses PopScope, so it is unaffected by this guard.
    return PopScope(
      canPop: _step != _Step.password,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeavePasswordStep();
      },
      child: Scaffold(
      // Transparent app bar so the back arrow floats on the gradient.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Reset password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildStep(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  // Pick which step's form to show based on _step.
  Widget _buildStep() {
    switch (_step) {
      case _Step.email:
        return _buildEmailStep();
      case _Step.code:
        return _buildCodeStep();
      case _Step.password:
        return _buildPasswordStep();
    }
  }

  // Shared button-or-spinner used at the bottom of every step.
  Widget _buildAction(String label, VoidCallback onPressed) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : FilledButton(
            onPressed: onPressed,
            child: Text(label),
          );
  }

  // Step 1: ask for the email.
  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Enter your email and we'll send you a 6-digit code.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Email is required.';
              if (!_isValidEmail(email)) return 'Enter a valid email.';
              return null;
            },
          ),
          const SizedBox(height: 22),
          _buildAction('Send code', _sendCode),
        ],
      ),
    );
  }

  // Step 2: ask for the 6-digit code from the email.
  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter the code we sent to '
            '${_emailController.text.trim()}.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            // Supabase's email OTP length is configurable (6-10 digits), so we
            // accept the whole numeric code instead of assuming one length.
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
            validator: (value) {
              final code = value?.trim() ?? '';
              if (code.isEmpty) return 'Code is required.';
              if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
                return 'Enter the numeric code from your email.';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          _buildAction('Verify code', _verifyCode),
        ],
      ),
    );
  }

  // Step 3: ask for the new password + confirmation.
  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choose a new password.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }
              return null;
            },
          ),
          const SizedBox(height: 22),
          _buildAction('Save password', _setNewPassword),
        ],
      ),
    );
  }
}
