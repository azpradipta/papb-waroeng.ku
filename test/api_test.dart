import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:waroeng_ku/data.dart';
import 'package:waroeng_ku/services/api_exception.dart';
import 'package:waroeng_ku/services/product_service.dart';
import 'package:waroeng_ku/services/transaction_service.dart';
import 'package:waroeng_ku/services/auth_service.dart';
import 'package:waroeng_ku/services/shop_service.dart';

Map<String, dynamic> product(int id) => {
  'id': id,
  'name': 'Produk $id',
  'cost_price': 1000,
  'selling_price': 2000,
  'stock': 10,
  'unit': 'pcs',
  'created_at': '2026-11-17T01:00:00Z',
};
Map<String, dynamic> receipt() => {
  'id': 'request-1',
  'invoice_code': 'WK-0000000001',
  'created_at': '2026-11-17T01:00:00Z',
  'cashier_name': 'Dina',
  'total_price': 4000,
  'cash_paid': 5000,
  'change_paid': 1000,
  'items': [
    {
      'product_id': 1,
      'product_name': 'Produk 1',
      'selling_price': 2000,
      'qty': 2,
      'subtotal': 4000,
    },
  ],
};

void main() {
  SupabaseClient client(Future<http.Response> Function(http.Request) handler) {
    final value = SupabaseClient(
      'https://example.supabase.co',
      'test-publishable',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    addTearDown(value.dispose);
    return value;
  }

  http.Response response(Object data) => http.Response(
    jsonEncode(data),
    200,
    headers: {'content-type': 'application/json'},
  );

  test(
    'daftar mengirim identitas toko tanpa memilih peran; profil dan password memakai sesi pengguna',
    () async {
      const id = '10000000-0000-4000-8000-000000000001';
      String jwtPart(Map<String, dynamic> data) =>
          base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
      final token =
          '${jwtPart({'alg': 'HS256', 'typ': 'JWT'})}.${jwtPart({'sub': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'role': 'authenticated'})}.signature';
      final user = {
        'id': id,
        'aud': 'authenticated',
        'email': 'rani@example.com',
        'created_at': '2026-11-18T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      };
      var updates = 0;
      final auth = SupabaseAuthService(
        client((request) async {
          if (request.url.path == '/auth/v1/signup') {
            final body = jsonDecode(request.body) as Map;
            expect(body['email'], 'rani@example.com');
            expect(body['code_challenge'], isNull);
            expect(body['data'], {
              'full_name': 'Rani',
              'store_name': 'Warung Rani',
            });
            return response({
              'access_token': token,
              'refresh_token': 'refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': user,
            });
          }
          if (request.url.path == '/rest/v1/rpc/get_my_profile') {
            return response({
              'id': id,
              'full_name': 'Rani',
              'role': 'Pemilik',
              'store_id': 'store-1',
              'store_name': 'Warung Rani',
            });
          }
          expect(request.url.path, '/auth/v1/user');
          expect(request.method, 'PUT');
          expect((jsonDecode(request.body) as Map)['password'], 'passwordBaru');
          updates++;
          return response(user);
        }),
      );
      await auth.register(
        name: ' Rani ',
        storeName: ' Warung Rani ',
        email: ' rani@example.com ',
        password: 'password123',
      );
      expect((await auth.getProfile())!.namaToko, 'Warung Rani');
      await auth.changePassword('passwordBaru');
      expect(updates, 1);
    },
  );

  test(
    'buat dan reset Kasir memakai Edge Function tanpa mengirim pilihan role atau toko',
    () async {
      final calls = <Map>[];
      final shop = SupabaseShopService(
        client((request) async {
          expect(request.url.path, '/functions/v1/manage-cashier');
          calls.add(jsonDecode(request.body) as Map);
          return response({'ok': true});
        }),
      );
      await shop.createCashier(
        name: 'Dina',
        email: 'dina@example.com',
        password: 'password123',
      );
      await shop.resetCashierPassword('cashier-1', 'passwordBaru');
      expect(calls, [
        {
          'action': 'create',
          'name': 'Dina',
          'email': 'dina@example.com',
          'password': 'password123',
        },
        {
          'action': 'reset_password',
          'id': 'cashier-1',
          'password': 'passwordBaru',
        },
      ]);
    },
  );

  test('pesan penolakan pembuatan Kasir diteruskan ke form', () async {
    final shop = SupabaseShopService(
      client(
        (request) async => http.Response(
          jsonEncode({'error': 'Email sudah digunakan.'}),
          409,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await expectLater(
      shop.createCashier(
        name: 'Dina',
        email: 'dina@example.com',
        password: 'password123',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Email sudah digunakan.',
        ),
      ),
    );
  });

  test('produk lebih dari satu halaman tetap diambil seluruhnya', () async {
    final offsets = <int>[];
    final service = SupabaseProductService(
      client((request) async {
        expect(request.url.path, '/rest/v1/rpc/get_products');
        final offset = (jsonDecode(request.body) as Map)['p_offset'] as int;
        offsets.add(offset);
        return response(
          offset == 0
              ? List.generate(200, (i) => product(i + 1))
              : [product(201)],
        );
      }),
    );
    expect((await service.getProducts()).length, 201);
    expect(offsets, [0, 200]);
  });

  test(
    'edit metadata produk tidak mengirim stok cache yang mungkin sudah lama',
    () async {
      final service = SupabaseProductService(
        client((request) async {
          expect(request.url.path, '/rest/v1/rpc/update_product');
          final body = jsonDecode(request.body) as Map;
          expect(body.containsKey('p_stock'), isFalse);
          return response(product(1));
        }),
      );
      final result = await service.updateProduct(Produk.fromMap(product(1)));
      expect(result.id, 1);
    },
  );

  test(
    'checkout mengirim ID retry dan harga yang ditampilkan tanpa laba buatan client',
    () async {
      final service = SupabaseTransactionService(
        client((request) async {
          expect(request.url.path, '/rest/v1/rpc/checkout');
          expect(jsonDecode(request.body), {
            'p_request_id': 'request-1',
            'p_cash': 5000,
            'p_expected_total': 4000,
            'p_items': [
              {'product_id': 1, 'qty': 2, 'expected_price': 2000},
            ],
          });
          return response(receipt());
        }),
      );
      final sale = await service.checkout(
        requestId: 'request-1',
        items: {Produk.fromMap(product(1)): 2},
        cash: 5000,
        expectedTotal: 4000,
      );
      expect(sale.items.single.jumlah, 2);
      expect(sale.kembalian, 1000);
      expect(sale.totalLaba, 0); // Kolom finansial tidak dikirim untuk Kasir.
    },
  );

  test(
    'validasi RPC dan penolakan akses diterjemahkan untuk pengguna',
    () async {
      final service = SupabaseTransactionService(
        client(
          (request) async => http.Response(
            jsonEncode({
              'code': 'P0001',
              'message': 'Stok Beras tidak mencukupi.',
            }),
            400,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        service.checkout(
          requestId: 'r',
          items: {Produk.fromMap(product(1)): 2},
          cash: 5000,
          expectedTotal: 4000,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Stok Beras tidak mencukupi.',
          ),
        ),
      );
      final restricted = SupabaseTransactionService(
        client(
          (request) async => http.Response(
            jsonEncode({'code': '42501', 'message': 'denied'}),
            403,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(restricted.getReport(), throwsA(isA<ApiException>()));
    },
  );

  test('periode laporan dikirim sebagai UTC dengan akhir eksklusif', () async {
    final from = DateTime(2026, 11, 1);
    final until = DateTime(2026, 12, 1);
    final service = SupabaseTransactionService(
      client((request) async {
        expect(jsonDecode(request.body), {
          'p_from': from.toUtc().toIso8601String(),
          'p_until': until.toUtc().toIso8601String(),
        });
        return response({
          'transaction_count': 2,
          'item_count': 5,
          'total_sales': 9000,
          'total_profit': 3000,
        });
      }),
    );
    expect((await service.getReport(from: from, until: until)).modal, 6000);
  });
}
