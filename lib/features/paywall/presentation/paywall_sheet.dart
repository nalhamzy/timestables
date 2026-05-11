import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tokens.dart';
import '../../../providers.dart';
import '../../../purchases/entitlements_provider.dart';
import '../../../purchases/iap_constants.dart';

/// PaywallSheet — bottom sheet for both paywall trigger points.
///
/// Trigger contexts (SPEC §7):
///   - User taps locked table card → [primaryFocus = tablesUnlock]
///   - User taps Parent Dashboard / Story → [primaryFocus = premiumAnnual]
///
/// Shows two offers:
///   1. "Unlock Tables 7-12 — $2.99" (non-consumable)
///   2. "Go Premium — $4.99/yr" (subscription, with perks list)
///      Perks: Tables 7-12 + Mixed + Parent Dashboard + Story Mnemonics
///   3. "Restore Purchases" link
///
/// Product prices fetched live from StoreKit / Play Billing via IapService.products.
/// Falls back to hardcoded strings if products unavailable.
///
/// SPEC §5 — PaywallSheet | SPEC §6 Task 8
class PaywallSheet extends ConsumerWidget {
  /// When true, the premiumAnnual offer is highlighted as primary.
  final bool highlightPremium;

  const PaywallSheet({super.key, this.highlightPremium = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iapService = ref.read(iapServiceProvider);
    final products = iapService.products;

    // Find product details (or null if store not yet loaded)
    final tablesUnlockProduct = products
        .where((p) => p.id == TimesTablesProductIds.tablesUnlock)
        .firstOrNull;
    final premiumProduct = products
        .where((p) => p.id == TimesTablesProductIds.premiumAnnual)
        .firstOrNull;

    final tablesUnlockPrice =
        tablesUnlockProduct?.price ?? r'$2.99';
    final premiumPrice = premiumProduct?.price ?? r'$4.99/yr';

    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      padding: const EdgeInsets.fromLTRB(
        kPagePadding, kPagePadding, kPagePadding, 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Unlock More Tables',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tables 1–6 are always free. Unlock 7–12 or go Premium.',
            style: TextStyle(color: kInkSoft),
          ),
          const SizedBox(height: 24),

          // Offer 1 — tablesUnlock
          _OfferButton(
            label: 'Unlock Tables 7–12',
            price: tablesUnlockPrice,
            description: 'All three modes for tables 7–12 and Mixed.',
            isPrimary: !highlightPremium,
            onTap: () {
              if (tablesUnlockProduct != null) {
                iapService.buyTablesUnlock(tablesUnlockProduct);
              }
            },
          ),
          const SizedBox(height: 12),

          // Offer 2 — premiumAnnual
          _OfferButton(
            label: 'Go Premium',
            price: premiumPrice,
            description:
                'Tables 7–12 + Parent Dashboard + Story Mnemonics. Billed annually.',
            isPrimary: highlightPremium,
            onTap: () {
              if (premiumProduct != null) {
                iapService.buyPremiumAnnual(premiumProduct);
              }
            },
          ),
          const SizedBox(height: 16),

          // Restore purchases
          TextButton(
            onPressed: () async {
              await iapService.restorePurchases();
              // Entitlements will update via purchaseStream callback.
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text(
              'Restore Purchases',
              style: TextStyle(color: kInkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferButton extends StatelessWidget {
  final String label;
  final String price;
  final String description;
  final bool isPrimary;
  final VoidCallback onTap;

  const _OfferButton({
    required this.label,
    required this.price,
    required this.description,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kCardRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary ? kPrimary : kCard,
          border: Border.all(
            color: isPrimary ? kPrimary : kHairline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? Colors.white : kInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPrimary ? Colors.white70 : kInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              price,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isPrimary ? Colors.white : kPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
