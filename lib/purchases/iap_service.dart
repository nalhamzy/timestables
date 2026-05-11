import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'iap_constants.dart';

typedef PurchaseDeliveryCallback = void Function(PurchaseDetails details);

/// Wraps in_app_purchase for Times Tables Trainer.
/// No RevenueCat — see SPEC §3.
/// Ported from Sight Words IapService; product IDs renamed.
class IapService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  PurchaseDeliveryCallback? onPurchaseDelivered;
  List<ProductDetails> _products = [];

  List<ProductDetails> get products => List.unmodifiable(_products);

  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('IapService: Store not available on this device.');
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object e) {
        debugPrint('IapService: purchaseStream error: $e');
      },
    );

    await queryProducts();
    // Silently restore on launch to refresh cached entitlement state.
    await restorePurchases();
  }

  Future<List<ProductDetails>> queryProducts() async {
    final response =
        await _iap.queryProductDetails(TimesTablesProductIds.all);
    if (response.error != null) {
      debugPrint('IapService: queryProducts error: ${response.error}');
    }
    _products = response.productDetails;
    return _products;
  }

  /// Buy the non-consumable tables_unlock product.
  Future<void> buyTablesUnlock(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Buy the auto-renewable premium_annual subscription.
  Future<void> buyPremiumAnnual(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    // Subscriptions use buyNonConsumable on in_app_purchase 3.x.
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> updates) {
    for (final details in updates) {
      if (details.status == PurchaseStatus.purchased ||
          details.status == PurchaseStatus.restored) {
        _deliverPurchase(details);
      } else if (details.status == PurchaseStatus.error) {
        debugPrint(
          'IapService: purchase error for ${details.productID}: '
          '${details.error?.message}',
        );
      }
      if (details.pendingCompletePurchase) {
        _iap.completePurchase(details);
      }
    }
  }

  Future<void> _deliverPurchase(PurchaseDetails details) async {
    final prefs = await SharedPreferences.getInstance();
    if (details.productID == TimesTablesProductIds.tablesUnlock) {
      await prefs.setBool(TimesTablesPrefsKeys.iapTablesUnlock, true);
    } else if (details.productID == TimesTablesProductIds.premiumAnnual) {
      await prefs.setBool(TimesTablesPrefsKeys.iapPremiumAnnual, true);
    }
    onPurchaseDelivered?.call(details);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
