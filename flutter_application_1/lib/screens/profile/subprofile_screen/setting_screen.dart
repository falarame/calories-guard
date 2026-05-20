import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/services/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../constants/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/user_data_provider.dart';
import '../../../services/notification_helper.dart';
import '../../../services/notification_prefs_service.dart';
import '../../../theme/app_theme.dart';
import '../../../login_register/screens/welcome_screen.dart';

// ── SettingScreen ─────────────────────────────────────────────────────────────

class SettingScreen extends ConsumerStatefulWidget {
  const SettingScreen({super.key});

  @override
  ConsumerState<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends ConsumerState<SettingScreen> {
  bool _isNotificationOn = true;
  int _weighInDay = DateTime.monday;

  // Per-category and quiet hours prefs (used in _buildNotifPrefsTile summary)
  final Map<NotificationCategory, bool> _categoryEnabled = {
    for (final cat in NotificationCategory.values) cat: true,
  };
  bool _quietEnabled = false;
  int _quietStartMin = 1320; // 22:00
  int _quietEndMin = 420; // 07:00

  // Tier 4.2: hidden debug screen tap counter
  int _versionTapCount = 0;

  static const _thaiDays = {
    DateTime.monday: 'วันจันทร์',
    DateTime.tuesday: 'วันอังคาร',
    DateTime.wednesday: 'วันพุธ',
    DateTime.thursday: 'วันพฤหัสบดี',
    DateTime.friday: 'วันศุกร์',
    DateTime.saturday: 'วันเสาร์',
    DateTime.sunday: 'วันอาทิตย์',
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final enabled = await NotificationHelper.isEnabled();
    final day = await NotificationHelper.getWeighInDay();
    final catMap = <NotificationCategory, bool>{};
    for (final cat in NotificationCategory.values) {
      catMap[cat] = await NotificationHelper.isCategoryEnabled(cat);
    }
    final quietEnabled = await NotificationHelper.isQuietHoursEnabled();
    final quietStart = await NotificationHelper.getQuietHoursStartMin();
    final quietEnd = await NotificationHelper.getQuietHoursEndMin();
    if (mounted) {
      setState(() {
        _isNotificationOn = enabled;
        _weighInDay = day;
        _categoryEnabled.addAll(catMap);
        _quietEnabled = quietEnabled;
        _quietStartMin = quietStart;
        _quietEndMin = quietEnd;
      });
    }
  }

  Future<void> _onToggleNotification(bool val) async {
    setState(() => _isNotificationOn = val);
    await NotificationHelper.setEnabled(val);
    if (val) {
      await NotificationHelper.scheduleAll();
    } else {
      await NotificationHelper.cancelAllScheduled();
    }
    final userId = ref.read(userDataProvider).userId;
    NotificationPrefsService.pushDebounced(userId);
  }

  Future<void> _onPickWeighInDay() async {
    final palette = context.palette;
    final userId = ref.read(userDataProvider).userId;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(children: [
                const Icon(Icons.scale_outlined, size: 18, color: Color(0xFF628141)),
                const SizedBox(width: 8),
                Text('เลือกวันชั่งน้ำหนัก',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary)),
              ]),
            ),
            const SizedBox(height: 4),
            ..._thaiDays.entries.map((e) {
              final isSelected = e.key == _weighInDay;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? const Color(0xFF628141) : Colors.grey,
                  size: 22,
                ),
                title: Text(e.value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF628141)
                            : palette.textPrimary)),
                trailing: isSelected
                    ? const Text('(ค่าเริ่มต้น)',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey))
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _weighInDay = e.key);
                  await NotificationHelper.setWeighInDay(e.key);
                  await NotificationHelper.scheduleWeeklyWeightCheck();
                  NotificationPrefsService.pushDebounced(userId);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Notification prefs sheet ───────────────────────────────────────────────

  Future<void> _openNotifPrefsSheet() async {
    final userId = ref.read(userDataProvider).userId;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotifPrefsSheet(userId: userId),
    );
    // Refresh parent state after sheet closes
    if (mounted) await _loadPrefs();
  }

  // ── Debug sheet (Tier 4.2) ─────────────────────────────────────────────────

  void _openDebugSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _DebugNotifSheet(),
    );
  }

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      _openDebugSheet();
    }
  }

  // ── Account actions ────────────────────────────────────────────────────────

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final userId = ref.read(userDataProvider).userId;
    try {
      final response = await ApiClient().delete('/users/$userId');
      if (response.statusCode == 200) {
        await NotificationHelper.signOutCleanup(userId);
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
              content: Text(
                  l10n.tr('settings.delete_account.error', {'message': '$e'})),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).tr('common.error'))),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

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
                      color: Colors.white.withOpacity( 0.15),
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
              onTap: () => _openExternalUrl(AppConstants.privacyPolicyUrl),
            ),
            _buildTile(
              icon: Icons.article_outlined,
              title: l10n.tr('settings.terms'),
              onTap: () => _openExternalUrl(AppConstants.termsOfServiceUrl),
            ),
            _buildNotificationTile(),
            if (_isNotificationOn) _buildNotifPrefsTile(),
            _buildWeighInDayTile(),
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
              onTap: () async {
                final userId = ref.read(userDataProvider).userId;
                await NotificationHelper.signOutCleanup(userId);
                ref.read(userDataProvider.notifier).reset();
                if (!context.mounted) return;
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
                onPressed: () async {
                  final userId = ref.read(userDataProvider).userId;
                  await NotificationHelper.signOutCleanup(userId);
                  ref.read(userDataProvider.notifier).reset();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WelcomeScreen()),
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
          const SizedBox(height: 24),
          // Tap 7× to open Debug screen (Tier 4.2)
          GestureDetector(
            onTap: _onVersionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '© CaloriesGuard',
                style: TextStyle(fontSize: 12, color: palette.textFaint),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

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
                color: Colors.black.withOpacity( 0.05),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  Widget _buildNotificationTile() {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Column(children: [
      ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          activeColor: palette.brand,
          onChanged: _onToggleNotification,
        ),
      ),
      Divider(
          height: 1,
          indent: 70,
          endIndent: 20,
          color: Theme.of(context).dividerColor),
    ]);
  }

  /// Tile that opens the granular notification prefs sheet.
  Widget _buildNotifPrefsTile() {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    // Build a short summary subtitle
    final enabledCount =
        _categoryEnabled.values.where((v) => v).length;
    final total = NotificationCategory.values.length;
    final subtitle = _quietEnabled
        ? '${_minToString(_quietStartMin)}–${_minToString(_quietEndMin)} · $enabledCount/$total'
        : '$enabledCount/$total ${l10n.tr("settings.notifications.categories_section").toLowerCase()}';
    return Column(children: [
      ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(10)),
          child:
              Icon(Icons.tune_rounded, color: palette.textSecondary, size: 20),
        ),
        title: Text(l10n.tr('settings.notifications.preferences'),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary)),
        subtitle: Text(subtitle,
            style:
                TextStyle(fontSize: 12, color: palette.textSecondary)),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: palette.textFaint),
        onTap: _openNotifPrefsSheet,
      ),
      Divider(
          height: 1,
          indent: 70,
          endIndent: 20,
          color: Theme.of(context).dividerColor),
    ]);
  }

  Widget _buildWeighInDayTile() {
    final palette = context.palette;
    final dayLabel = _thaiDays[_weighInDay] ?? 'วันจันทร์';
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(10)),
        child:
            Icon(Icons.scale_outlined, color: palette.textSecondary, size: 20),
      ),
      title: Text('วันชั่งน้ำหนัก',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: palette.textPrimary)),
      subtitle: Text(dayLabel,
          style:
              TextStyle(fontSize: 13, color: palette.textSecondary)),
      trailing: Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: palette.textFaint),
      onTap: _onPickWeighInDay,
    );
  }

  static String _minToString(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

// ── _NotifPrefsSheet ──────────────────────────────────────────────────────────

class _NotifPrefsSheet extends StatefulWidget {
  const _NotifPrefsSheet({required this.userId});
  final int userId;

  @override
  State<_NotifPrefsSheet> createState() => _NotifPrefsSheetState();
}

class _NotifPrefsSheetState extends State<_NotifPrefsSheet> {
  bool _loaded = false;
  final Map<NotificationCategory, bool> _cats = {};
  bool _quietEnabled = false;
  int _quietStart = 1320; // 22:00
  int _quietEnd = 420; // 07:00
  int _bfHm = 800;
  int _lnHm = 1200;
  int _dnHm = 1800;
  List<int> _waterHH = [10, 14, 16, 20];
  // Feature 3: adaptive timing
  bool _smartTimingEnabled = false;
  Map<String, int> _smartSuggested = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final catMap = <NotificationCategory, bool>{};
    for (final cat in NotificationCategory.values) {
      catMap[cat] = await NotificationHelper.isCategoryEnabled(cat);
    }
    final qe = await NotificationHelper.isQuietHoursEnabled();
    final qs = await NotificationHelper.getQuietHoursStartMin();
    final qend = await NotificationHelper.getQuietHoursEndMin();
    final bf = await NotificationHelper.getBreakfastHm();
    final ln = await NotificationHelper.getLunchHm();
    final dn = await NotificationHelper.getDinnerHm();
    final wt = await NotificationHelper.getWaterTimesHH();
    final smartEnabled = await NotificationHelper.isSmartTimingEnabled();
    final smartSuggested = await NotificationHelper.getSmartSuggestedTimes();
    if (mounted) {
      setState(() {
        _cats.addAll(catMap);
        _quietEnabled = qe;
        _quietStart = qs;
        _quietEnd = qend;
        _bfHm = bf;
        _lnHm = ln;
        _dnHm = dn;
        _waterHH = List<int>.from(wt);
        _smartTimingEnabled = smartEnabled;
        _smartSuggested = smartSuggested;
        _loaded = true;
      });
    }
  }

  static String _hmStr(int hm) {
    final h = hm ~/ 100;
    final m = hm % 100;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String _minStr(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _pushPrefs() async {
    NotificationPrefsService.pushDebounced(widget.userId);
  }

  Future<void> _toggleCategory(NotificationCategory cat, bool val) async {
    setState(() => _cats[cat] = val);
    await NotificationHelper.setCategoryEnabled(cat, val);
    await _pushPrefs();
  }

  Future<void> _toggleQuietHours(bool val) async {
    setState(() => _quietEnabled = val);
    await NotificationHelper.setQuietHoursEnabled(val);
    await _pushPrefs();
  }

  Future<void> _pickQuietTime(bool isStart) async {
    final currentMin = isStart ? _quietStart : _quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: currentMin ~/ 60, minute: currentMin % 60),
    );
    if (picked == null || !mounted) return;
    final newMin = picked.hour * 60 + picked.minute;
    setState(() {
      if (isStart) {
        _quietStart = newMin;
      } else {
        _quietEnd = newMin;
      }
    });
    await NotificationHelper.setQuietHours(
      startMin: _quietStart,
      endMin: _quietEnd,
    );
    await _pushPrefs();
  }

  Future<void> _pickMealTime(String meal) async {
    final hm = meal == 'breakfast'
        ? _bfHm
        : meal == 'lunch'
            ? _lnHm
            : _dnHm;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hm ~/ 100, minute: hm % 100),
    );
    if (picked == null || !mounted) return;
    final newHm = picked.hour * 100 + picked.minute;
    setState(() {
      if (meal == 'breakfast') {
        _bfHm = newHm;
      } else if (meal == 'lunch') {
        _lnHm = newHm;
      } else {
        _dnHm = newHm;
      }
    });
    if (meal == 'breakfast') {
      await NotificationHelper.setBreakfastHm(newHm);
    } else if (meal == 'lunch') {
      await NotificationHelper.setLunchHm(newHm);
    } else {
      await NotificationHelper.setDinnerHm(newHm);
    }
    if (await NotificationHelper.isEnabled()) {
      await NotificationHelper.scheduleMealReminders();
    }
    await _pushPrefs();
  }

  // Feature 3: adaptive timing toggle
  Future<void> _toggleSmartTiming(bool val) async {
    setState(() => _smartTimingEnabled = val);
    await NotificationHelper.setSmartTimingEnabled(val);
    // Reload times so UI reflects smart vs manual
    final bf = await NotificationHelper.getBreakfastHm();
    final ln = await NotificationHelper.getLunchHm();
    final dn = await NotificationHelper.getDinnerHm();
    if (mounted) setState(() { _bfHm = bf; _lnHm = ln; _dnHm = dn; });
    await _pushPrefs();
  }

  Future<void> _toggleWaterHour(int h, bool v) async {
    if (!v && _waterHH.length <= 1) return; // keep at least 1
    setState(() {
      if (v) {
        _waterHH = [..._waterHH, h]..sort();
      } else {
        _waterHH = _waterHH.where((x) => x != h).toList();
      }
    });
    await NotificationHelper.setWaterTimesHH(_waterHH);
    if ((_cats[NotificationCategory.water] ?? true) &&
        await NotificationHelper.isEnabled()) {
      await NotificationHelper.scheduleWaterReminders();
    }
    await _pushPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(children: [
                  Icon(Icons.tune_rounded, color: palette.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tr('settings.notifications.sheet_title'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                  ),
                ]),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              // Content
              if (!_loaded)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // ── Categories ─────────────────────────────────────
                      _sheetSectionLabel(
                          l10n.tr('settings.notifications.categories_section'),
                          palette),
                      const SizedBox(height: 8),
                      _sheetCard([
                        ...NotificationCategory.values.indexed.map(
                          (entry) {
                            final i = entry.$1;
                            final cat = entry.$2;
                            final isLast = i ==
                                NotificationCategory.values.length - 1;
                            return Column(children: [
                              SwitchListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 2),
                                title: Text(
                                  l10n.tr(
                                      'settings.notifications.category.${cat.name}'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                value: _cats[cat] ?? true,
                                activeColor: palette.brand,
                                onChanged: (val) =>
                                    _toggleCategory(cat, val),
                              ),
                              if (!isLast)
                                Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: Theme.of(context).dividerColor),
                            ]);
                          },
                        ),
                      ], palette),
                      const SizedBox(height: 20),

                      // ── Quiet hours ────────────────────────────────────
                      _sheetSectionLabel(
                          l10n.tr(
                              'settings.notifications.quiet_hours'),
                          palette),
                      const SizedBox(height: 8),
                      _sheetCard([
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          title: Text(
                            l10n.tr(
                                'settings.notifications.quiet_hours'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${_minStr(_quietStart)} – ${_minStr(_quietEnd)}',
                            style: TextStyle(
                                fontSize: 13,
                                color: palette.textSecondary),
                          ),
                          value: _quietEnabled,
                          activeColor: palette.brand,
                          onChanged: _toggleQuietHours,
                        ),
                        if (_quietEnabled) ...[
                          Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Theme.of(context).dividerColor),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Icon(Icons.bedtime_outlined,
                                size: 20, color: palette.textSecondary),
                            title: Text(
                              l10n.tr(
                                  'settings.notifications.quiet_hours.start'),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: palette.textSecondary),
                            ),
                            trailing: Text(
                              _minStr(_quietStart),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: palette.brand),
                            ),
                            onTap: () => _pickQuietTime(true),
                          ),
                          Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Theme.of(context).dividerColor),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading: Icon(Icons.wb_sunny_outlined,
                                size: 20, color: palette.textSecondary),
                            title: Text(
                              l10n.tr(
                                  'settings.notifications.quiet_hours.end'),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: palette.textSecondary),
                            ),
                            trailing: Text(
                              _minStr(_quietEnd),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: palette.brand),
                            ),
                            onTap: () => _pickQuietTime(false),
                          ),
                        ],
                      ], palette),
                      const SizedBox(height: 20),

                      // ── Meal times (only when meal category enabled) ───
                      if (_cats[NotificationCategory.meal] == true) ...[
                        _sheetSectionLabel(
                            l10n.tr(
                                'settings.notifications.meal_times'),
                            palette),
                        const SizedBox(height: 8),
                        // Feature 3: Smart timing toggle
                        _sheetCard([
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            title: Text(
                              '⏱️ Smart Reminders',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              _smartTimingEnabled && _smartSuggested.isNotEmpty
                                  ? 'ปรับตามพฤติกรรมจริงของคุณ'
                                  : 'ปรับเวลาแจ้งเตือนตามพฤติกรรมอัตโนมัติ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: palette.textSecondary),
                            ),
                            value: _smartTimingEnabled,
                            activeThumbColor: palette.brand,
                            onChanged: _smartSuggested.isNotEmpty
                                ? _toggleSmartTiming
                                : null,
                          ),
                          if (_smartTimingEnabled && _smartSuggested.isNotEmpty) ...[
                            Divider(height: 1, indent: 16, endIndent: 16,
                                color: Theme.of(context).dividerColor),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'เวลาแนะนำจากข้อมูลจริง (30 นาทีก่อนที่คุณมักบันทึก)',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: palette.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 8, runSpacing: 4, children: [
                                    if (_smartSuggested['breakfast'] != null)
                                      _smartChip('🍳 เช้า', _smartSuggested['breakfast']!, palette),
                                    if (_smartSuggested['lunch'] != null)
                                      _smartChip('🍱 เที่ยง', _smartSuggested['lunch']!, palette),
                                    if (_smartSuggested['dinner'] != null)
                                      _smartChip('🌙 เย็น', _smartSuggested['dinner']!, palette),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                          if (_smartSuggested.isEmpty) ...[
                            Divider(height: 1, indent: 16, endIndent: 16,
                                color: Theme.of(context).dividerColor),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Text(
                                'บันทึกอาหารอย่างน้อย 3 วันเพื่อเปิดใช้ฟีเจอร์นี้',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ], palette),
                        const SizedBox(height: 12),
                        // Manual time pickers (disabled when smart timing on)
                        if (!_smartTimingEnabled) ...[
                          _sheetCard([
                            _mealTimeTile('breakfast', l10n, palette),
                            Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: Theme.of(context).dividerColor),
                            _mealTimeTile('lunch', l10n, palette),
                            Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: Theme.of(context).dividerColor),
                            _mealTimeTile('dinner', l10n, palette),
                          ], palette),
                          const SizedBox(height: 20),
                        ] else ...[
                          const SizedBox(height: 8),
                        ],
                      ],

                      // ── Water times (only when water category enabled) ─
                      if (_cats[NotificationCategory.water] == true) ...[
                        _sheetSectionLabel(
                            l10n.tr(
                                'settings.notifications.water_times'),
                            palette),
                        const SizedBox(height: 8),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (int h = 6; h <= 22; h++)
                                FilterChip(
                                  label: Text(
                                    '${h.toString().padLeft(2, '0')}:00',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  selected: _waterHH.contains(h),
                                  selectedColor:
                                      palette.brand.withOpacity( 0.15),
                                  checkmarkColor: palette.brand,
                                  side: BorderSide(
                                    color: _waterHH.contains(h)
                                        ? palette.brand
                                        : Colors.grey.shade300,
                                  ),
                                  onSelected: (v) => _toggleWaterHour(h, v),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetSectionLabel(String label, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sheetCard(List<Widget> children, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _smartChip(String label, int hm, AppPalette palette) {
    final h = hm ~/ 100;
    final m = hm % 100;
    final time = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.brand.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $time',
        style: TextStyle(
            fontSize: 12,
            color: palette.brand,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _mealTimeTile(
      String meal, AppLocalizations l10n, AppPalette palette) {
    final key = meal == 'breakfast'
        ? 'settings.notifications.breakfast_time'
        : meal == 'lunch'
            ? 'settings.notifications.lunch_time'
            : 'settings.notifications.dinner_time';
    final hm = meal == 'breakfast'
        ? _bfHm
        : meal == 'lunch'
            ? _lnHm
            : _dnHm;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        l10n.tr(key),
        style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: palette.textPrimary),
      ),
      trailing: Text(
        _hmStr(hm),
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: palette.brand),
      ),
      onTap: () => _pickMealTime(meal),
    );
  }
}

// ── _DebugNotifSheet (Tier 4.2) ───────────────────────────────────────────────

class _DebugNotifSheet extends StatefulWidget {
  const _DebugNotifSheet();

  @override
  State<_DebugNotifSheet> createState() => _DebugNotifSheetState();
}

class _DebugNotifSheetState extends State<_DebugNotifSheet> {
  List<PendingNotificationRequest> _pending = [];
  bool _loaded = false;
  String? _lastTriggered;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final pending = await NotificationHelper.getPendingRequests()
          .timeout(const Duration(seconds: 4), onTimeout: () => []);
      if (mounted) setState(() { _pending = pending; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() { _pending = []; _loaded = true; });
    }
  }

  Future<void> _trigger(String type) async {
    try {
      await NotificationHelper.triggerTestNotification(type);
    } catch (_) {}
    if (mounted) setState(() => _lastTriggered = type);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _lastTriggered = null);
  }

  Widget _triggerBtn(String type, String label, AppPalette palette,
      {Color? color}) {
    final isActive = _lastTriggered == type;
    return ElevatedButton.icon(
      onPressed: () => _trigger(type),
      icon: Icon(
        isActive ? Icons.check_rounded : Icons.send_rounded,
        size: 13,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? Colors.green
            : (color ?? palette.brand),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _debugInfoRow(
      String label, String desc, AppPalette palette) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: palette.brand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.brand)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(desc,
            style: TextStyle(fontSize: 11, color: palette.textSecondary)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surfaceCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.bug_report_outlined,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tr('settings.notifications.debug.title'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary),
                  ),
                  const Spacer(),
                  const Text('🛠️',
                      style: TextStyle(fontSize: 14)),
                ]),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              Expanded(
                child: !_loaded
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ── Original triggers ──────────────────────────
                          Text(
                            l10n.tr(
                                'settings.notifications.debug.trigger'),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textSecondary,
                                letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final entry in const {
                                'meal': '🍳 Meal',
                                'water': '💧 Water',
                                'streak': '🔥 Streak',
                                'reengagement': '😔 Re-engage',
                                'calorie': '🚨 Calorie',
                              }.entries)
                                _triggerBtn(entry.key, entry.value, palette),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── New feature triggers ───────────────────────
                          Text(
                            'NEW FEATURES',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade700,
                                letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 6),
                          // Labels explain what each test does
                          _debugInfoRow(
                            '🍱 + Actions',
                            'Meal notification พร้อม "ทานเหมือนเดิม ✓" action button',
                            palette,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _triggerBtn('meal_actions', '🍱 + Actions', palette,
                                  color: Colors.indigo),
                              _triggerBtn('gap_fill', '⏰ Gap Fill (+10s)', palette,
                                  color: Colors.deepOrange),
                              _triggerBtn('celebration_goal', '🎉 Goal!', palette,
                                  color: Colors.green.shade700),
                              _triggerBtn('celebration_streak', '🥇 Streak 7d', palette,
                                  color: Colors.amber.shade800),
                              _triggerBtn('personalized_dinner', '🥩 Protein Tip', palette,
                                  color: Colors.teal),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.orange.shade200, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('💡 วิธีทดสอบ',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange.shade800)),
                                const SizedBox(height: 4),
                                Text(
                                  '• Gap Fill: fires ใน 10 วินาที → ออกจาก app รอดู\n'
                                  '• Actions: กด notification → เห็น "ทานเหมือนเดิม" button\n'
                                  '• Goal!/Streak: แสดงทันทีใน notification tray',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade900,
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Pending list header
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${l10n.tr('settings.notifications.debug.pending')} (${_pending.length})',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textSecondary,
                                    letterSpacing: 0.5),
                              ),
                              TextButton.icon(
                                onPressed: _reload,
                                icon:
                                    const Icon(Icons.refresh, size: 16),
                                label: const Text('Refresh',
                                    style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                    foregroundColor: palette.brand),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_pending.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No pending notifications',
                                  style: TextStyle(
                                      color: palette.textSecondary),
                                ),
                              ),
                            )
                          else
                            ..._pending.map((n) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 0,
                                  color: palette.surfaceMuted,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: palette.brand
                                            .withOpacity( 0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${n.id}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: palette.brand,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      n.title ?? '(no title)',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: palette.textPrimary),
                                    ),
                                    subtitle: Text(
                                      n.body ?? '',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: palette.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
