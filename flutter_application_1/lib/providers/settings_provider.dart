import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Keys ────────────────────────────────────────────────────────────────────
const _kLanguage = 'settings_language';
const _kTheme = 'settings_theme';
const _kConsentAccepted = 'settings_consent_accepted';

// ─── State ───────────────────────────────────────────────────────────────────
class AppSettings {
  final String language; // 'th' | 'en'
  final String theme; // 'light' | 'dark' | 'system'
  final bool consentAccepted;

  const AppSettings({
    this.language = 'th',
    this.theme = 'light',
    this.consentAccepted = false,
  });

  AppSettings copyWith({
    String? language,
    String? theme,
    bool? consentAccepted,
  }) =>
      AppSettings(
        language: language ?? this.language,
        theme: theme ?? this.theme,
        consentAccepted: consentAccepted ?? this.consentAccepted,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      language: prefs.getString(_kLanguage) ?? 'th',
      theme: prefs.getString(_kTheme) ?? 'light',
      consentAccepted: prefs.getBool(_kConsentAccepted) ?? false,
    );
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, lang);
    state = state.copyWith(language: lang);
  }

  Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> setConsentAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsentAccepted, accepted);
    state = state.copyWith(consentAccepted: accepted);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);

// Convenience: ThemeMode from settings
final themeModeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(appSettingsProvider).theme;
  switch (theme) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    default:
      return ThemeMode.light;
  }
});

// Convenience: Locale from settings
final localeProvider = Provider<Locale>((ref) {
  return Locale(ref.watch(appSettingsProvider).language);
});
