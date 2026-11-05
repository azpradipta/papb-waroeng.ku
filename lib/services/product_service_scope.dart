import 'package:flutter/widgets.dart';

import 'product_service.dart';

class ProductServiceScope extends InheritedWidget {
  final ProductService service;

  const ProductServiceScope({
    super.key,
    required this.service,
    required super.child,
  });

  static ProductService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ProductServiceScope>();
    assert(scope != null, 'ProductServiceScope tidak ditemukan.');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(ProductServiceScope oldWidget) {
    return service != oldWidget.service;
  }
}
