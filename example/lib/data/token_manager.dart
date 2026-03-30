// ============================================================================
//  example/lib/data/token_manager.dart
//
//  Concrete TokenManager implementation.
//
//  Key design rule: the authDio instance used inside refreshToken() must NOT
//  have AuthInterceptor attached — otherwise a 401 on the refresh endpoint
//  triggers another refresh, creating an infinite loop.
//
//  In a real app, replace the in-memory Map with flutter_secure_storage:
//
//    final _storage = FlutterSecureStorage();
//    await _storage.write(key: 'access_token', value: token);
//    final token = await _storage.read(key: 'access_token');
// ============================================================================

import 'package:keystone_network/config/keystone_network.dart';
import 'package:keystone_network/keystone_network.dart';

class AppTokenManager implements TokenManager {
  // ── In-memory token store (replace with secure storage in production) ─────
  final Map<String, String> _store = {
    // Seed a fake token so the example works without a real auth server
    'access_token':  'fake-access-token-123',
    'refresh_token': 'fake-refresh-token-456',
  };

  // ── Dedicated Dio for auth calls (no AuthInterceptor — avoids loops) ──────
  //
  // Notice we use KeystoneNetwork.createInstance() and deliberately omit
  // AuthInterceptor from the interceptors list.
  final Dio _authDio = KeystoneNetwork.createInstance(
    baseUrl: 'https://dev-api.example.com/v1',
    interceptors: [
      // Logging is fine here — just not AuthInterceptor
      LoggingInterceptor(level: LogLevel.basic),
    ],
  );

  // ── TokenManager interface ────────────────────────────────────────────────

  @override
  Future<String?> getAccessToken() async => _store['access_token'];

  @override
  Future<String?> getRefreshToken() async => _store['refresh_token'];

  @override
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      // Call the refresh endpoint with the dedicated auth Dio
      final response = await _authDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      // Store the new tokens
      _store['access_token']  = response.data['access_token'] as String;
      _store['refresh_token'] = response.data['refresh_token'] as String;

      return true;
    } catch (_) {
      // Refresh failed — AuthInterceptor will call clearTokens() next
      return false;
    }
  }

  @override
  Future<void> clearTokens() async {
    _store.remove('access_token');
    _store.remove('refresh_token');
    // In a real app: navigate to login screen here
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
