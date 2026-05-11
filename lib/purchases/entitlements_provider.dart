import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'iap_constants.dart';
import 'iap_service.dart';

/// Immutable snapshot of what the user has purchased.
class Entitlements {
  final bool tablesUnlock;
  final bool premiumAnnual;

  const Entitlements({
    required this.tablesUnlock,
    required this.premiumAnnual,
  });

  static const empty = Entitlements(
    tablesUnlock: false,
    premiumAnnual: false,
  );

  /// Tables 7–12 + Mixed unlocked if either product is purchased.
  bool get hasTablesUnlock => tablesUnlock || premiumAnnual;

  /// Premium features (Parent Dashboard, Story Mnemonics) require annual sub.
  bool get hasPremium => premiumAnnual;

  @override
  String toString() =>
      'Entitlements(tablesUnlock: $tablesUnlock, premiumAnnual: $premiumAnnual)';
}

class EntitlementsNotifier extends Notifier<Entitlements> {
  @override
  Entitlements build() {
    _init();
    return Entitlements.empty;
  }

  Future<void> _init() async {
    await _refreshFromPrefs();
    // Wire up the IapService callback so purchases update this notifier live.
    ref.read(iapServiceProvider).onPurchaseDelivered = (_) {
      _refreshFromPrefs();
    };
  }

  Future<void> _refreshFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final tablesUnlock =
        prefs.getBool(TimesTablesPrefsKeys.iapTablesUnlock) ?? false;
    final premiumAnnual =
        prefs.getBool(TimesTablesPrefsKeys.iapPremiumAnnual) ?? false;
    state = Entitlements(
      tablesUnlock: tablesUnlock,
      premiumAnnual: premiumAnnual,
    );
  }

  /// Called explicitly after purchase/restore to synchronise state.
  Future<void> refresh() => _refreshFromPrefs();
}

final entitlementsProvider =
    NotifierProvider<EntitlementsNotifier, Entitlements>(
  EntitlementsNotifier.new,
);

final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService();
  ref.onDispose(service.dispose);
  return service;
});
