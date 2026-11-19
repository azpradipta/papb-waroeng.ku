import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'data.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_exception.dart';
import 'services/app_services.dart';
import 'services/auth_service.dart';
import 'services/document_service.dart';
import 'services/product_service.dart';
import 'services/transaction_service.dart';
import 'services/shop_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SupabaseConfig.isConfigured) {
    runApp(const SupabaseSetupRequiredApp());
    return;
  }
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    final client = Supabase.instance.client;
    runApp(
      MyApp(
        auth: SupabaseAuthService(client),
        products: SupabaseProductService(client),
        transactions: SupabaseTransactionService(client),
        documents: PdfDocumentService(),
        shop: SupabaseShopService(client),
      ),
    );
  } catch (_) {
    runApp(const SupabaseSetupRequiredApp(initializationFailed: true));
  }
}

class MyApp extends StatelessWidget {
  final AuthService auth;
  final ProductService products;
  final TransactionService transactions;
  final DocumentService documents;
  final ShopService shop;
  const MyApp({
    super.key,
    required this.auth,
    required this.products,
    required this.transactions,
    required this.documents,
    required this.shop,
  });

  @override
  Widget build(BuildContext context) => AppServices(
    auth: auth,
    products: products,
    transactions: transactions,
    documents: documents,
    shop: shop,
    child: const _SessionApp(),
  );
}

class _SessionApp extends StatefulWidget {
  const _SessionApp();
  @override
  State<_SessionApp> createState() => _SessionAppState();
}

class _SessionAppState extends State<_SessionApp> {
  StreamSubscription<void>? _subscription;
  late Future<Profil?> _profile;
  AuthService? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AppServices.of(context).auth;
    if (_auth == auth) return;
    _subscription?.cancel();
    _auth = auth;
    _profile = auth.getProfile();
    _subscription = auth.changes.listen(
      (_) => _reload(),
      onError: (Object error) => _reload(),
    );
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _profile = _auth!.getProfile();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Profil?>(
    future: _profile,
    builder: (context, snapshot) {
      final waiting = snapshot.connectionState != ConnectionState.done;
      final profile = snapshot.data;
      // Pergantian sesi membuang seluruh halaman dan keranjang akun sebelumnya.
      return MaterialApp(
        key: ValueKey(
          waiting
              ? 'loading'
              : snapshot.hasError
              ? 'error'
              : profile?.id ?? 'login',
        ),
        title: 'Waroeng.Ku',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF7A29),
            primary: const Color(0xFFFF7A29),
          ),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: waiting
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : snapshot.hasError
            ? Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          snapshot.error is ApiException
                              ? (snapshot.error as ApiException).message
                              : 'Profil tidak dapat dimuat.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('Coba Lagi'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await _auth!.signOut();
                            } catch (_) {
                              _reload();
                            }
                          },
                          child: const Text('Kembali ke Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : profile == null
            ? const LoginScreen()
            : MainScreen(profile: profile),
      );
    },
  );
}

class SupabaseSetupRequiredApp extends StatelessWidget {
  final bool initializationFailed;
  const SupabaseSetupRequiredApp({
    super.key,
    this.initializationFailed = false,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 72, color: Color(0xFFFF7A29)),
              const SizedBox(height: 16),
              Text(
                initializationFailed
                    ? 'Gagal menghubungkan Supabase'
                    : 'Konfigurasi Supabase belum diisi',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY pada file .env. '
                'Jalankan flutter run --dart-define-from-file=.env. '
                'Petunjuk database dan akun tersedia di README.md.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
