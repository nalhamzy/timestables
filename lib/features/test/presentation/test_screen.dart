import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';
import '../../../purchases/iap_constants.dart';
import '../../../widgets/number_pad.dart';

/// Immutable result from a single Test session.
class TestResult {
  final int table;
  final int score;
  final int totalQ;
  final double accuracy;
  final int durationSeconds;
  final String timestamp;

  const TestResult({
    required this.table,
    required this.score,
    required this.totalQ,
    required this.accuracy,
    required this.durationSeconds,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'table': table,
        'score': score,
        'totalQ': totalQ,
        'accuracy': accuracy,
        'durationSeconds': durationSeconds,
        'timestamp': timestamp,
      };

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
        table: (json['table'] as num).toInt(),
        score: (json['score'] as num).toInt(),
        totalQ: (json['totalQ'] as num).toInt(),
        accuracy: (json['accuracy'] as num).toDouble(),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        timestamp: json['timestamp'] as String,
      );
}

class _Fact {
  final int a;
  final int b;
  int get product => a * b;
  const _Fact(this.a, this.b);
}

class _Answer {
  final _Fact fact;
  final int? userAnswer;
  bool get isCorrect => userAnswer == fact.product;
  const _Answer({required this.fact, required this.userAnswer});
}

List<_Fact> _generateTestFacts(int table) {
  final rng = Random();
  final List<_Fact> pool;
  if (table == 0) {
    pool = [
      for (int a = 1; a <= 12; a++)
        for (int b = 1; b <= 12; b++) _Fact(a, b),
    ];
  } else {
    pool = [for (int b = 1; b <= 12; b++) _Fact(table, b)];
    // If table has only 12 facts, repeat to reach 20 but avoid exact duplicates
    // by also including reversed or nearby tables. Simplest: sample with replacement.
  }
  pool.shuffle(rng);
  // Ensure exactly 20 — repeat pool if smaller
  final result = <_Fact>[];
  int idx = 0;
  while (result.length < 20) {
    result.add(pool[idx % pool.length]);
    idx++;
  }
  return result;
}

/// TestScreen — 20-question timed test.
/// SPEC §5 | SPEC §6 Task 6
class TestScreen extends ConsumerStatefulWidget {
  final int table; // 1-12 or 0 for mixed

  const TestScreen({super.key, required this.table});

  @override
  ConsumerState<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends ConsumerState<TestScreen> {
  static const int _totalQuestions = 20;
  static const int _testDuration = 120; // seconds

  late final List<_Fact> _facts;
  final List<_Answer> _answers = [];
  int _currentIndex = 0;
  String _input = '';
  bool _sessionRecorded = false;
  bool _isComplete = false;

  int _secondsLeft = _testDuration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _facts = _generateTestFacts(widget.table);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _finishTest();
      }
    });

    // Record streak on entering test
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sessionRecorded) {
        _sessionRecorded = true;
        ref.read(streakProvider.notifier).recordSessionToday();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_isComplete) return;
    if (_input.length >= 3) return;
    setState(() => _input += d);
  }

  void _onBackspace() {
    if (_isComplete) return;
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _onSubmit() {
    if (_isComplete) return;
    final userAnswer = int.tryParse(_input);
    _answers.add(_Answer(fact: _facts[_currentIndex], userAnswer: userAnswer));

    if (_currentIndex >= _totalQuestions - 1) {
      _finishTest();
      return;
    }
    setState(() {
      _currentIndex++;
      _input = '';
    });
  }

  void _finishTest() {
    _timer?.cancel();
    final durationSeconds = _testDuration - _secondsLeft;

    // Record mastery for each answered question
    for (final ans in _answers) {
      ref.read(masteryProvider.notifier).recordAnswer(
            table: widget.table,
            wasCorrect: ans.isCorrect,
          );
    }

    // Build TestResult
    final score = _answers.where((a) => a.isCorrect).length;
    final total = _answers.length;
    final accuracy = total == 0 ? 0.0 : score / total;
    final result = TestResult(
      table: widget.table,
      score: score,
      totalQ: total,
      accuracy: accuracy,
      durationSeconds: durationSeconds,
      timestamp: DateTime.now().toIso8601String(),
    );

    // Persist to SharedPreferences (FIFO max 50)
    _saveResult(result);

    setState(() => _isComplete = true);
  }

  Future<void> _saveResult(TestResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(TimesTablesPrefsKeys.historyJson);
    final List<dynamic> list =
        existing != null ? jsonDecode(existing) as List<dynamic> : [];
    list.add(result.toJson());
    // FIFO: keep last 50
    final trimmed = list.length > 50 ? list.sublist(list.length - 50) : list;
    await prefs.setString(
        TimesTablesPrefsKeys.historyJson, jsonEncode(trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.table == 0 ? 'Mixed' : '${widget.table}×';
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('$label Test'),
        leading: _isComplete
            ? null
            : BackButton(
                onPressed: () {
                  _timer?.cancel();
                  Navigator.of(context).pop();
                },
              ),
      ),
      body: _isComplete ? _buildResults(context) : _buildTest(context),
    );
  }

  Widget _buildTest(BuildContext context) {
    final fact = _facts[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(kPagePadding),
      child: Column(
        children: [
          // Top bar: question counter + timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Q${_currentIndex + 1} / $_totalQuestions',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kInkSoft,
                ),
              ),
              _TimerChip(secondsLeft: _secondsLeft),
            ],
          ),
          const SizedBox(height: 24),

          // Equation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(kCardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '${fact.a} × ${fact.b} = ?',
                  style: const TextStyle(
                    fontSize: kEquationFontSize,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: 120,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: kHairline, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _input.isEmpty ? '___' : _input,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: kInk,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          NumberPad(
            onDigit: _onDigit,
            onBackspace: _onBackspace,
            onSubmit: _onSubmit,
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final score = _answers.where((a) => a.isCorrect).length;
    final total = _answers.length;
    final pct = total == 0 ? 0 : ((score / total) * 100).round();
    final durationSeconds = _testDuration - _secondsLeft;
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    final timeStr = mins > 0
        ? '${mins}m ${secs.toString().padLeft(2, '0')}s'
        : '${secs}s';

    return Padding(
      padding: const EdgeInsets.all(kPagePadding),
      child: Column(
        children: [
          // Score summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(kCardRadius),
            ),
            child: Column(
              children: [
                Text(
                  '$score / $_totalQuestions',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: kPrimary,
                  ),
                ),
                Text(
                  '$pct% accuracy',
                  style: const TextStyle(fontSize: 18, color: kInkSoft),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, size: 16, color: kInkSoft),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(color: kInkSoft),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Per-question review
          Expanded(
            child: ListView.builder(
              itemCount: _answers.length,
              itemBuilder: (context, i) {
                final ans = _answers[i];
                final color = ans.isCorrect ? kAccentGreen : kAccentRed;
                final icon = ans.isCorrect ? Icons.check : Icons.close;
                return ListTile(
                  dense: true,
                  leading: Icon(icon, color: color, size: 20),
                  title: Text(
                    '${ans.fact.a} × ${ans.fact.b} = ${ans.fact.product}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: ans.isCorrect
                      ? null
                      : Text(
                          'You: ${ans.userAnswer ?? '–'}',
                          style: const TextStyle(
                              color: kAccentRed, fontSize: 13),
                        ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Buttons
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Test again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(kMinTapTarget + 4),
            ),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => TestScreen(table: widget.table),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.home),
            label: const Text('Back to tables'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(kMinTapTarget + 4),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer chip
// ---------------------------------------------------------------------------

class _TimerChip extends StatelessWidget {
  final int secondsLeft;
  const _TimerChip({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsLeft <= 10;
    final mins = secondsLeft ~/ 60;
    final secs = secondsLeft % 60;
    final text = '${mins.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? kAccentRed : kPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
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
