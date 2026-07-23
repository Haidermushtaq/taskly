// services/auth_service.dart
// Thin wrapper around Supabase Auth. Every auth-related Supabase call lives
// here so the screens stay focused on UI and just call these methods.
// Used by login_screen, signup_screen, and the logout button. Session
// persistence and the profiles row (via a DB trigger on signup) are handled
// by Supabase itself. Team membership and roles live in team_service.

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class AuthService {
  // Shared Supabase client instance.
  final SupabaseClient _client = Supabase.instance.client;

  // The logged-in user's email (from the auth session, not the database).
  String get myEmail => _client.auth.currentUser?.email ?? '';

  // Fetch the profiles row (name) for the currently logged-in user.
  // Used by the profile screen.
  Future<Profile> fetchMyProfile() async {
    final userId = _client.auth.currentUser!.id;
    final data =
        await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromMap(data);
  }

  // Create a new account. We pass `name` in user metadata; a database trigger
  // reads that metadata and auto-creates the matching profiles row. Throws on
  // failure so the UI can show the error.
  // emailRedirectTo makes the confirmation email link open our app directly
  // (deep link registered in AndroidManifest) instead of a web page.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
      emailRedirectTo: 'io.supabase.taskly://login-callback/',
    );
  }

  // Sign in with email + password. Supabase stores the session automatically.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out and clear the persisted session.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // --- Forgot password (OTP recovery flow, no deep links) ---

  // Step 1: email the user a 6-digit recovery code. We do NOT pass a
  // redirectTo, so Supabase sends a one-time code instead of a magic link.
  Future<void> sendPasswordResetCode({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // Step 2: verify the 6-digit code from the email. On success Supabase
  // establishes a recovery session for this user, which lets us update the
  // password in step 3.
  Future<void> verifyPasswordResetCode({
    required String email,
    required String token,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  // Step 3: set the new password on the now-recovered session.
  Future<void> updatePassword({required String newPassword}) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}

// Turns a caught auth error into a short, human-friendly sentence for a
// SnackBar. The screens catch the raw exception and pass it here so they never
// show stack-trace-y text. Kept next to the auth calls so all the messaging
// lives in one place.
String authErrorMessage(Object error) {
  // No connection, DNS failure, or a transient fetch that Supabase retries.
  if (error is SocketException || error is AuthRetryableFetchException) {
    return 'Network error, please check your connection and try again.';
  }

  // Errors Supabase Auth reports with a code/message we can humanize.
  if (error is AuthException) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    // Wrong or expired 6-digit recovery/confirmation code.
    if (code == 'otp_expired' ||
        message.contains('otp') ||
        message.contains('token')) {
      return 'That code is incorrect or has expired. Request a new one.';
    }
    // New password fails Supabase's strength/length rule.
    if (code == 'weak_password' || message.contains('password should')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    // Wrong email/password at login.
    if (code == 'invalid_credentials' ||
        message.contains('invalid login')) {
      return 'Incorrect email or password.';
    }
    // Tried to log in before clicking the confirmation link.
    if (code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      return 'Please confirm your email first — check your inbox.';
    }
    // Asked for too many emails/codes in a short window.
    if (message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    // Any other auth error: Supabase's own message is usually short and clear.
    return error.message;
  }

  // Anything unexpected (non-auth, non-network).
  return 'Something went wrong. Please try again.';
}
