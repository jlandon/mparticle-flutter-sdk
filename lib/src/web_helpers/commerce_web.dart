import 'dart:js_interop';

import 'package:mparticle_flutter_sdk/src/web_helpers/commerce_helpers.dart';
import 'package:mparticle_flutter_sdk/src/web_helpers/js_bridge.dart';

JSObject createJSProduct({
  required MParticleJsBridge bridge,
  required JSObject commerce,
  required Map<dynamic, dynamic> rawProduct,
}) {
  final args = buildProductCreateArgs(rawProduct).map((value) {
    if (value == null) {
      return null;
    }
    if (value is Map || value is List) {
      return bridge.jsifyValue(value);
    }
    return bridge.jsifyValue(value);
  }).toList();

  return bridge.callMethodVarArgs(
    commerce,
    'createProduct',
    args.cast<JSAny?>(),
  )! as JSObject;
}

bool? logCommerceEvent({
  required MParticleJsBridge bridge,
  required JSObject commerce,
  required Map<dynamic, dynamic> commerceEvent,
}) {
  var customAttributes =
      commerceEvent['customAttributes'] as Map<dynamic, dynamic>? ?? {};
  var customFlags =
      commerceEvent['customFlags'] as Map<dynamic, dynamic>? ?? {};
  var transactionAttributes =
      commerceEvent['transactionAttributes'] as Map<dynamic, dynamic>? ?? {};

  final checkoutStep = commerceEvent['checkoutStep'] as String?;
  if (checkoutStep != null) {
    transactionAttributes = Map<dynamic, dynamic>.from(transactionAttributes)
      ..['Step'] = checkoutStep;
  }

  final checkoutOptions = commerceEvent['checkoutOptions'] as String?;
  if (checkoutOptions != null) {
    transactionAttributes = Map<dynamic, dynamic>.from(transactionAttributes)
      ..['Option'] = checkoutOptions;
  }

  final currency = commerceEvent['currency'] as String?;
  if (currency != null) {
    bridge.callMethodVarArgs(commerce, 'setCurrencyCode', [
      bridge.jsifyValue(currency),
    ]);
  }

  final eventOptions = <String, dynamic>{};
  final shouldUploadEvent = commerceEvent['shouldUploadEvent'] as bool?;
  if (shouldUploadEvent != null) {
    eventOptions['shouldUploadEvent'] = shouldUploadEvent;
  }

  final rawProducts = commerceEvent['products'] as List<dynamic>?;
  final products = <JSObject>[];
  if (rawProducts != null && rawProducts.isNotEmpty) {
    for (final rawProduct in rawProducts) {
      products.add(
        createJSProduct(
          bridge: bridge,
          commerce: commerce,
          rawProduct: rawProduct as Map<dynamic, dynamic>,
        ),
      );
    }
  }

  final productActionType = commerceEvent['jsProductActionType'] as int?;
  final promotionActionType = commerceEvent['jsPromotionActionType'] as int?;

  if (productActionType != null) {
    bridge.callMethodVarArgs(commerce, 'logProductAction', [
      bridge.jsifyValue(productActionType),
      _jsObjectList(products),
      bridge.jsifyValue(customAttributes),
      bridge.jsifyValue(customFlags),
      bridge.jsifyValue(transactionAttributes),
      bridge.jsifyValue(eventOptions),
    ]);
    return true;
  }

  if (promotionActionType != null) {
    final rawPromotions = commerceEvent['promotions'] as List<dynamic>?;
    final promotions = <JSObject>[];
    if (rawPromotions != null && rawPromotions.isNotEmpty) {
      for (final rawPromotion in rawPromotions) {
        final promotion = rawPromotion as Map<dynamic, dynamic>;
        promotions.add(
          bridge.callMethodVarArgs(commerce, 'createPromotion', [
            bridge.jsifyValue(promotion['promotionId']),
            bridge.jsifyValue(promotion['creative']),
            bridge.jsifyValue(promotion['name']),
            bridge.jsifyValue(promotion['position']),
          ])! as JSObject,
        );
      }
    }

    bridge.callMethodVarArgs(commerce, 'logPromotion', [
      bridge.jsifyValue(promotionActionType),
      _jsObjectList(promotions),
      bridge.jsifyValue(customAttributes),
      bridge.jsifyValue(customFlags),
      bridge.jsifyValue(eventOptions),
    ]);
    return true;
  }

  final rawImpressions = commerceEvent['impressions'] as List<dynamic>?;
  final impressions = <JSObject>[];
  if (rawImpressions != null && rawImpressions.isNotEmpty) {
    for (final rawImpression in rawImpressions) {
      final impression = rawImpression as Map<dynamic, dynamic>;
      final impressionProducts = <JSObject>[];
      final rawImpressionProducts = impression['products'] as List<dynamic>?;
      if (rawImpressionProducts != null && rawImpressionProducts.isNotEmpty) {
        for (final rawImpressionProduct in rawImpressionProducts) {
          impressionProducts.add(
            createJSProduct(
              bridge: bridge,
              commerce: commerce,
              rawProduct: rawImpressionProduct as Map<dynamic, dynamic>,
            ),
          );
        }
      }

      impressions.add(
        bridge.callMethodVarArgs(commerce, 'createImpression', [
          bridge.jsifyValue(impression['impressionListName']),
          _jsObjectList(impressionProducts),
        ])! as JSObject,
      );
    }
  }

  bridge.callMethodVarArgs(commerce, 'logImpression', [
    _jsObjectList(impressions),
    bridge.jsifyValue(customAttributes),
    bridge.jsifyValue(customFlags),
    bridge.jsifyValue(eventOptions),
  ]);
  return null;
}

JSAny? _jsObjectList(List<JSObject> objects) {
  return objects.map((object) => object as JSAny?).toList().jsify();
}
