import 'package:flutter/widgets.dart';
import 'auth_service.dart';
import 'product_service.dart';
import 'transaction_service.dart';
import 'document_service.dart';
import 'shop_service.dart';

class AppServices extends InheritedWidget {
  final AuthService auth;
  final ProductService products;
  final TransactionService transactions;
  final DocumentService documents;
  final ShopService shop;

  const AppServices({
    super.key,
    required this.auth,
    required this.products,
    required this.transactions,
    required this.documents,
    required this.shop,
    required super.child,
  });

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>()!;

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      auth != oldWidget.auth ||
      products != oldWidget.products ||
      transactions != oldWidget.transactions ||
      documents != oldWidget.documents ||
      shop != oldWidget.shop;
}
