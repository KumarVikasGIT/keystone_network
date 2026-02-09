/// Generic token manager interface for authentication
///
/// Implement this interface to integrate with your auth system.
/// The AuthInterceptor will use this to manage tokens.
///
/// **Example Implementation:**
/// ```dart
/// class MyTokenManager implements TokenManager {
///   final SecureStorage _storage;
///   final Dio _authDio; // ✅ Dedicated Dio instance for auth
///
///   MyTokenManager(this._storage, this._authDio);
///
///   @override
///   Future<String?> getAccessToken() async {
///     return await _storage.read(key: 'access_token');
///   }
///
///   @override
///   Future<String?> getRefreshToken() async {
///     return await _storage.read(key: 'refresh_token');
///   }
///
///   @override
///   Future<bool> refreshToken() async {
///     try {
///       final refreshToken = await getRefreshToken();
///       if (refreshToken == null) return false;
///
///       // ✅ Use dedicated auth Dio (without AuthInterceptor to avoid loops)
///       final response = await _authDio.post(
///         '/auth/refresh',
///         data: {'refresh_token': refreshToken},
///       );
///
///       final newAccessToken = response.data['access_token'];
///       final newRefreshToken = response.data['refresh_token'];
///
///       await _storage.write(key: 'access_token', value: newAccessToken);
///       await _storage.write(key: 'refresh_token', value: newRefreshToken);
///
///       return true;
///     } catch (e) {
///       return false;
///     }
///   }
///
///   @override
///   Future<void> clearTokens() async {
///     await _storage.delete(key: 'access_token');
///     await _storage.delete(key: 'refresh_token');
///   }
/// }
///
/// // Setup
/// final authDio = NetworkKit.createInstance(
///   baseUrl: 'https://api.example.com',
///   interceptors: [
///     LoggingInterceptor(), // ✅ Can still have logging
///     // ❌ DON'T add AuthInterceptor here (infinite loop)
///   ],
/// );
///
/// final tokenManager = MyTokenManager(secureStorage, authDio);
/// ```
abstract class TokenManager {
  /// Get the current access token
  ///
  /// Returns null if no token is available or if it has expired.
  Future<String?> getAccessToken();

  /// Get the current refresh token
  ///
  /// Returns null if no refresh token is available.
  Future<String?> getRefreshToken();

  /// Refresh the access token using the refresh token
  ///
  /// Returns true if refresh was successful, false otherwise.
  /// Should update the stored access token on success.
  Future<bool> refreshToken();

  /// Clear all stored tokens (logout)
  ///
  /// This should remove both access and refresh tokens from storage.
  Future<void> clearTokens();

  /// Check if user is authenticated
  ///
  /// Default implementation checks if access token exists.
  /// Override this if you have custom authentication logic.
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
