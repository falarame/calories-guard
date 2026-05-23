import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

Map<String, dynamic>? _parseJson(String body) {
  if (body.isEmpty) return null;
  try {
    return jsonDecode(body) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

/// AuthService wraps backend auth plus Supabase OAuth.
///
/// Auth flow:
///   1. Backend handles email/password signup, verification, and reset
///   2. Supabase handles OAuth redirects such as Google
///   3. Backend-issued JWT is attached to API calls via [ApiClient]
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
    String password, {
    String? referralCode,
  }) async {
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

      // Email/password accounts are created in the backend only. Calling
      // Supabase signUp here would send a second OTP from Supabase and make
      // users unsure which code to enter.
      final response = await _api.post('/register', body: {
        'username': username,
        'email': email,
        'password': password,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
      });

      if (response.statusCode == 200) {
        final data = _parseJson(response.body);
        if (data == null) {
          return {
            'success': false,
            'message':
                'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง'
          };
        }
        final backendToken = data['access_token'] as String?;
        if (backendToken != null) {
          ApiClient.setManualToken(backendToken);
        }
        return {'success': true, 'data': data};
      } else {
        if (response.statusCode == 409) {
          await _supabase.auth.signOut();
          return {
            'success': false,
            'message':
                'อีเมลนี้ถูกใช้งานแล้ว กรุณาเข้าสู่ระบบหรือใช้ลืมรหัสผ่าน'
          };
        }
        final errorData = _parseJson(response.body);
        return {
          'success': false,
          'message': errorData?['detail'] as String? ??
              'Backend sync failed (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message':
            'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต'
      };
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
        final data = _parseJson(response.body);
        if (data == null) {
          return {
            'success': false,
            'message':
                'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง'
          };
        }
        // Use backend-issued JWT for all subsequent API calls
        final backendToken = data['access_token'] as String?;
        if (backendToken != null) {
          ApiClient.setManualToken(backendToken);
        }
        return {'success': true, 'data': data};
      } else {
        if (response.statusCode == 429) {
          return {
            'success': false,
            'message': 'ลองใหม่เร็วเกินไป กรุณารอสักครู่แล้วลองอีกครั้ง',
          };
        }
        final errorData = _parseJson(response.body);
        final detail = errorData?['detail'] as String?;
        return {
          'success': false,
          'message': _toThaiLoginError(detail, response.statusCode),
        };
      }
    } on AuthException catch (e) {
      final backendResult = await _loginWithBackendPassword(email, password);
      if (backendResult['success'] == true) {
        return backendResult;
      }
      // Backend 403 → email not verified
      if (backendResult['needsEmailVerification'] == true) {
        return backendResult;
      }
      final lower = e.message.toLowerCase();
      if (lower.contains('email not confirmed') ||
          lower.contains('not confirmed')) {
        try {
          await _api.post('/resend-verification-email', body: {
            'email': email,
          });
        } catch (_) {}
        return {
          'success': false,
          'needsEmailVerification': true,
          'message':
              'อีเมลนี้ยังไม่ได้ยืนยัน กรุณากรอกรหัสยืนยันจากอีเมลล่าสุด',
        };
      }
      return {
        'success': false,
        'message': backendResult['message'] ?? e.message
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต'
      };
    }
  }

  Future<Map<String, dynamic>> _loginWithBackendPassword(
    String email,
    String password,
  ) async {
    try {
      final response = await _api.post('/login', body: {
        'email': email,
        'password': password,
      });
      final data = _parseJson(response.body);
      if (response.statusCode == 200 && data != null) {
        final backendToken = data['access_token'] as String?;
        if (backendToken != null) {
          ApiClient.setManualToken(backendToken);
        }
        return {'success': true, 'data': data};
      }
      // 403 → email not verified, redirect to verify screen
      if (response.statusCode == 403) {
        return {
          'success': false,
          'needsEmailVerification': true,
          'message': 'อีเมลนี้ยังไม่ได้ยืนยัน กรุณากรอกรหัสยืนยันจากอีเมล',
        };
      }
      // 429 → slowapi returns {"error":"..."} not {"detail":"..."}
      if (response.statusCode == 429) {
        return {
          'success': false,
          'statusCode': 429,
          'message': 'ลองใหม่เร็วเกินไป กรุณารอสักครู่แล้วลองอีกครั้ง',
        };
      }
      final detail = data?['detail'] as String?;
      final thaiMessage = _toThaiLoginError(detail, response.statusCode);
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': thaiMessage,
      };
    } catch (e) {
      debugPrint('[AuthService] _loginWithBackendPassword exception: $e');
      return {
        'success': false,
        'message':
            'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
      };
    }
  }

  static String _toThaiLoginError(String? detail, int statusCode) {
    if (detail == null) return 'เข้าสู่ระบบล้มเหลว ($statusCode)';
    final lower = detail.toLowerCase();
    if (lower.contains('invalid email or password') ||
        lower.contains('invalid login')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (lower.contains('email not verified') ||
        lower.contains('not verified')) {
      return 'อีเมลนี้ยังไม่ได้ยืนยัน กรุณากรอกรหัสยืนยันจากอีเมล';
    }
    if (lower.contains('login failed') || lower.contains('please try again')) {
      return 'เกิดข้อผิดพลาดที่เซิร์ฟเวอร์ กรุณาลองใหม่ภายหลัง';
    }
    return detail;
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
        final data = _parseJson(response.body);
        final backendToken = data?['access_token'] as String?;
        if (backendToken != null) {
          ApiClient.setManualToken(backendToken);
        }
        return {'success': true, 'data': data ?? {}};
      } else {
        final errorData = _parseJson(response.body);
        return {
          'success': false,
          'message': errorData?['detail'] as String? ??
              'Social login failed (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message':
            'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต'
      };
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
  // Flow: backend OTP is the source of truth. Supabase OTP is accepted only as
  // a legacy fallback for accounts created before this backend-only flow.
  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    try {
      // Step 1 — Verify the backend OTP generated by /register or resend.
      final response = await _api.post('/verify-email', body: {
        'email': email,
        'code': code,
        'supabase_verified': false,
      });
      if (response.statusCode == 200) {
        final data = _parseJson(response.body);
        if (data == null) {
          return {
            'success': false,
            'message':
                'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง'
          };
        }
        final backendToken = data['access_token'] as String?;
        if (backendToken != null) ApiClient.setManualToken(backendToken);
        return {'success': true, 'data': data};
      }

      // Step 2 — Legacy fallback: accept Supabase OTP if the user is holding
      // an older Supabase email from a previous build.
      var supabaseVerified = false;
      String? supabaseErrorMessage;
      try {
        final authResponse = await _supabase.auth.verifyOTP(
          type: OtpType.signup,
          email: email,
          token: code,
        );
        supabaseVerified = authResponse.user != null;
      } on AuthException catch (e) {
        final lower = e.message.toLowerCase();
        final expired = lower.contains('expired') || lower.contains('invalid');
        supabaseErrorMessage = expired
            ? 'รหัสไม่ถูกต้องหรือหมดอายุ กรุณากดส่งรหัสใหม่'
            : e.message;
      }
      if (supabaseVerified) {
        final syncResponse = await _api.post('/verify-email', body: {
          'email': email,
          'code': code,
          'supabase_verified': true,
        });
        if (syncResponse.statusCode == 200) {
          final data = _parseJson(syncResponse.body);
          final backendToken = data?['access_token'] as String?;
          if (backendToken != null) ApiClient.setManualToken(backendToken);
          return {'success': true, 'data': data ?? {}};
        }
      }

      final errorData = _parseJson(response.body);
      return {
        'success': false,
        'message': errorData?['detail'] as String? ??
            supabaseErrorMessage ??
            'รหัสไม่ถูกต้องหรือหมดอายุ',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต'
      };
    }
  }

  Future<Map<String, dynamic>> resendEmailVerification(String email) async {
    try {
      final response = await _api.post('/resend-verification-email', body: {
        'email': email,
      });
      final data = _parseJson(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data?['message'] as String? ?? 'ส่งรหัสยืนยันใหม่แล้ว',
        };
      }
      return {
        'success': false,
        'message': data?['detail'] as String? ?? 'ส่งรหัสใหม่ไม่สำเร็จ',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // --- Password Reset (backend OTP fallback, independent from Supabase mail) ---

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final response = await _api.post('/password-reset/request', body: {
        'email': email,
      });
      final data = _parseJson(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'mode': 'code',
          'message': data?['message'] as String? ?? 'ส่งรหัสรีเซ็ตรหัสผ่านแล้ว',
        };
      }
      return {
        'success': false,
        'message': data?['detail'] as String? ?? 'ส่งรหัสไม่สำเร็จ',
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifyPasswordResetCode({
    required String email,
    required String code,
    required DateTime birthDate,
  }) async {
    try {
      final response = await _api.post('/password-reset/verify', body: {
        'email': email,
        'code': code,
        'birth_date': birthDate.toIso8601String().split('T').first,
      });
      final data = _parseJson(response.body);
      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200
            ? (data?['message'] as String? ?? 'ยืนยันโค้ดสำเร็จ')
            : (data?['detail'] as String? ?? 'รหัสไม่ถูกต้องหรือหมดอายุ'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String code,
    required DateTime birthDate,
    required String newPassword,
  }) async {
    try {
      final response = await _api.post('/password-reset/confirm', body: {
        'email': email,
        'code': code,
        'birth_date': birthDate.toIso8601String().split('T').first,
        'new_password': newPassword,
      });
      final data = _parseJson(response.body);
      return {
        'success': response.statusCode == 200,
        'message': response.statusCode == 200
            ? (data?['message'] as String? ?? 'รีเซ็ตรหัสผ่านสำเร็จ')
            : (data?['detail'] as String? ?? 'รีเซ็ตรหัสผ่านไม่สำเร็จ'),
      };
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
    ApiClient.setManualToken(null);
    await _supabase.auth.signOut();
  }

  // --- Session Restore ---

  Future<Map<String, dynamic>?> restoreSession() async {
    if (_supabase.auth.currentSession == null) return null;
    try {
      final response = await _api.get('/me');
      if (response.statusCode == 200) {
        final data = _parseJson(response.body);
        if (data == null) return null;
        final backendToken = data['access_token'] as String?;
        if (backendToken != null) ApiClient.setManualToken(backendToken);
        return data;
      }
    } catch (_) {}
    return null;
  }

  // --- Current User ---

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isSignedIn => _supabase.auth.currentSession != null;

  /// Listen to auth state changes.
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
}
