import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        final errorData = _parseJson(response.body);
        return {
          'success': false,
          'message': errorData?['detail'] as String? ??
              'เข้าสู่ระบบล้มเหลว (${response.statusCode})',
        };
      }
    } on AuthException catch (e) {
      final backendResult = await _loginWithBackendPassword(email, password);
      if (backendResult['success'] == true) {
        return backendResult;
      }
      final lower = e.message.toLowerCase();
      if (lower.contains('email not confirmed') ||
          lower.contains('not confirmed')) {
        try {
          await _supabase.auth.resend(type: OtpType.signup, email: email);
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
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': data?['detail'] as String? ?? 'เข้าสู่ระบบล้มเหลว',
      };
    } catch (_) {
      return {'success': false, 'message': 'เข้าสู่ระบบล้มเหลว'};
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
  // Flow: try Supabase OTP first, then fall back to the backend OTP generated
  // by /register or /resend-verification-email.
  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    var supabaseVerified = false;
    String? supabaseErrorMessage;
    try {
      // Step 1 — Verify the OTP with Supabase Auth.
      final authResponse = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: code,
      );
      if (authResponse.user == null) {
        supabaseErrorMessage = 'รหัสไม่ถูกต้องหรือหมดอายุ';
      } else {
        supabaseVerified = true;
      }
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      final expired = lower.contains('expired') || lower.contains('invalid');
      supabaseErrorMessage =
          expired ? 'รหัสไม่ถูกต้องหรือหมดอายุ กรุณากดส่งรหัสใหม่' : e.message;
    }

    try {
      final response = await _api.post('/verify-email', body: {
        'email': email,
        'code': code,
        'supabase_verified': supabaseVerified,
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
    AuthException? supabaseError;
    try {
      try {
        await _supabase.auth.resend(type: OtpType.signup, email: email);
      } on AuthException catch (e) {
        supabaseError = e;
      } catch (_) {
        // Backend OTP is the source of truth for this fallback flow.
      }

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
        'message': data?['detail'] as String? ??
            supabaseError?.message ??
            'ส่งรหัสใหม่ไม่สำเร็จ',
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
    await _supabase.auth.signOut();
  }

  // --- Current User ---

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  bool get isSignedIn => _supabase.auth.currentSession != null;

  /// Listen to auth state changes.
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
}
