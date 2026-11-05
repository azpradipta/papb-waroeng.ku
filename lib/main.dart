import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/login_screen.dart';
import 'services/product_service.dart';
import 'services/product_service_scope.dart';

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
    );
    runApp(
      MyApp(productService: SupabaseProductService(Supabase.instance.client)),
    );
  } catch (_) {
    runApp(const SupabaseSetupRequiredApp(initializationFailed: true));
  }
}

class MyApp extends StatelessWidget {
  final ProductService productService;

  const MyApp({super.key, required this.productService});

  @override
  Widget build(BuildContext context) {
    return ProductServiceScope(
      service: productService,
      child: MaterialApp(
        title: 'Waroeng.Ku',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF7A29),
            primary: const Color(0xFFFF7A29),
          ),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}

class SupabaseSetupRequiredApp extends StatelessWidget {
  final bool initializationFailed;

  const SupabaseSetupRequiredApp({
    super.key,
    this.initializationFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 72,
                    color: Color(0xFFFF7A29),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    initializationFailed
                        ? 'Gagal menghubungkan Supabase'
                        : 'Konfigurasi Supabase belum diisi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY pada '
                    'file .env, lalu jalankan dengan '
                    '--dart-define-from-file=.env. Lihat '
                    'DOKUMENTASI_API_PRODUK.md untuk langkah lengkap.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
