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
      final availability = await checkEmailAvailable(email);
      if (availability['networkError'] != true &&
          availability['available'] != true &&
          availability['reason'] != 'unverified') {
        return {
          'success': false,
          'message': availability['reason'] == 'taken'
              ? 'อีเมลนี้ถูกใช้งานแล้ว กรุณาเข้าสู่ระบบหรือใช้ลืมรหัสผ่าน'
              : 'รูปแบบอีเมลไม่ถูกต้อง',
        };
      }

      // 1. Sign up with Supabase Auth
      String? supabaseUid;
      try {
        final authResponse = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {'username': username},
        );
        supabaseUid = authResponse.user?.id;
      } on AuthException catch (e) {
        final lower = e.message.toLowerCase();
        final alreadyExists =
            lower.contains('already') || lower.contains('registered');
        if (!alreadyExists) {
          return {'success': false, 'message': e.message};
        }
        // The user may exist in Supabase Auth from a previous interrupted
        // registration. Continue with our backend's idempotent unverified-user
        // flow, and ask Supabase to resend its signup OTP when possible.
        try {
          await _supabase.auth.resend(type: OtpType.signup, email: email);
        } catch (_) {
          // Backend also sends its own OTP; don't block recovery here.
        }
      }

      // 2. Sync with our backend (create user row in our DB)
      final response = await _api.post('/register', body: {
        'username': username,
        'email': email,
        'password': password,
        if (supabaseUid != null) 'supabase_uid': supabaseUid,
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
        if (response.statusCode == 409) {
          await _supabase.auth.signOut();
        }
        return {
          'success': false,
          'message': response.statusCode == 409
              ? 'อีเมลนี้ถูกใช้งานแล้ว กรุณาเข้าสู่ระบบหรือใช้ลืมรหัสผ่าน'
              : errorData['detail'] ?? 'Backend sync failed',
        };
      }
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
    var supabaseVerified = false;
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
      supabaseVerified = true;
    } on AuthException {
      // Some interrupted registrations only have the backend OTP. Fall through
      // and let the backend validate its latest email_verification_codes row.
    }

    try {
      final response = await _api.post('/verify-email', body: {
        'email': email,
        'code': code,
        'supabase_verified': supabaseVerified,
      });
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      final errorData = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorData['detail'] ?? 'รหัสไม่ถูกต้องหรือหมดอายุ',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> resendEmailVerification(String email) async {
    try {
      try {
        await _supabase.auth.resend(type: OtpType.signup, email: email);
      } catch (_) {
        // Continue to backend resend for interrupted registrations.
      }
      try {
        await _api.post('/resend-verification-email', body: {'email': email});
      } catch (_) {
        // If Supabase resend succeeded, this is still good enough.
      }
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
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: oauthRedirectTo,
      );
      return {'success': true, 'message': 'Password reset email sent'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePassword(String password) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
      return {'success': true};
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
