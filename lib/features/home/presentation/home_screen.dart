import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';
import '../../../features/flash/presentation/flash_screen.dart';
import '../../../features/practice/presentation/practice_screen.dart';
import '../../../features/test/presentation/test_screen.dart';
import '../../../features/paywall/presentation/paywall_sheet.dart';
import '../../../features/settings/presentation/settings_screen.dart';
import '../../../features/parent_dashboard/presentation/parent_dashboard_screen.dart';

/// HomeScreen — grid of 13 table cards (1× through 12× + Mixed).
/// SPEC §5 | SPEC §6 Task 3
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mastery = ref.watch(masteryProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final streak = ref.watch(streakProvider);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Times Tables'),
        actions: [
          // Parent Dashboard button
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Parent Dashboard',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ParentDashboardScreen(),
                ),
              );
            },
          ),
          // Streak badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _StreakBadge(count: streak.count),
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(kPagePadding),
        child: GridView.builder(
          itemCount: 13, // 1-12 + Mixed (index 0 shown last)
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            // index 0-11 = tables 1-12, index 12 = mixed
            final tableNum = index < 12 ? index + 1 : 0;
            final tableMastery =
                mastery[tableNum] ?? const TableMastery(correct: 0, total: 0);
            final isLocked = tableNum == 0
                ? !entitlements.hasTablesUnlock
                : (tableNum >= 7 && !entitlements.hasTablesUnlock);

            return _TableCard(
              tableNum: tableNum,
              mastery: tableMastery,
              isLocked: isLocked,
              onTap: () {
                if (isLocked) {
                  _openPaywall(context, ref);
                } else {
                  _openModePicker(context, ref, tableNum);
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _openPaywall(BuildContext context, WidgetRef ref) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const PaywallSheet(),
      ),
    );
  }

  void _openModePicker(BuildContext context, WidgetRef ref, int tableNum) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _ModePicker(tableNum: tableNum),
    );
  }
}

// ---------------------------------------------------------------------------
// Streak badge
// ---------------------------------------------------------------------------

class _StreakBadge extends StatelessWidget {
  final int count;
  const _StreakBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kAccentAmber,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table card
// ---------------------------------------------------------------------------

class _TableCard extends StatelessWidget {
  final int tableNum;
  final TableMastery mastery;
  final bool isLocked;
  final VoidCallback onTap;

  const _TableCard({
    required this.tableNum,
    required this.mastery,
    required this.isLocked,
    required this.onTap,
  });

  String get _label => tableNum == 0 ? 'Mixed' : '$tableNum×';

  @override
  Widget build(BuildContext context) {
    final accuracy = mastery.accuracy;
    final Color ringColor;
    if (mastery.total == 0) {
      ringColor = kHairline;
    } else if (accuracy >= 0.9) {
      ringColor = kAccentGreen;
    } else if (accuracy >= 0.7) {
      ringColor = kAccentAmber;
    } else {
      ringColor = kAccentRed;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Card content
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress ring + label
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          value: accuracy,
                          strokeWidth: 5,
                          backgroundColor: kHairline,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(ringColor),
                        ),
                      ),
                      Text(
                        _label,
                        style: TextStyle(
                          fontSize: tableNum == 0 ? 14 : kTableLabelFontSize * 0.7,
                          fontWeight: FontWeight.bold,
                          color: kInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mastery.accuracyLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kInkSoft,
                    ),
                  ),
                ],
              ),
            ),

            // Lock overlay
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: kLockOverlay,
                    borderRadius: BorderRadius.circular(kCardRadius),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock, color: Colors.white, size: 28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode picker bottom sheet
// ---------------------------------------------------------------------------

class _ModePicker extends StatelessWidget {
  final int tableNum;
  const _ModePicker({required this.tableNum});

  String get _tableLabel => tableNum == 0 ? 'Mixed' : '$tableNum×';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(kPagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$_tableLabel Table',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kInk,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _ModeButton(
              icon: Icons.flash_on,
              label: 'Flash Cards',
              description: 'Flip cards — see if you know it',
              color: kPrimary,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FlashScreen(table: tableNum),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ModeButton(
              icon: Icons.edit,
              label: 'Practice',
              description: 'Type the answer — no time pressure',
              color: kAccentGreen,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PracticeScreen(table: tableNum),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ModeButton(
              icon: Icons.emoji_events,
              label: 'Test',
              description: '20 questions, 120 seconds',
              color: kAccentAmber,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TestScreen(table: tableNum),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
