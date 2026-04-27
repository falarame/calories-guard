import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

/// AuthService wraps Supabase Auth and syncs user data with our backend.
///
/// Auth flow:
///   1. Supabase handles sign-up/sign-in/social-login and issues JWT
///   2. JWT is automatically attached to API calls via [ApiClient]
///   3. Backend verifies JWT and maps Supabase UUID → our user_id
class AuthService {
  final _supabase = Supabase.instance.client;
  final _api = ApiClient();

  String get oauthRedirectTo =>
      kIsWeb ? Uri.base.origin : 'com.caloriesguard.app://login-callback';

  // --- Live availability check (for register screen) ---

  /// Returns {available: bool, reason: "format"|"taken"|null, networkError: bool}.
  /// `networkError: true` means we couldn't reach the backend — UI should stay
  /// neutral (don't block the user from submitting).
  Future<Map<String, dynamic>> checkEmailAvailable(String email) async {
    try {
      final response = await _api.get(
        '/check-email?email=${Uri.encodeQueryComponent(email)}',
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'available': body['available'] == true,
          'reason': body['reason'],
          'networkError': false,
        };
      }
      return {'available': true, 'reason': null, 'networkError': true};
    } catch (_) {
      return {'available': true, 'reason': null, 'networkError': true};
    }
  }

  // --- Email/Password Registration ---

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      // 1. Sign up with Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (authResponse.user == null) {
        return {'success': false, 'message': 'Registration failed'};
      }

      // 2. Sync with our backend (create user row in our DB)
      final response = await _api.post('/register', body: {
        'username': username,
        'email': email,
        'password': password,
        'supabase_uid': authResponse.user!.id,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final backendToken = data['access_token'] as String?;
        if (backendToken != null) {
          ApiClient.setManualToken(backendToken);
        }
        return {'success': true, 'data': data};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['detail'] ?? 'Backend sync failed',
        };
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // --- Email/Password Login ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // 1. Sign in with Supabase Auth
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return {'success': false, 'message': 'Login failed'};
      }

      final supabaseToken = authResponse.session?.accessToken;

      // 2. Fetch user profile from our backend
      final response = await _api.post(
        '/login',
        body: {
          'email': email,
          'password': password,
        },
        extraHeaders: supabaseToken == null
            ? null
            : {'Authorization': 'Bearer $supabaseToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Use backend-issued JWT for all subsequent API calls
        final backendToken = data['access_token'] as String?;
        if (backendToken != null) {
          ApiClient.setManualToken(backendToken);
        }
        return {'success': true, 'data': data};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['detail'] ?? 'Login failed',
        };
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // --- Social Login (Google / Facebook) ---

  Future<Map<String, dynamic>> socialLogin({
    required String email,
    required String name,
    required String uid,
    required String provider,
  }) async {
    try {
      // For social login, sign in via Supabase OAuth
      // The Flutter UI should have already called signInWithOAuth
      // which sets the session. We just sync with our backend.
      final response = await _api.post('/social-login', body: {
        'email': email,
        'name': name,
        'uid': uid,
        'provider': provider,
      });

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['detail'] ?? 'Social login failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  /// Sign in with Google via Supabase OAuth.
  Future<bool> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: oauthRedirectTo,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sign in with Facebook via Supabase OAuth.
  Future<bool> signInWithFacebook() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: oauthRedirectTo,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Email Verification ---
  //
  // Flow: Supabase Auth sends a 6-digit OTP on signUp (or a link, depending on
  // the Supabase dashboard Email Template). We verify the OTP with Supabase
  // directly, then sync the verified flag to our backend so /login can pass.
  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    try {
      // Step 1 — Verify the OTP with Supabase Auth.
      final authResponse = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: code,
      );
      if (authResponse.user == null) {
        return {'success': false, 'message': 'รหัสไม่ถูกต้องหรือหมดอายุ'};
      }

      // Step 2 — Sync with our backend so users.is_email_verified = TRUE.
      // If the backend call fails, we still consider the verification successful
      // from the user's perspective (Supabase is the source of truth).
      try {
        final response = await _api.post('/verify-email', body: {
          'email': email,
          'code': code,
        });
        if (response.statusCode == 200) {
          return {'success': true, 'data': jsonDecode(response.body)};
        }
      } catch (_) {
        // Swallow backend sync errors — Supabase already confirmed the email.
      }
      return {
        'success': true,
        'data': {'message': 'ยืนยันอีเมลสำเร็จ'}
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> resendEmailVerification(String email) async {
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
      return {'success': true, 'message': 'Verification email sent'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // --- Password Reset (Supabase handles this) ---

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return {'success': true, 'message': 'Password reset email sent'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // --- Profile Update ---

  Future<bool> updateProfile(int userId, Map<String, dynamic> data) async {
    try {
      final response = await _api.put('/users/$userId', body: data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Sign Out ---

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // --- Current User ---

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isSignedIn => _supabase.auth.currentSession != null;

  /// Listen to auth state changes.
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
}
