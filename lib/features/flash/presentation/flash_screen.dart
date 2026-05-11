import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';
import '../../mnemonics/presentation/story_mnemonics_sheet.dart';
import '../../paywall/presentation/paywall_sheet.dart';

/// A single multiplication fact.
class _Fact {
  final int a;
  final int b;
  int get product => a * b;

  const _Fact(this.a, this.b);
}

List<_Fact> _buildFacts(int table) {
  final List<_Fact> facts;
  if (table == 0) {
    facts = [
      for (int a = 1; a <= 12; a++)
        for (int b = 1; b <= 12; b++) _Fact(a, b),
    ];
  } else {
    facts = [for (int b = 1; b <= 12; b++) _Fact(table, b)];
  }
  facts.shuffle(Random());
  return facts;
}

/// FlashScreen — card-flip drill mode for a single table.
/// SPEC §5 | SPEC §6 Task 4
class FlashScreen extends ConsumerStatefulWidget {
  final int table; // 1-12; 0 = mixed

  const FlashScreen({super.key, required this.table});

  @override
  ConsumerState<FlashScreen> createState() => _FlashScreenState();
}

class _FlashScreenState extends ConsumerState<FlashScreen>
    with TickerProviderStateMixin {
  late List<_Fact> _facts;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isComplete = false;
  int _correctCount = 0;
  bool _sessionRecorded = false;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _facts = _buildFacts(widget.table);

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  void _flip() {
    if (_isFlipped) return;
    setState(() => _isFlipped = true);
    _flipController.forward();

    final settings = ref.read(settingsProvider);
    final tts = ref.read(ttsProvider);
    final fact = _facts[_currentIndex];
    speakEquation(
      '${fact.a} times ${fact.b} equals ${fact.product}',
      ttsEnabled: settings.ttsEnabled,
      tts: tts,
      voiceSpeed: settings.voiceSpeed,
    );

    if (!_sessionRecorded) {
      _sessionRecorded = true;
      ref.read(streakProvider.notifier).recordSessionToday();
    }
  }

  Future<void> _answer(bool correct) async {
    if (!_isFlipped) return;
    await ref.read(masteryProvider.notifier).recordAnswer(
          table: widget.table,
          wasCorrect: correct,
        );

    if (correct) _correctCount++;

    if (_currentIndex >= _facts.length - 1) {
      setState(() => _isComplete = true);
    } else {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
      _flipController.reset();
    }
  }

  void _restart() {
    _facts = _buildFacts(widget.table);
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
      _isComplete = false;
      _correctCount = 0;
    });
    _flipController.reset();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.table == 0 ? 'Mixed' : '${widget.table}×';
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text('$label Flash Cards'),
        leading: const BackButton(),
      ),
      body: _isComplete
          ? _buildCompletionView(context)
          : _buildDrillView(context),
    );
  }

  Widget _buildDrillView(BuildContext context) {
    final fact = _facts[_currentIndex];
    final total = _facts.length;

    return Padding(
      padding: const EdgeInsets.all(kPagePadding),
      child: Column(
        children: [
          _ProgressBar(current: _currentIndex + 1, total: total),
          const SizedBox(height: 24),

          // Flip card — tappable
          Expanded(
            child: GestureDetector(
              onTap: _flip,
              onHorizontalDragEnd: (details) {
                if (!_isFlipped) return;
                final v = details.primaryVelocity ?? 0;
                if (v > 200) {
                  _answer(true);
                } else if (v < -200) {
                  _answer(false);
                }
              },
              child: _FlipCard(
                animation: _flipAnimation,
                front: _buildFront(fact),
                back: _buildBack(fact),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Memory trick button — only on qualifying facts after flip
          if (_isFlipped && StoryMnemonicsSheet.hasMnemonic(fact.a, fact.b))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Memory trick'),
                onPressed: () => _openMnemonic(context, fact),
              ),
            ),

          // Got it / Not yet buttons — shown after flip
          if (_isFlipped)
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Not yet',
                    color: kAccentRed,
                    icon: Icons.close,
                    onTap: () => _answer(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Got it!',
                    color: kAccentGreen,
                    icon: Icons.check,
                    onTap: () => _answer(true),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kHairline,
                borderRadius: BorderRadius.circular(kCardRadius),
              ),
              child: const Text(
                'Tap the card to reveal the answer',
                textAlign: TextAlign.center,
                style: TextStyle(color: kInkSoft),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFront(_Fact fact) {
    return Center(
      child: Text(
        '${fact.a} × ${fact.b} = ?',
        style: const TextStyle(
          fontSize: kEquationFontSize,
          fontWeight: FontWeight.bold,
          color: kInk,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBack(_Fact fact) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${fact.product}',
          style: const TextStyle(
            fontSize: kAnswerFontSize,
            fontWeight: FontWeight.bold,
            color: kPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${fact.a} × ${fact.b} = ${fact.product}',
          style: const TextStyle(
            fontSize: kBodyFontSize + 4,
            color: kInkSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionView(BuildContext context) {
    final total = _facts.length;
    final pct = total == 0 ? 0 : ((_correctCount / total) * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kPagePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars, color: kAccentAmber, size: 72),
            const SizedBox(height: 16),
            Text(
              '$_correctCount / $total',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: kPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$pct% correct',
              style: const TextStyle(fontSize: 20, color: kInkSoft),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(kMinTapTarget + 4),
              ),
              onPressed: _restart,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Done'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(kMinTapTarget + 4),
              ),
              onPressed: () => Navigator.of(context).pop(),
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
// 3D flip card widget
// ---------------------------------------------------------------------------

class _FlipCard extends StatelessWidget {
  final Animation<double> animation;
  final Widget front;
  final Widget back;

  const _FlipCard({
    required this.animation,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        final isShowingBack = value >= 0.5;
        final angle = value * pi;

        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(isShowingBack ? angle - pi : angle);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(kCardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isShowingBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: back,
                  )
                : front,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar
// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card $current of $total',
          style: const TextStyle(color: kInkSoft, fontSize: 13),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: total == 0 ? 0 : current / total,
          backgroundColor: kHairline,
          valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action button (Got it / Not yet)
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMinTapTarget + 8,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(kCardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kCardRadius),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
