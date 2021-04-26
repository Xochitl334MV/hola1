import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dashclicker/logic/dash_counter.dart';
import 'package:dashclicker/model/purchasable_product.dart';
import 'package:dashclicker/model/store_state.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const storeKeyConsumable = 'consumable';
const storeKeySubscription = 'subscription_silver1';

class DashPurchases extends ChangeNotifier {
  DashCounter counter;
  StoreState storeState = StoreState.notAvailable;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<PurchasableProduct> products = [
    PurchasableProduct(
      'Spring is in the air',
      'Many dashes flying out from their nests',
      '\$0.99',
    ),
    PurchasableProduct(
      'Jet engine',
      'Doubles you clicks per second for a day',
      '\$1.99',
    ),
  ];

  DashPurchases(this.counter){
    final purchaseUpdated =
        InAppPurchaseConnection.instance.purchaseUpdatedStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: _updateStreamOnDone,
      onError: _updateStreamOnError,
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> buy(PurchasableProduct product) async {
    product.status = ProductStatus.pending;
    notifyListeners();
    await Future.delayed(Duration(seconds: 5));
    product.status = ProductStatus.purchased;
    notifyListeners();
    await Future.delayed(Duration(seconds: 5));
    product.status = ProductStatus.purchasable;
    notifyListeners();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    // Handle purchases here
  }

  void _updateStreamOnDone() {
    _subscription.cancel();
  }

  void _updateStreamOnError(dynamic error) {
    //Handle error here
  }
}