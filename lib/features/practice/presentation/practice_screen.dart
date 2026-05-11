import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';
import '../../../widgets/number_pad.dart';
import '../../mnemonics/presentation/story_mnemonics_sheet.dart';
import '../../paywall/presentation/paywall_sheet.dart';

class _Fact {
  final int a;
  final int b;
  int get product => a * b;
  const _Fact(this.a, this.b);
}

List<_Fact> _buildFacts(int table) {
  if (table == 0) {
    final all = [
      for (int a = 1; a <= 12; a++)
        for (int b = 1; b <= 12; b++) _Fact(a, b),
    ];
    all.shuffle(Random());
    return all;
  }
  final facts = [for (int b = 1; b <= 12; b++) _Fact(table, b)];
  facts.shuffle(Random());
  return facts;
}

/// PracticeScreen — typed-answer drill for a single table or mixed.
/// SPEC §5 | SPEC §6 Task 5
class PracticeScreen extends ConsumerStatefulWidget {
  final int table; // 1-12, or 0 for mixed

  const PracticeScreen({super.key, required this.table});

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late List<_Fact> _facts;
  int _currentIndex = 0;
  String _input = '';
  bool _submitted = false;
  bool _wasCorrect = false;
  bool _sessionRecorded = false;

  // Timer
  Timer? _countdownTimer;
  int _secondsLeft = 10;

  @override
  void initState() {
    super.initState();
    _facts = _buildFacts(widget.table);
    _startTimerIfNeeded();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    _countdownTimer?.cancel();
    final settings = ref.read(settingsProvider);
    if (!settings.timerEnabled) return;

    _secondsLeft = settings.voiceSpeed < 0.4
        ? 20
        : settings.voiceSpeed < 0.7
            ? 10
            : 5;
    // Actually: timer duration from settings. For now use a fixed 10s default.
    // The SPEC says configurable 5/10/20s. We derive from a simple lookup:
    _secondsLeft = _timerDuration(settings);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _countdownTimer?.cancel();
        if (!_submitted) _submit();
      }
    });
  }

  int _timerDuration(AppSettings settings) {
    // Maps voiceSpeed proxy to timer seconds.
    // SPEC says 5/10/20s configurable. SettingsScreen uses voiceSpeed slider.
    // For timer duration we'll default to 10s (the mid setting).
    // A future SettingsScreen addition can expose a separate timer picker.
    return 10;
  }

  _Fact get _currentFact => _facts[_currentIndex];

  void _onDigit(String d) {
    if (_submitted) return;
    if (_input.length >= 3) return; // max 3 digits (144 is largest answer)
    setState(() => _input += d);
  }

  void _onBackspace() {
    if (_submitted) return;
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    if (_submitted) return;
    _countdownTimer?.cancel();

    if (!_sessionRecorded) {
      _sessionRecorded = true;
      ref.read(streakProvider.notifier).recordSessionToday();
    }

    final answer = int.tryParse(_input);
    final correct = answer == _currentFact.product;
    setState(() {
      _submitted = true;
      _wasCorrect = correct;
    });

    ref.read(masteryProvider.notifier).recordAnswer(
          table: widget.table,
          wasCorrect: correct,
        );

    // Speak on submit for practice (regardless of flip)
    final settings = ref.read(settingsProvider);
    final tts = ref.read(ttsProvider);
    final fact = _currentFact;
    speakEquation(
      '${fact.a} times ${fact.b} equals ${fact.product}',
      ttsEnabled: settings.ttsEnabled,
      tts: tts,
      voiceSpeed: settings.voiceSpeed,
    );

    if (correct) {
      Future.delayed(const Duration(milliseconds: 1500), _advance);
    }
    // On wrong: user must tap to continue (shown via _submitted + !_wasCorrect UI)
  }

  void _advance() {
    if (!mounted) return;
    _countdownTimer?.cancel();
    if (_currentIndex >= _facts.length - 1) {
      // Wrap around — generate fresh shuffled set
      setState(() {
        _facts = _buildFacts(widget.table);
        _currentIndex = 0;
        _input = '';
        _submitted = false;
        _wasCorrect = false;
      });
    } else {
      setState(() {
        _currentIndex++;
        _input = '';
        _submitted = false;
        _wasCorrect = false;
      });
    }
    _startTimerIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final fact = _currentFact;
    final label = widget.table == 0 ? 'Mixed' : '${widget.table}×';

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('$label Practice'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
            kPagePadding, 8, kPagePadding, kPagePadding),
        child: Column(
          children: [
            // Timer bar
            if (settings.timerEnabled && !_submitted)
              _TimerBar(secondsLeft: _secondsLeft, totalSeconds: 10),
            const SizedBox(height: 16),

            // Equation display
            _EquationCard(
              fact: fact,
              input: _input,
              submitted: _submitted,
              wasCorrect: _wasCorrect,
            ),

            const SizedBox(height: 16),

            // Memory trick button
            if (_submitted && StoryMnemonicsSheet.hasMnemonic(fact.a, fact.b))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Memory trick'),
                  onPressed: () => _openMnemonic(context, fact),
                ),
              ),

            // Wrong answer: tap to continue
            if (_submitted && !_wasCorrect)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(kMinTapTarget),
                  ),
                  onPressed: _advance,
                  child: const Text('Continue'),
                ),
              ),

            const Spacer(),

            // Number pad — always visible, disabled after submit
            NumberPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  void _openMnemonic(BuildContext context, _Fact fact) {
    final entitlements = ref.read(entitlementsProvider);
    final container = ProviderScope.containerOf(context);
    if (!entitlements.hasPremium) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => UncontrolledProviderScope(
          container: container,
          child: const PaywallSheet(highlightPremium: true),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: StoryMnemonicsSheet(a: fact.a, b: fact.b),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Equation card with feedback overlay
// ---------------------------------------------------------------------------

class _EquationCard extends StatelessWidget {
  final _Fact fact;
  final String input;
  final bool submitted;
  final bool wasCorrect;

  const _EquationCard({
    required this.fact,
    required this.input,
    required this.submitted,
    required this.wasCorrect,
  });

  @override
  Widget build(BuildContext context) {
    Color overlayColor = kCard;
    if (submitted) {
      overlayColor = wasCorrect
          ? kAccentGreen.withAlpha(30)
          : kAccentRed.withAlpha(30);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: overlayColor,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Equation
          Text(
            '${fact.a} × ${fact.b} = ',
            style: const TextStyle(
              fontSize: kEquationFontSize,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),

          // Input display
          Container(
            width: 140,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: submitted ? Colors.transparent : Colors.white,
              border: submitted
                  ? null
                  : Border.all(color: kHairline, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              input.isEmpty && !submitted ? '___' : input,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: submitted
                    ? (wasCorrect ? kAccentGreen : kAccentRed)
                    : kInk,
              ),
            ),
          ),

          // Feedback
          if (submitted) ...[
            const SizedBox(height: 12),
            if (wasCorrect)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: kAccentGreen, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Correct!',
                    style: TextStyle(
                      color: kAccentGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel, color: kAccentRed, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Not quite!',
                        style: TextStyle(
                          color: kAccentRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Answer: ${fact.product}',
                    style: const TextStyle(
                      color: kInkSoft,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timer bar
// ---------------------------------------------------------------------------

class _TimerBar extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;

  const _TimerBar({required this.secondsLeft, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final fraction =
        totalSeconds == 0 ? 0.0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final color = secondsLeft <= 3 ? kAccentRed : kPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$secondsLeft s',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: fraction,
          backgroundColor: kHairline,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
