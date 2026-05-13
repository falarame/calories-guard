import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'error_reporter.dart';
import 'notification_helper.dart';

/// Background handler — ต้องเป็น top-level function (ไม่ใช่ method ของ class)
/// Firebase เรียกตัวนี้ใน isolate แยก ตอนแอปถูก killed หรืออยู่ background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase จะแสดง notification อัตโนมัติสำหรับ notification-type messages
  // ถ้าเป็น data-only message ค่อย show เอง (ไม่จำเป็นสำหรับ use case ปัจจุบัน)
  await Firebase.initializeApp();
}

class FcmService {
  static bool _initialized = false;

  /// เรียกใน main() ก่อน runApp() เพื่อ initialize Firebase
  static Future<void> initFirebase() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
  }

  /// เรียกหลัง Firebase.initializeApp() — setup message handlers
  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    try {
      // ขอ permission (สำคัญสำหรับ iOS และ Android 13+)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      // Track denied สำหรับ banner UX ใน Tier 2.5
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notification_permission_denied', true);
      }

      // ── Foreground message: show ผ่าน flutter_local_notifications ────────────
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // ── Background tap: แอปอยู่ background แล้ว user แตะ notification ──────
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // ── Terminated tap: แอปถูก kill แล้ว user เปิดจาก notification ─────────
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onMessageOpenedApp(initial);
    } catch (e) {
      debugPrint('FcmService.init skipped: $e');
    }
  }

  /// ลบ FCM token ทั้งฝั่ง device และ backend — เรียกตอน logout
  static Future<void> clearToken(int userId) async {
    if (kIsWeb) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      if (userId != 0) {
        await ApiClient().delete('/users/$userId/fcm_token');
      }
      debugPrint('FCM token cleared for user $userId');
    } catch (e) {
      debugPrint('FCM token clear skipped: $e');
    }
  }

  /// ส่ง FCM token ขึ้น backend — เรียกหลัง login สำเร็จและมี userId
  static Future<void> uploadToken(int userId) async {
    if (kIsWeb || userId == 0) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await ApiClient().put('/users/$userId/fcm_token', body: {'fcm_token': token});
      debugPrint('FCM token uploaded for user $userId');

      // Refresh เมื่อ token เปลี่ยน (เช่น ล้างข้อมูลแอป, re-install)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await ApiClient().put('/users/$userId/fcm_token', body: {'fcm_token': newToken});
        } catch (e, st) {
          ErrorReporter.report('fcm.token_refresh', e, st);
        }
      });
    } catch (e) {
      debugPrint('FCM token upload skipped: $e');
    }
  }

  // ─── Private handlers ──────────────────────────────────────────────────────

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    // FCM ไม่แสดง notification อัตโนมัติตอน foreground → ต้อง show เอง
    await NotificationHelper.showNotification(
      id: message.hashCode & 0x7FFFFFFF,
      title: notification.title ?? 'CaloriesGuard',
      body: notification.body ?? '',
      payload: message.data['payload'] as String?,
    );
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    final payload = message.data['payload'] as String?;
    if (payload != null && payload.isNotEmpty) {
      // ส่งให้ MainScreen handle ผ่าน pendingPayload (P2 deep linking)
      NotificationHelper.pendingPayload.value = payload;
    }
  }
}
