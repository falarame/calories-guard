// Coverage for the hand-rolled AppLocalizations used on hot-path screens.
// This is the public contract: given a Locale, tr(key) returns a non-empty,
// locale-appropriate string, and never throws on a missing key.
//
// When the catalogue migrates to gen-l10n these tests will still be useful —
// the API (tr, delegate, supportedLocales) matches what gen-l10n emits.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

void main() {
  group('AppLocalizations.tr', () {
    test('returns Thai for th locale', () {
      final l10n = AppLocalizations(const Locale('th'));
      expect(l10n.tr('login.title'), 'ยินดีต้อนรับกลับ');
      expect(l10n.tr('login.cta'), 'เข้าสู่ระบบ');
    });

    test('returns English for en locale', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.tr('login.title'), 'Welcome back');
      expect(l10n.tr('login.cta'), 'Log in');
    });

    test('falls back to English when locale is unsupported', () {
      // A French-speaking tester shouldn't see Thai for missing translations —
      // English is our lowest-common-denominator fallback.
      final l10n = AppLocalizations(const Locale('fr'));
      expect(l10n.tr('login.title'), 'Welcome back');
    });

    test('returns the key itself when key is missing (never throws)', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.tr('no.such.key'), 'no.such.key');
    });

    test('supportedLocales includes th and en', () {
      final codes =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toList();
      expect(codes, containsAll(['th', 'en']));
    });

    test('every en key has a th translation (catalogue symmetry)', () {
      // The golden rule: add keys in both languages in the same commit.
      // Pull both catalogues out by calling tr() on every known key and
      // checking it's not the key itself (our missing-key sentinel).
      final en = AppLocalizations(const Locale('en'));
      final th = AppLocalizations(const Locale('th'));

      // Keys we commit to in the hot-path scope. Keep this list in sync with
      // lib/l10n/app_localizations.dart when you add new keys.
      const keys = [
        'app.name',
        'common.cancel',
        'common.confirm',
        'common.loading',
        'common.retry',
        'common.save',
        'welcome.tagline',
        'welcome.cta.login',
        'welcome.cta.register',
        'login.title',
        'login.email',
        'login.password',
        'login.forgot',
        'login.cta',
        'login.error.invalid',
        'login.error.password_min',
        'register.title',
        'register.cta',
        'record.title',
        'record.search_hint',
        'record.add_item',
        'record.save',
        'record.meal.breakfast',
        'record.meal.lunch',
        'record.meal.dinner',
        'record.meal.snack',
        'home.greeting',
        'home.today_calories',
        'home.goal',
        'home.water',
        'error.network',
        'error.timeout',
        'error.server',
        'error.ai_unavailable',
        'error.upgrade_required',
      ];

      for (final k in keys) {
        expect(en.tr(k), isNot(k), reason: 'en missing key: $k');
        expect(th.tr(k), isNot(k), reason: 'th missing key: $k');
      }
    });
  });
}
