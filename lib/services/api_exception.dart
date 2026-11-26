import 'package:supabase_flutter/supabase_flutter.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

// Semua halaman menerima pesan yang dapat ditampilkan langsung kepada pengguna.
Future<T> apiCall<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException {
    rethrow;
  } on AuthException catch (error) {
    if (error.code == 'invalid_credentials') {
      throw const ApiException('Email atau password salah.');
    }
    if (error.code == 'email_not_confirmed') {
      throw const ApiException('Akun belum aktif. Hubungi pengelola aplikasi.');
    }
    if (error.code == 'user_already_exists' || error.code == 'email_exists') {
      throw const ApiException(
        'Email sudah digunakan. Silakan masuk atau gunakan email lain.',
      );
    }
    if (error.code == 'weak_password') {
      throw const ApiException('Password minimal 8 karakter.');
    }
    if (error.code == 'signup_disabled') {
      throw const ApiException(
        'Pendaftaran belum dibuka. Hubungi pengelola aplikasi.',
      );
    }
    throw const ApiException('Sesi tidak valid. Silakan masuk kembali.');
  } on FunctionException catch (error) {
    final data = error.details;
    if (data is Map && data['code'] == 'invalid_password') {
      throw const ApiException('Password salah. Periksa dan coba lagi.');
    }
    if (data is Map && data['code'] == 'invalid_session') {
      throw const ApiException('Sesi tidak valid. Silakan masuk kembali.');
    }
    if (data is Map && data['error'] is String) {
      throw ApiException(data['error'] as String);
    }
    throw const ApiException(
      'Layanan akun belum tersedia. Coba lagi atau hubungi pengelola aplikasi.',
    );
  } on PostgrestException catch (error) {
    if (error.code == 'P0001') throw ApiException(error.message);
    if (error.code == '42501') {
      throw const ApiException('Akun tidak memiliki akses ke fitur ini.');
    }
    if (error.code == '23514' || error.code == '22003') {
      throw const ApiException('Harga, jumlah, atau stok di luar batas.');
    }
    if (error.code == 'PGRST202' || error.code == '42P01') {
      throw const ApiException(
        'Layanan toko belum siap. Hubungi pengelola aplikasi.',
      );
    }
    throw const ApiException(
      'Permintaan database gagal. Muat ulang dan coba lagi.',
    );
  } catch (_) {
    throw const ApiException(
      'Tidak dapat terhubung. Periksa koneksi dan coba lagi.',
    );
  }
}
