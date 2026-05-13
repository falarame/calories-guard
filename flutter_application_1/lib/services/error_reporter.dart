import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Lightweight wrapper around Sentry for non-fatal errors that used to be
/// swallowed by `catch (_) {}`. Call-sites tag each report with a short
/// `where` label so breadcrumbs are searchable (e.g. "home.fetch_summary").
///
/// In debug, logs to console so developers see what production would capture.
/// In release, forwards to Sentry if SENTRY_DSN is set at build time
/// (--dart-define=SENTRY_DSN=...). If Sentry is disabled the report is a
/// no-op — the original silent behaviour is preserved.
class ErrorReporter {
  static Future<void> report(
    String where,
    Object error, [
    StackTrace? stackTrace,
  ]) async {
    if (kDebugMode) {
      debugPrint('[err:$where] $error');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('where', where);
        },
      );
    } catch (_) {
      // Never let error reporting itself throw.
    }
  }

  /// Record a structured analytics event as a Sentry breadcrumb.
  /// Call-sites include notification lifecycle hooks (scheduled, shown, tapped).
  /// Never throws — analytics should never break production flows.
  static void event(String name, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debugPrint('[event:$name] ${data ?? {}}');
    }
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'notification',
        message: name,
        data: data,
        level: SentryLevel.info,
      ));
    } catch (_) {}
  }
}
