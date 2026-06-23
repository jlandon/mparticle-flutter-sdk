/// Pure Dart commerce helpers for web (no JS interop imports).
List<Object?> buildProductCreateArgs(Map<dynamic, dynamic> rawProduct) {
  return [
    rawProduct['name'],
    rawProduct['sku'],
    rawProduct['price'],
    rawProduct['quantity'],
    rawProduct['variant'],
    rawProduct['category'],
    rawProduct['brand'],
    rawProduct['position'],
    rawProduct['couponCode'],
    rawProduct['attributes'],
  ];
}
