import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';
import '../../../purchases/iap_constants.dart';
import '../../paywall/presentation/paywall_sheet.dart';

/// ParentDashboard — premium-gated analytics screen.
/// SPEC §5 | SPEC §6 Task 9
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState
    extends ConsumerState<ParentDashboardScreen> {
  int _weeklyCorrect = 0;

  @override
  void initState() {
    super.initState();
    _loadWeeklyCount();
  }

  Future<void> _loadWeeklyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(TimesTablesPrefsKeys.historyJson);
    if (raw == null || !mounted) return;

    final list = jsonDecode(raw) as List<dynamic>;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    int total = 0;
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final ts = DateTime.tryParse(map['timestamp'] as String? ?? '');
      if (ts != null && ts.isAfter(cutoff)) {
        total += (map['score'] as num).toInt();
      }
    }
    if (mounted) setState(() => _weeklyCorrect = total);
  }

  Future<void> _shareReport(BuildContext context) async {
    final mastery = ref.read(masteryProvider);
    final buffer = StringBuffer();
    buffer.writeln('Times Tables Progress Report');
    buffer.writeln('Week of ${_weekLabel()}');
    buffer.writeln();
    buffer.writeln('Weekly correct answers: $_weeklyCorrect');
    buffer.writeln();
    buffer.writeln('Table-by-table accuracy:');
    for (int i = 1; i <= 12; i++) {
      final m = mastery[i];
      if (m != null) {
        buffer.writeln('  $i×  ${m.accuracyLabel.padLeft(4)} '
            '(${m.correct}/${m.total})');
      }
    }
    final mixed = mastery[0];
    if (mixed != null && mixed.total > 0) {
      buffer.writeln('  Mixed  ${mixed.accuracyLabel}');
    }

    // Best and worst tables
    final attempted =
        mastery.entries.where((e) => e.value.total > 0 && e.key > 0).toList()
          ..sort((a, b) => b.value.accuracy.compareTo(a.value.accuracy));
    if (attempted.isNotEmpty) {
      final best = attempted.first;
      buffer.writeln(
          '\nBest: ${best.key}× at ${best.value.accuracyLabel}');
      final worst = attempted.last;
      if (worst.key != best.key) {
        buffer.writeln(
            'Working on: ${worst.key}× (${worst.value.accuracyLabel})');
      }
    }
    buffer.writeln('\nShared from Times Tables Trainer');

    await Share.share(buffer.toString(), subject: 'Times Tables Progress');
  }

  String _weekLabel() {
    final now = DateTime.now();
    return '${_monthName(now.month)} ${now.day}, ${now.year}';
  }

  String _monthName(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[m];
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = ref.watch(entitlementsProvider);

    if (!entitlements.hasPremium) {
      // Show paywall — use PostFrameCallback to avoid build-time nav
      final container = ProviderScope.containerOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => UncontrolledProviderScope(
            container: container,
            child: const PaywallSheet(highlightPremium: true),
          ),
        );
      });

      return Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(title: const Text('Parent Dashboard')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(kPagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: kInkSoft, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Parent Dashboard is a Premium feature.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kInkSoft),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => UncontrolledProviderScope(
                        container: container,
                        child: const PaywallSheet(highlightPremium: true),
                      ),
                    );
                  },
                  child: const Text('Go Premium'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mastery = ref.watch(masteryProvider);
    final worst5 = ref.read(masteryProvider.notifier).worstTables(5);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share report',
            onPressed: () => _shareReport(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(kPagePadding),
        children: [
          // Weekly correct chip
          _SummaryCard(
            title: 'This Week',
            value: '$_weeklyCorrect',
            subtitle: 'correct answers',
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 20),

          // Per-table accuracy bars
          const _SectionHeader('Table Accuracy'),
          const SizedBox(height: 8),
          ...List.generate(12, (i) {
            final tableNum = i + 1;
            final m =
                mastery[tableNum] ?? const TableMastery(correct: 0, total: 0);
            return _TableAccuracyBar(tableNum: tableNum, mastery: m);
          }),
          // Mixed
          _TableAccuracyBar(
            tableNum: 0,
            mastery: mastery[0] ??
                const TableMastery(correct: 0, total: 0),
          ),
          const SizedBox(height: 20),

          // Top 5 hardest facts
          if (worst5.isNotEmpty) ...[
            const _SectionHeader('Needs Most Practice'),
            const SizedBox(height: 8),
            ...worst5.map(
              (entry) => _MissedFactTile(
                tableNum: entry.key,
                mastery: entry.value,
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table accuracy bar
// ---------------------------------------------------------------------------

class _TableAccuracyBar extends StatelessWidget {
  final int tableNum;
  final TableMastery mastery;

  const _TableAccuracyBar({required this.tableNum, required this.mastery});

  String get _label => tableNum == 0 ? 'Mixed' : '$tableNum×';

  @override
  Widget build(BuildContext context) {
    final accuracy = mastery.accuracy;
    final Color barColor;
    if (mastery.total == 0) {
      barColor = kHairline;
    } else if (accuracy >= 0.9) {
      barColor = kAccentGreen;
    } else if (accuracy >= 0.7) {
      barColor = kAccentAmber;
    } else {
      barColor = kAccentRed;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              _label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: kInk,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: accuracy,
              backgroundColor: kHairline,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 14,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              mastery.accuracyLabel,
              style: const TextStyle(fontSize: 12, color: kInkSoft),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Missed fact tile
// ---------------------------------------------------------------------------

class _MissedFactTile extends StatelessWidget {
  final int tableNum;
  final TableMastery mastery;

  const _MissedFactTile({required this.tableNum, required this.mastery});

  @override
  Widget build(BuildContext context) {
    final label = tableNum == 0 ? 'Mixed' : '$tableNum×';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: kAccentRed.withAlpha(40),
        child: Text(
          label,
          style: const TextStyle(
            color: kAccentRed,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text('$label table'),
      subtitle: Text(
        '${mastery.correct} correct out of ${mastery.total} attempts',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        mastery.accuracyLabel,
        style: const TextStyle(
          color: kAccentRed,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: kInkSoft,
      ),
    );
  }
}
