import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/services/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/user_data_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../login_register/screens/welcome_screen.dart';

class SettingScreen extends ConsumerStatefulWidget {
  const SettingScreen({super.key});

  @override
  ConsumerState<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends ConsumerState<SettingScreen> {
  bool _isNotificationOn = true;
  bool _regionLoading = false;
  String? _selectedRegion;

  List<Map<String, String>> _regions(AppLocalizations l10n) => [
        {'code': 'central', 'label': l10n.tr('settings.region.central')},
        {'code': 'northern', 'label': l10n.tr('settings.region.northern')},
        {
          'code': 'northeastern',
          'label': l10n.tr('settings.region.northeastern')
        },
        {'code': 'southern', 'label': l10n.tr('settings.region.southern')},
      ];

  @override
  void initState() {
    super.initState();
    _fetchRegion();
  }

  String _regionLabel(AppLocalizations l10n) {
    final match =
        _regions(l10n).where((r) => r['code'] == _selectedRegion);
    return match.isEmpty ? l10n.tr('common.not_set') : match.first['label']!;
  }

  Future<void> _fetchRegion() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    setState(() => _regionLoading = true);
    try {
      final response = await ApiClient().get('/users/$userId/region');
      if (response.statusCode == 200 && mounted) {
        final data = response.body.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(response.body))
            : <String, dynamic>{};
        setState(() => _selectedRegion = data['region'] as String?);
      }
    } catch (_) {
      // Settings still works if the backend is temporarily unreachable.
    } finally {
      if (mounted) setState(() => _regionLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final userId = ref.read(userDataProvider).userId;
    try {
      final response = await ApiClient().delete('/users/$userId');
      if (response.statusCode == 200) {
        ref.read(userDataProvider.notifier).resetDailyFood();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.tr('settings.delete_account.success')),
                backgroundColor: Colors.grey),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.tr(
                  'settings.delete_account.error',
                  {'message': '$e'})),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.tr('settings.delete_account.confirm_title'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(l10n.tr('settings.delete_account.confirm_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.tr('common.cancel'),
                  style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Text(l10n.tr('settings.delete_account.confirm_cta'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: palette.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(l10n.tr('common.close'))),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(appSettingsProvider).language;
    final palette = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(l10n.tr('settings.language.picker_title'),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary)),
          const SizedBox(height: 16),
          _languageOption(
            flag: '🇬🇧',
            label: 'English',
            code: 'en',
            selected: current == 'en',
          ),
          const SizedBox(height: 10),
          _languageOption(
            flag: '🇹🇭',
            label: 'ไทย (Thai)',
            code: 'th',
            selected: current == 'th',
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _languageOption({
    required String flag,
    required String label,
    required String code,
    required bool selected,
  }) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () {
        ref.read(appSettingsProvider.notifier).setLanguage(code);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              l10n.tr('settings.language.changed', {'label': label})),
          backgroundColor: palette.brand,
          duration: const Duration(seconds: 2),
        ));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? palette.brandSoft : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? palette.brand : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary)),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: palette.brand, size: 22)
          else
            Icon(Icons.circle_outlined,
                color: palette.textFaint, size: 22),
        ]),
      ),
    );
  }

  void _showThemeSelector() {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(appSettingsProvider).theme;
    final palette = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(l10n.tr('settings.theme.picker_title'),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary)),
          const SizedBox(height: 16),
          _themeOption(
            icon: Icons.wb_sunny_rounded,
            label: l10n.tr('settings.theme.light'),
            code: 'light',
            color: const Color(0xFFF39C12),
            selected: current == 'light',
          ),
          const SizedBox(height: 10),
          _themeOption(
            icon: Icons.nightlight_round,
            label: l10n.tr('settings.theme.dark'),
            code: 'dark',
            color: const Color(0xFF2C3E50),
            selected: current == 'dark',
          ),
          const SizedBox(height: 10),
          _themeOption(
            icon: Icons.settings_system_daydream_rounded,
            label: l10n.tr('settings.theme.system'),
            code: 'system',
            color: const Color(0xFF3498DB),
            selected: current == 'system',
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _themeOption({
    required IconData icon,
    required String label,
    required String code,
    required Color color,
    required bool selected,
  }) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () {
        ref.read(appSettingsProvider.notifier).setTheme(code);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(l10n.tr('settings.theme.changed', {'label': label})),
          backgroundColor: palette.brand,
          duration: const Duration(seconds: 2),
        ));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary)),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color, size: 22)
          else
            Icon(Icons.circle_outlined,
                color: palette.textFaint, size: 22),
        ]),
      ),
    );
  }

  void _showRegionSelector() {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(l10n.tr('settings.region.picker_title'),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary)),
          const SizedBox(height: 16),
          _regionOption(
              code: null,
              label: l10n.tr('settings.region.use_central'),
              isLast: false),
          const SizedBox(height: 10),
          ..._regions(l10n).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _regionOption(
                  code: r['code'],
                  label: r['label']!,
                  isLast: r == _regions(l10n).last,
                ),
              )),
        ]),
      ),
    );
  }

  Widget _regionOption({
    required String? code,
    required String label,
    required bool isLast,
  }) {
    final palette = context.palette;
    final selected = _selectedRegion == code;
    return GestureDetector(
      onTap: () => _saveRegion(code, label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? palette.brandSoft : palette.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? palette.brand : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.brand.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on_outlined,
                color: palette.brand, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary)),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: palette.brand, size: 22)
          else
            Icon(Icons.circle_outlined,
                color: palette.textFaint, size: 22),
        ]),
      ),
    );
  }

  Future<void> _saveRegion(String? code, String label) async {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    try {
      final response = await ApiClient().put(
        '/users/$userId/region',
        body: {'region': code},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _selectedRegion = code);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              l10n.tr('settings.region.changed', {'label': label})),
          backgroundColor: palette.brand,
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.tr('settings.region.failed',
              {'code': '${response.statusCode}'})),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l10n.tr('common.error')}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final settings = ref.watch(appSettingsProvider);
    final langLabel = settings.language == 'th' ? 'ไทย' : 'English';
    final themeLabel = switch (settings.theme) {
      'dark' => l10n.tr('settings.theme.dark'),
      'system' => l10n.tr('settings.theme.system'),
      _ => l10n.tr('settings.theme.light'),
    };

    return Scaffold(
      backgroundColor: palette.surfaceMuted,
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.brandStrong, palette.brand],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              Expanded(
                child: Text(l10n.tr('settings.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(width: 40),
            ]),
          ),

          const SizedBox(height: 24),

          _buildSectionLabel(l10n.tr('settings.group.general')),
          const SizedBox(height: 10),
          _buildCard([
            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: l10n.tr('settings.privacy'),
              onTap: () => _showInfoDialog(
                  l10n.tr('settings.privacy'), l10n.tr('settings.privacy.body')),
            ),
            _buildNotificationTile(),
          ]),

          const SizedBox(height: 16),

          _buildSectionLabel(l10n.tr('settings.group.display')),
          const SizedBox(height: 10),
          _buildCard([
            _buildTileWithValue(
              icon: Icons.language_rounded,
              title: l10n.tr('settings.language'),
              value: langLabel,
              onTap: _showLanguageSelector,
            ),
            _buildTileWithValue(
              icon: Icons.location_on_outlined,
              title: l10n.tr('settings.region'),
              value: _regionLoading
                  ? l10n.tr('settings.loading')
                  : _regionLabel(l10n),
              onTap: _showRegionSelector,
            ),
            _buildTileWithValue(
              icon: Icons.palette_outlined,
              title: l10n.tr('settings.theme'),
              value: themeLabel,
              isLast: true,
              onTap: _showThemeSelector,
            ),
          ]),

          const SizedBox(height: 16),

          _buildSectionLabel(l10n.tr('settings.group.support')),
          const SizedBox(height: 10),
          _buildCard([
            _buildTile(
              icon: Icons.lightbulb_outline_rounded,
              title: l10n.tr('settings.suggest_feature'),
              onTap: () => _showInfoDialog(l10n.tr('settings.contact'),
                  l10n.tr('settings.suggest_feature.body')),
            ),
            _buildTile(
              icon: Icons.help_outline_rounded,
              title: l10n.tr('settings.help'),
              isLast: true,
              onTap: () => _showInfoDialog(
                  l10n.tr('settings.help'), l10n.tr('settings.help.body')),
            ),
          ]),

          const SizedBox(height: 16),

          _buildSectionLabel(l10n.tr('settings.group.about')),
          const SizedBox(height: 10),
          _buildCard([
            _buildTile(
              icon: Icons.star_outline_rounded,
              title: l10n.tr('settings.rate'),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.tr('settings.rate.thanks')))),
            ),
            _buildTile(
              icon: Icons.info_outline_rounded,
              title: l10n.tr('settings.about'),
              isLast: true,
              onTap: () => _showInfoDialog(
                  l10n.tr('settings.about'), l10n.tr('settings.about.body')),
            ),
          ]),

          const SizedBox(height: 16),

          _buildSectionLabel(l10n.tr('settings.group.account')),
          const SizedBox(height: 10),
          _buildCard([
            _buildTile(
              icon: Icons.swap_horiz_rounded,
              title: l10n.tr('settings.switch_account'),
              onTap: () {
                ref.read(userDataProvider.notifier).reset();
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false);
              },
            ),
            _buildTile(
              icon: Icons.delete_outline_rounded,
              title: l10n.tr('settings.delete_account'),
              isDestructive: true,
              isLast: true,
              onTap: _showDeleteConfirmDialog,
            ),
          ]),

          const SizedBox(height: 32),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(userDataProvider.notifier).reset();
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false);
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.tr('settings.logout'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
                letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    bool isLast = false,
    bool isDestructive = false,
  }) {
    final palette = context.palette;
    return Column(children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: palette.textSecondary, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : palette.textPrimary)),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: palette.textFaint),
        onTap: onTap,
      ),
      if (!isLast)
        Divider(
            height: 1,
            indent: 70,
            endIndent: 20,
            color: Theme.of(context).dividerColor),
    ]);
  }

  Widget _buildTileWithValue({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    final palette = context.palette;
    return Column(children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: palette.textSecondary, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: palette.textFaint),
        ]),
        onTap: onTap,
      ),
      if (!isLast)
        Divider(
            height: 1,
            indent: 70,
            endIndent: 20,
            color: Theme.of(context).dividerColor),
    ]);
  }

  Widget _buildNotificationTile() {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Column(children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.notifications_outlined,
              color: palette.textSecondary, size: 20),
        ),
        title: Text(l10n.tr('settings.notifications'),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary)),
        trailing: Switch(
          value: _isNotificationOn,
          activeThumbColor: palette.brand,
          onChanged: (val) => setState(() => _isNotificationOn = val),
        ),
      ),
      Divider(
          height: 1,
          indent: 70,
          endIndent: 20,
          color: Theme.of(context).dividerColor),
    ]);
  }
}
