import 'package:supabase_flutter/supabase_flutter.dart';
import '../data.dart';
import 'api_exception.dart';

class AccountDeletionRequest {
  final String id;
  final String status;
  final DateTime requestedAt;
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
  });

  factory AccountDeletionRequest.fromMap(Map<String, dynamic> map) =>
      AccountDeletionRequest(
        id: map['id'].toString(),
        status: map['status'] as String,
        requestedAt: DateTime.parse(map['requested_at'] as String),
      );
}

abstract interface class AuthService {
  Stream<void> get changes;
  Future<Profil?> getProfile();
  Future<void> signIn(String email, String password);
  Future<void> register({
    required String name,
    required String storeName,
    required String email,
    required String password,
  });
  Future<void> changePassword(String password);
  Future<AccountDeletionRequest?> getAccountDeletionRequest();
  Future<AccountDeletionRequest> requestAccountDeletion();
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  final SupabaseClient client;
  const SupabaseAuthService(this.client);

  @override
  Stream<void> get changes => client.auth.onAuthStateChange
      .where(
        (state) => const {
          AuthChangeEvent.initialSession,
          AuthChangeEvent.signedIn,
          AuthChangeEvent.signedOut,
        }.contains(state.event),
      )
      .map((_) {});

  @override
  Future<Profil?> getProfile() => apiCall(() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client.rpc('get_my_profile');
    if (row == null) {
      throw const ApiException(
        'Profil belum tersedia. Hubungi Pemilik warung.',
      );
    }
    return Profil.fromMap(Map<String, dynamic>.from(row as Map));
  });

  @override
  Future<void> register({
    required String name,
    required String storeName,
    required String email,
    required String password,
  }) => apiCall(() async {
    final result = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': name.trim(), 'store_name': storeName.trim()},
    );
    if (result.session == null) {
      throw const ApiException(
        'Akun belum dapat masuk otomatis. Hubungi pengelola aplikasi.',
      );
    }
  });

  @override
  Future<void> changePassword(String password) => apiCall(() async {
    await client.rpc('get_my_profile');
    await client.auth.updateUser(UserAttributes(password: password));
  });

  @override
  Future<void> signIn(String email, String password) => apiCall(() async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  });

  @override
  Future<AccountDeletionRequest?> getAccountDeletionRequest() =>
      apiCall(() async {
        final row = await client.rpc('get_my_account_deletion_request');
        return row == null
            ? null
            : AccountDeletionRequest.fromMap(
                Map<String, dynamic>.from(row as Map),
              );
      });

  @override
  Future<AccountDeletionRequest> requestAccountDeletion() => apiCall(() async {
    final row = await client.rpc(
      'request_account_deletion',
      params: {'p_confirm': true},
    );
    return AccountDeletionRequest.fromMap(
      Map<String, dynamic>.from(row as Map),
    );
  });

  @override
  Future<void> signOut() => apiCall(() async {
    await client.auth.signOut(scope: SignOutScope.local);
  });
}
