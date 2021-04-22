import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dashclicker/logic/dash_counter.dart';
import 'package:dashclicker/logic/firebase_notifier.dart';
import 'package:dashclicker/model/purchasable_product.dart';
import 'package:dashclicker/model/store_state.dart';

const storeKeyConsumable = 'consumable';
const storeKeySubscription = 'subscription_silver1';

class DashPurchases extends ChangeNotifier {
  DashCounter counter;
  StoreState storeState = StoreState.available;
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

  DashPurchases(this.counter);

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
}