import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../purchases/iap_constants.dart';

/// Immutable snapshot of mastery data for a single table (or 'mixed').
class TableMastery {
  final int correct;
  final int total;

  const TableMastery({required this.correct, required this.total});

  /// Accuracy as a fraction 0.0–1.0. Returns 0.0 if no attempts.
  double get accuracy => total == 0 ? 0.0 : correct / total;

  /// Human-readable accuracy percentage string (e.g. "84%").
  String get accuracyLabel =>
      total == 0 ? '0%' : '${(accuracy * 100).round()}%';

  /// Mastery status label for the HomeScreen ring badge.
  String get statusLabel {
    if (total == 0) return 'Not started';
    final pct = accuracy * 100;
    if (pct >= 90) return 'Mastered!';
    if (pct >= 70) return 'Almost there';
    return 'Keep going!';
  }

  TableMastery copyWith({int? correct, int? total}) {
    return TableMastery(
      correct: correct ?? this.correct,
      total: total ?? this.total,
    );
  }

  @override
  String toString() => 'TableMastery(correct: $correct, total: $total)';
}

/// Holds mastery data for all tables 1–12 plus the 'mixed' pseudo-table (index 0).
///
/// Key convention: index 1–12 = individual tables; index 0 = mixed.
typedef MasteryState = Map<int, TableMastery>;

/// Notifier that reads/writes mastery data from SharedPreferences.
/// Mobile-developer: implement the TODOs in each method body.
class MasteryNotifier extends Notifier<MasteryState> {
  @override
  MasteryState build() {
    _loadFromPrefs();
    // Return all-zero state synchronously; _loadFromPrefs() will update state.
    return {
      for (int i = 0; i <= 12; i++) i: const TableMastery(correct: 0, total: 0),
    };
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final updated = <int, TableMastery>{};

    // Tables 1–12
    for (int i = 1; i <= 12; i++) {
      final correct =
          prefs.getInt(TimesTablesPrefsKeys.masteryCorrect(i)) ?? 0;
      final total = prefs.getInt(TimesTablesPrefsKeys.masteryTotal(i)) ?? 0;
      updated[i] = TableMastery(correct: correct, total: total);
    }

    // Mixed (index 0)
    final mixedCorrect =
        prefs.getInt(TimesTablesPrefsKeys.masteryMixedCorrect) ?? 0;
    final mixedTotal =
        prefs.getInt(TimesTablesPrefsKeys.masteryMixedTotal) ?? 0;
    updated[0] = TableMastery(correct: mixedCorrect, total: mixedTotal);

    state = updated;
  }

  /// Records an answer for [table] (1–12, or 0 for mixed).
  /// [wasCorrect] determines whether to increment the correct counter.
  Future<void> recordAnswer({
    required int table,
    required bool wasCorrect,
  }) async {
    assert(table >= 0 && table <= 12, 'table must be 0–12');
    final current = state[table] ?? const TableMastery(correct: 0, total: 0);
    final updated = current.copyWith(
      correct: wasCorrect ? current.correct + 1 : current.correct,
      total: current.total + 1,
    );
    state = {...state, table: updated};
    await _persistTable(table, updated);
  }

  Future<void> _persistTable(int table, TableMastery mastery) async {
    final prefs = await SharedPreferences.getInstance();
    if (table == 0) {
      await prefs.setInt(TimesTablesPrefsKeys.masteryMixedCorrect, mastery.correct);
      await prefs.setInt(TimesTablesPrefsKeys.masteryMixedTotal, mastery.total);
    } else {
      await prefs.setInt(
          TimesTablesPrefsKeys.masteryCorrect(table), mastery.correct);
      await prefs.setInt(
          TimesTablesPrefsKeys.masteryTotal(table), mastery.total);
    }
  }

  /// Returns the top-N tables with the lowest accuracy (for Parent Dashboard).
  /// Excludes tables with zero attempts.
  List<MapEntry<int, TableMastery>> worstTables(int n) {
    final attempted = state.entries
        .where((e) => e.value.total > 0)
        .toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));
    return attempted.take(n).toList();
  }
}

final masteryProvider =
    NotifierProvider<MasteryNotifier, MasteryState>(MasteryNotifier.new);
