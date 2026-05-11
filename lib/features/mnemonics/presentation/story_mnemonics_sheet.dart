import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';
import '../../paywall/presentation/paywall_sheet.dart';

/// The 40 curated story mnemonics for hard multiplication facts.
/// Key: 'AxB' (A <= B, both 6–9 and select others). Value: mnemonic sentence.
const Map<String, String> kMnemonics = {
  '6x6': 'Six six — dirty tricks, thirty-six sticks!',
  '6x7': 'Six seven — ate (8) at seven-eleven and had forty-two!',
  '6x8': 'Six ate (8) forty-eight sandwiches at the diner.',
  '6x9': 'Six and nine dined together — fifty-four was on the menu.',
  '7x7': 'Seven heavens times seven heavens — forty-nine steps to paradise.',
  '7x8': 'Seven ate (8) fifty-six hotdogs at the state fair.',
  '7x9': 'Seven and nine went on a date — sixty-three was their table number.',
  '8x8': 'Eight eight — I ate and ate until I had sixty-four!',
  '8x9': 'Eight and nine baked together — seventy-two cookies came out.',
  '9x9': 'Nine nuns ran — eighty-one steps to the chapel.',
  '4x8': 'Four octopuses (8 arms each) — thirty-two arms total!',
  '3x7': 'Three lucky sevens — twenty-one is a winner!',
  '4x7': 'Four weeks of seven days — twenty-eight days in February.',
  '6x4': 'Six fours are two dozen — twenty-four hours in a day.',
  '3x8': 'Three stop signs (eight sides each) — twenty-four sides!',
  '4x9': 'Four cats with nine lives — thirty-six lives between them.',
  '5x7': 'Five weeks of seven days — thirty-five days until the holidays.',
  '5x8': 'Five spiders with eight legs — forty legs scurrying!',
  '5x9': 'Five baseball teams with nine players — forty-five players total.',
  '3x9': 'Three cats with nine lives — twenty-seven lives.',
  '2x9': 'Two hands with nine fingers (one broken) — eighteen fingers.',
  '4x6': 'Four bugs with six legs — twenty-four legs crawling.',
  '7x6': 'Same as 6x7 — six seven, forty-two!',
  '8x6': 'Same as 6x8 — six ate forty-eight.',
  '9x6': 'Same as 6x9 — fifty-four on the menu.',
  '8x7': 'Same as 7x8 — seven ate fifty-six.',
  '9x7': 'Same as 7x9 — sixty-three was their number.',
  '9x8': 'Same as 8x9 — seventy-two cookies.',
  '12x11': 'Twelve times eleven — one hundred and thirty-two steps up the stairs.',
  '11x11': 'Eleven times eleven — one hundred and twenty-one spotted dogs!',
  '12x12': 'Twelve times twelve — a gross! One hundred and forty-four.',
  '11x12': 'Same as 12x11 — one hundred and thirty-two.',
  '9x11': 'Nine times eleven — ninety-nine bottles of orange juice.',
  '8x11': 'Eight times eleven — eighty-eight piano keys.',
  '7x11': 'Seven times eleven — seventy-seven trombones.',
  '6x11': 'Six times eleven — sixty-six, Route sixty-six!',
  '12x9': 'Twelve months times nine — one hundred and eight.',
  '12x8': 'Twelve times eight — ninety-six dreams a year.',
  '12x7': 'Twelve months times seven — eighty-four.',
  '12x6': 'Twelve times six — seventy-two, same as a dozen eggs times six.',
};

/// Bottom sheet showing the story mnemonic for a specific multiplication fact.
/// Premium gate: if !hasPremium, opens PaywallSheet.
///
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     builder: (_) => StoryMnemonicsSheet(a: 7, b: 8),
///   );
///
/// SPEC §5 — StoryMnemonicsSheet | SPEC §6 Task 10
class StoryMnemonicsSheet extends ConsumerWidget {
  final int a;
  final int b;

  const StoryMnemonicsSheet({super.key, required this.a, required this.b});

  /// Returns true if a mnemonic exists for this fact.
  static bool hasMnemonic(int a, int b) {
    final key1 = '${a}x$b';
    final key2 = '${b}x$a';
    return kMnemonics.containsKey(key1) || kMnemonics.containsKey(key2);
  }

  String? _getMnemonic() {
    final key1 = '${a}x$b';
    final key2 = '${b}x$a';
    return kMnemonics[key1] ?? kMnemonics[key2];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref.watch(entitlementsProvider);
    final mnemonic = _getMnemonic();

    if (!entitlements.hasPremium) {
      // Close this and open PaywallSheet instead
      final container = ProviderScope.containerOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.of(context).pop();
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => UncontrolledProviderScope(
            container: container,
            child: const PaywallSheet(highlightPremium: true),
          ),
        );
      });

      return Container(
        padding: const EdgeInsets.all(kPagePadding),
        child: const Text(
          'Premium required...',
          style: TextStyle(color: kInkSoft),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      padding: const EdgeInsets.fromLTRB(
          kPagePadding, kPagePadding, kPagePadding, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fact header
          Row(
            children: [
              const Icon(Icons.lightbulb, color: kAccentAmber, size: 28),
              const SizedBox(width: 10),
              Text(
                '$a × $b = ${a * b}',
                style: const TextStyle(
                  fontSize: kEquationFontSize * 0.55,
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Memory Trick',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: kInkSoft,
            ),
          ),
          const SizedBox(height: 8),

          if (mnemonic != null)
            Text(
              mnemonic,
              style: const TextStyle(
                fontSize: kBodyFontSize + 2,
                color: kInk,
                height: 1.5,
              ),
            )
          else
            const Text(
              'No story for this fact yet — try the flash drill!',
              style: TextStyle(color: kInkSoft),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
