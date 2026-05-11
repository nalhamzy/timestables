import 'package:flutter/material.dart';
import '../core/constants/tokens.dart';

/// Reusable custom number pad for PracticeScreen and TestScreen.
/// No system keyboard — avoids autocorrect / emoji on kids' input.
///
/// Callbacks:
///   [onDigit]     — called with digit character '0'–'9' when a digit key tapped.
///   [onBackspace] — called when backspace key tapped.
///   [onSubmit]    — called when submit (✓) key tapped.
class NumberPad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  const NumberPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(['7', '8', '9']),
        const SizedBox(height: 8),
        _row(['4', '5', '6']),
        const SizedBox(height: 8),
        _row(['1', '2', '3']),
        const SizedBox(height: 8),
        Row(
          children: [
            _PadKey(
              label: '⌫',
              color: kAccentRed.withAlpha(220),
              onTap: onBackspace,
            ),
            const SizedBox(width: 8),
            _PadKey(label: '0', onTap: () => onDigit('0')),
            const SizedBox(width: 8),
            _PadKey(
              label: '✓',
              color: kAccentGreen,
              onTap: onSubmit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(List<String> digits) {
    return Row(
      children: digits
          .expand((d) => [
                _PadKey(label: d, onTap: () => onDigit(d)),
                if (d != digits.last) const SizedBox(width: 8),
              ])
          .toList(),
    );
  }
}

class _PadKey extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _PadKey({
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? kPrimary;
    return Expanded(
      child: SizedBox(
        height: kNumPadKeyHeight,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
