import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/user_data_provider.dart';
import '../../services/api_client.dart';
import '../../services/error_reporter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/weight_chart_card.dart';

class WeightChartScreen extends ConsumerStatefulWidget {
  const WeightChartScreen({super.key});

  @override
  ConsumerState<WeightChartScreen> createState() => _WeightChartScreenState();
}

class _WeightChartScreenState extends ConsumerState<WeightChartScreen> {
  List<Map<String, dynamic>> _weightLogs = [];
  Map<String, dynamic> _goalProgress = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        ApiClient().get('/users/$userId/weight_logs'),
        ApiClient().get('/users/$userId/goal_progress'),
      ]);
      if (!mounted) return;
      final logsRes = results[0];
      final goalRes = results[1];
      List<Map<String, dynamic>> logs = [];
      if (logsRes.statusCode == 200) {
        final data = json.decode(logsRes.body) as List;
        logs = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      Map<String, dynamic> goal = {};
      if (goalRes.statusCode == 200) {
        goal = Map<String, dynamic>.from(json.decode(goalRes.body));
      }
      setState(() {
        _weightLogs = logs;
        _goalProgress = goal;
        _loading = false;
      });
    } catch (e, st) {
      ErrorReporter.report('weight.fetch', e, st);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRecordSheet() async {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final controller = TextEditingController(
        text: ref.read(userDataProvider).weight > 0
            ? ref.read(userDataProvider).weight.toStringAsFixed(1)
            : '');
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Form(
                  key: formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.tr('weight.dialog.title'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: l10n.tr('weight.dialog.hint'),
                        suffixText: l10n.tr('unit.kg'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) {
                        final parsed = double.tryParse((v ?? '').trim());
                        if (parsed == null ||
                            parsed.isNaN ||
                            parsed.isInfinite ||
                            parsed < 20 ||
                            parsed > 400) {
                          return l10n.tr('weight.dialog.error.invalid');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              submitting ? null : () => Navigator.pop(sheetCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(l10n.tr('common.cancel')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (!(formKey.currentState?.validate() ??
                                      false)) {
                                    return;
                                  }
                                  setSheetState(() => submitting = true);
                                  final ok = await _submitWeight(
                                      double.parse(controller.text.trim()));
                                  if (!ctx.mounted) return;
                                  if (ok) {
                                    Navigator.pop(sheetCtx);
                                  } else {
                                    setSheetState(() => submitting = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(l10n.tr('weight.dialog.save'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _submitWeight(double kg) async {
    final l10n = AppLocalizations.of(context);
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return false;
    try {
      final body = {
        'weight_kg': kg,
        'recorded_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      };
      final res = await ApiClient().post('/weight_logs/$userId', body: body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        ref.read(userDataProvider.notifier).setCurrentWeight(kg);
        await _fetch();
        if (!mounted) return true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.tr('weight.dialog.success')),
            backgroundColor: context.palette.brand));
        return true;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.tr('weight.dialog.error.failed')),
            backgroundColor: Colors.red));
      }
      return false;
    } catch (e, st) {
      ErrorReporter.report('weight.submit', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.tr('weight.dialog.error.failed')),
            backgroundColor: Colors.red));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    final userData = ref.watch(userDataProvider);

    return Scaffold(
      backgroundColor: palette.surfaceMuted,
      appBar: AppBar(
        title: Text(l10n.tr('weight.title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetch,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    WeightChartCard(
                      weightLogs: _weightLogs,
                      goalProgress: _goalProgress,
                      targetWeight: userData.targetWeight.toDouble(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecordSheet,
        backgroundColor: palette.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.tr('weight.record_cta'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
