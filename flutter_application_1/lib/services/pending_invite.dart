import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Captures referral codes from incoming deep links so the register screen
/// can apply them automatically.
///
/// Two link forms are supported:
///   * Universal link:  https://caloriesguard.app/invite/{code-or-token}
///   * Custom scheme:   com.caloriesguard.app://invite/{code-or-token}
///
/// The captured value is stored in flutter_secure_storage so it survives
/// the inevitable "user hits the link, installs the app, opens it minutes
/// later" flow.
class PendingInvite {
  PendingInvite._();

  static const _storage = FlutterSecureStorage();
  static const _key = 'pending_invite_code';

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  /// Notifies listeners (e.g. the register screen) when a new invite is captured.
  static final ValueNotifier<String?> latest = ValueNotifier<String?>(null);

  /// Wire up the link listeners. Safe to call multiple times.
  static Future<void> init() async {
    // Cold-start link (user tapped the link with the app not running)
    try {
      final initialUri = await _appLinks.getInitialLink();
      _capture(initialUri);
    } catch (_) {
      /* fall through */
    }

    _sub ??= _appLinks.uriLinkStream.listen(_capture, onError: (_) {});
  }

  /// Pull-and-clear the pending code. Returns null if no invite is queued.
  static Future<String?> consume() async {
    final fromMemory = latest.value;
    if (fromMemory != null && fromMemory.isNotEmpty) {
      latest.value = null;
      await _storage.delete(key: _key);
      return fromMemory;
    }
    final stored = await _storage.read(key: _key);
    if (stored != null && stored.isNotEmpty) {
      await _storage.delete(key: _key);
      return stored;
    }
    return null;
  }

  /// Read without clearing — used by register screen on init to show a preview.
  static Future<String?> peek() async {
    final fromMemory = latest.value;
    if (fromMemory != null && fromMemory.isNotEmpty) return fromMemory;
    return _storage.read(key: _key);
  }

  /// Extract the code from a URL: last non-empty path segment after /invite/.
  static void _capture(Uri? uri) {
    if (uri == null) return;
    final path = uri.path;
    if (!path.contains('/invite/')) {
      // also handle scheme://invite/<code> where path may be empty
      if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
        _store(uri.pathSegments.last);
      }
      return;
    }
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final last = segments.last;
    if (last.isEmpty) return;
    _store(last);
  }

  static Future<void> _store(String code) async {
    final cleaned = code.trim();
    if (cleaned.length < 4 || cleaned.length > 64) return;
    latest.value = cleaned;
    try {
      await _storage.write(key: _key, value: cleaned);
    } catch (_) {
      /* best effort */
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
