import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class DataConsentScreen extends ConsumerStatefulWidget {
  const DataConsentScreen({super.key, required this.next});

  /// Builder for the screen to navigate to once consent is granted.
  /// We take a builder (not a Widget) so the destination is created fresh
  /// after acceptance — important for screens that read providers in build.
  final WidgetBuilder next;

  @override
  ConsumerState<DataConsentScreen> createState() => _DataConsentScreenState();
}

class _DataConsentScreenState extends ConsumerState<DataConsentScreen> {
  bool _isAccepted = false;
  bool _saving = false;

  Future<void> _onSave() async {
    final l10n = AppLocalizations.of(context);
    if (!_isAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.tr('consent.error.must_accept')),
      ));
      return;
    }
    setState(() => _saving = true);
    await ref.read(appSettingsProvider.notifier).setConsentAccepted(true);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: widget.next),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.surfaceMuted,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 200,
            height: 8,
            child: LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Theme.of(context).dividerColor,
              color: palette.brand,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                l10n.tr('consent.heading'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: palette.brandStrong,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.tr('consent.body1'),
                style: TextStyle(
                  fontSize: 16,
                  color: palette.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.tr('consent.body2'),
                style: TextStyle(
                  fontSize: 16,
                  color: palette.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              InkWell(
                onTap: () => setState(() => _isAccepted = !_isAccepted),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color:
                              _isAccepted ? palette.brand : palette.surfaceCard,
                          border: Border.all(color: palette.brand, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _isAccepted
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.tr('consent.checkbox'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        palette.brand.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          l10n.tr('consent.cta'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes the appropriate post-auth screen, gating on the consent flag.
/// Uses [pushAndRemoveUntil] so the back stack is cleaned up.
void routeAfterAuth(
  BuildContext context,
  WidgetRef ref, {
  required WidgetBuilder destination,
  bool requireConsent = true,
}) {
  final accepted = ref.read(appSettingsProvider).consentAccepted;
  final shouldShowConsent = requireConsent && !accepted;
  final route = MaterialPageRoute(
    builder: shouldShowConsent
        ? (ctx) => DataConsentScreen(next: destination)
        : destination,
  );
  Navigator.pushAndRemoveUntil(context, route, (_) => false);
}
