# 🚀 Keystone Network

**Clean, Generic, Minimal Networking Library for Flutter**

[![pub package](https://img.shields.io/pub/v/keystone_network.svg)](https://pub.dev/packages/keystone_network)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready networking library that provides type-safe API state management, automatic error handling, smart retry logic, and token management—all in a minimal, tree-shakeable package.

## ✨ Features

- **🎯 Type-Safe State Management** - Best-in-class `ApiState` pattern for handling API responses
- **🔒 Production-Ready Auth** - Token management with automatic refresh (90% of auth interceptors are broken, ours isn't)
- **🔁 Smart Retry Logic** - Exponential backoff with idempotency protection (prevents double payments!)
- **📝 Clean Logging** - Formatted logs with sensitive data redaction
- **🌐 Generic First** - Works with ANY API structure, no opinions forced
- **📦 Minimal Core** - ~500 lines for basic usage, tree-shakeable
- **🎨 Optional Features** - Use only what you need
- **🛡️ Type-Safe Errors** - Custom error types with full type safety

## 🎯 Why Keystone Network?

### vs Vanilla Dio
✅ Type-safe state management  
✅ Built-in error handling  
✅ No boilerplate  
✅ Better developer experience

### vs Other Libraries
✅ Smaller size (< 1,000 lines with all features)  
✅ More generic (no opinions)  
✅ Better type safety  
✅ Plugin architecture

### Unique Value
✅ **ApiState pattern** - Best in class  
✅ **Actually safe auth** - Not broken like 90% of implementations  
✅ **Idempotency by default** - Prevents critical bugs  
✅ **Minimal core** - Small bundle size

## 📦 Installation

```yaml
dependencies:
  keystone_network: ^0.1.2
  dio: ^5.9.1
```

## 🚀 Quick Start

### 1. Basic Usage (No Configuration)

```dart
import 'package:dio/dio.dart';
import 'package:keystone_network/keystone_network.dart';

// Use your own Dio instance
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

// Make request
final result = await ApiExecutor.execute<User, dynamic>(
  request: () => dio.get('/user/me'),
  parser: (json) => User.fromJson(json),
);

// Handle states
result.when(
  idle: () => Text('Ready'),
  loading: () => CircularProgressIndicator(),
  success: (user) => Text('Hello, ${user.name}'),
  failed: (error) => Text('Error: ${error.message}'),
  networkError: (error) => Text('No internet'),
);
```

### 2. Full Setup (Production-Ready)

```dart
void main() {
  // Initialize once
  KeystoneNetwork.initialize(
    baseUrl: 'https://api.example.com',
    interceptors: [
      AuthInterceptor(
        tokenManager: myTokenManager,
        dioProvider: KeystoneNetwork.dioProvider, // ✅ Important!
      ),
      RetryInterceptor(),
      LoggingInterceptor(level: LogLevel.body),
    ],
  );
  
  runApp(MyApp());
}

// Use anywhere
final result = await ApiExecutor.execute<User, dynamic>(
  request: () => KeystoneNetwork.dio.get('/user/me'),
  parser: (json) => User.fromJson(json),
);
```

## 📖 Core Concepts

### ApiState - Type-Safe State Management

`ApiState<T, E>` represents the state of an API request with full type safety.

```dart
sealed class ApiState<T, E> {
  idle,          // Initial state
  loading,       // Request in progress
  success(T),    // Success with data
  failed(Error), // Failed with error
  networkError,  // Network-related error
}
```

#### Pattern Matching

```dart
result.when(
  idle: () => print('Ready'),
  loading: () => print('Loading...'),
  success: (data) => print('Got data: $data'),
  failed: (error) => print('Error: ${error.message}'),
  networkError: (error) => print('No internet'),
);
```

#### State Checks

```dart
if (result.isSuccess) {
  print(result.data!.name);
}

if (result.isNetworkError) {
  showNoInternetDialog();
}

if (result.hasError) {
  showError(result.error!.message);
}
```

#### Mapping

```dart
final userState = await ApiExecutor.execute<User, dynamic>(...);

// Map to different type
final nameState = userState.map((user) => user.name);
// ApiState<String, dynamic>
```

### ApiExecutor - Clean Request Execution

#### Simple Execution

```dart
final result = await ApiExecutor.execute<User, dynamic>(
  request: () => dio.get('/user/123'),
  parser: (json) => User.fromJson(json),
);
```

#### With Custom Errors

```dart
final result = await ApiExecutor.execute<User, LoginError>(
  request: () => dio.post('/login', data: {...}),
  parser: (json) => User.fromJson(json['user']),
  errorParser: (json) => LoginError.fromJson(json),
);

result.when(
  success: (user) => navigateHome(user),
  failed: (error) {
    // Type-safe error!
    if (error.errorData?.email != null) {
      showFieldError('email', error.errorData!.email!);
    }
  },
  // ...
);
```

#### Stream for Loading State

```dart
ApiExecutor.executeAsStateStream<List<User>, dynamic>(
  request: () => dio.get('/users'),
  parser: (json) => (json as List).map((e) => User.fromJson(e)).toList(),
).listen((state) {
  setState(() => _state = state);
});
```

## 🔧 Features

### 🔐 Auth Interceptor (Token Management)

Handles token injection and automatic refresh with race condition prevention.

#### Implementation

```dart
class MyTokenManager implements TokenManager {
  final SecureStorage storage;
  
  @override
  Future<String?> getAccessToken() async {
    return await storage.read('access_token');
  }
  
  @override
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await storage.read('refresh_token');
      final response = await Dio().post('/auth/refresh', 
        data: {'refresh_token': refreshToken}
      );
      
      await storage.write('access_token', response.data['access_token']);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<void> clearTokens() async {
    await storage.deleteAll();
  }
}
```

#### Usage

```dart
final authInterceptor = AuthInterceptor(
  tokenManager: MyTokenManager(),
  dioProvider: KeystoneNetwork.dioProvider, // ✅ Prevents config loss
);

KeystoneNetwork.initialize(
  baseUrl: 'https://api.example.com',
  interceptors: [authInterceptor],
);

// Now all requests have auth token
// Auto refresh on 401
```

#### Skip Auth for Public Endpoints

```dart
dio.get('/public/data', 
  options: Options(extra: {'skipAuth': true})
);
```

### 🔁 Retry Interceptor (Smart Retry)

Exponential backoff with idempotency protection to prevent double payments.

#### Features

- ✅ Automatic retry on network errors and 5xx
- ✅ Exponential backoff
- ✅ Idempotency protection (GET, PUT, DELETE retried by default)
- ✅ POST/PATCH require explicit opt-in

#### Usage

```dart
RetryInterceptor(
  config: RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
    multiplier: 2.0,
  ),
);
```

#### Allow Retry on POST (Use with Caution)

```dart
dio.post('/orders', 
  data: {...},
  options: Options(
    extra: {'allowRetry': true}, // ⚠️ Explicit opt-in
  ),
);
```

#### Custom Retry Logic

```dart
RetryInterceptor(
  config: RetryConfig(
    shouldRetry: (error) {
      // Only retry on specific errors
      return error.type == DioExceptionType.connectionTimeout ||
             error.response?.statusCode == 503;
    },
  ),
);
```

### 📝 Logging Interceptor

Clean, formatted logs with sensitive data redaction.

#### Usage

```dart
LoggingInterceptor(
  level: LogLevel.body,
  redactHeaders: ['authorization', 'cookie'],
  redactFields: ['password', 'token', 'ssn'],
);
```

#### Log Levels

```dart
enum LogLevel {
  none,     // No logging
  basic,    // URL + status
  headers,  // + headers
  body,     // + bodies
}
```

#### Request ID Tracking

```dart
// Automatic request ID generation for distributed debugging
┌──── Request [abc123] ────────────────────────────
│ GET https://api.example.com/users
│ Headers:
│   Authorization: ***REDACTED***
│   Content-Type: application/json
└──────────────────────────────────────────────────

┌──── Response [abc123] ───────────────────────────
│ 200 https://api.example.com/users
│ Body: [...]
└──────────────────────────────────────────────────
```

## 🌍 Environment Configuration

### Simple Configuration

```dart
final config = DefaultEnvironmentConfig(
  environment: Environment.production,
  baseUrl: 'https://api.example.com',
);

KeystoneNetwork.initialize(
  baseUrl: config.baseUrl,
  connectTimeout: config.connectTimeout,
);
```

### Multi-Environment Configuration

```dart
class AppConfig extends MultiEnvironmentConfig {
  const AppConfig(super.environment);
  
  @override
  String getBaseUrl(Environment env) {
    return switch (env) {
      Environment.development => 'https://dev-api.example.com',
      Environment.staging => 'https://staging-api.example.com',
      Environment.production => 'https://api.example.com',
    };
  }
  
  @override
  Map<String, dynamic> getHeaders(Environment env) {
    return {
      'X-App-Version': '1.0.0',
      'X-Environment': env.name,
    };
  }
}

// Usage
const config = AppConfig(Environment.production);
KeystoneNetwork.initialize(
  baseUrl: config.baseUrl,
  headers: config.headers,
);
```

## 🎨 Custom Error Types

Define type-safe errors for different endpoints.

```dart
class LoginError {
  final String? email;
  final String? password;
  
  factory LoginError.fromJson(Map<String, dynamic> json) {
    return LoginError(
      email: json['errors']?['email'],
      password: json['errors']?['password'],
    );
  }
}

// Use with type safety
final result = await ApiExecutor.execute<User, LoginError>(
  request: () => dio.post('/login', data: {...}),
  parser: (json) => User.fromJson(json),
  errorParser: (json) => LoginError.fromJson(json),
);

result.when(
  success: (user) => print('Welcome ${user.name}'),
  failed: (error) {
    if (error.errorData?.email != null) {
      showError('Email', error.errorData!.email!);
    }
  },
  // ...
);
```

## 📊 Error Detection Extensions

```dart
if (error.isNetworkError) {
  showNoInternetDialog();
}

if (error.isAuthError) {
  navigateToLogin();
}

if (error.isValidationError) {
  showValidationErrors();
}

if (error.isServerError) {
  showRetryButton();
}
```

## 🔒 Security Best Practices

### Token Storage

```dart
// ✅ Good: Use flutter_secure_storage
final storage = FlutterSecureStorage();
await storage.write(key: 'access_token', value: token);

// ❌ Bad: Never use SharedPreferences for tokens
// Tokens in SharedPreferences are not encrypted!
```

### Sensitive Data Redaction

```dart
LoggingInterceptor(
  redactHeaders: ['authorization', 'cookie', 'x-api-key'],
  redactFields: ['password', 'token', 'ssn', 'credit_card'],
);
```

## 📏 Package Size

- **Core only:** ~500 lines
- **With KeystoneNetwork:** ~550 lines
- **All features:** ~880 lines
- **Tree-shakeable:** Import only what you use

## 🧪 Testing

```dart
// Mock Dio for testing
final mockDio = MockDio();

when(() => mockDio.get('/users'))
  .thenAnswer((_) async => Response(
    data: [{'id': '1', 'name': 'John'}],
    statusCode: 200,
  ));

final result = await ApiExecutor.execute<List<User>, dynamic>(
  request: () => mockDio.get('/users'),
  parser: (json) => (json as List).map((e) => User.fromJson(e)).toList(),
);

expect(result.isSuccess, true);
expect(result.data?.length, 1);
```

## 📚 Examples

See the `/example` folder for complete examples:

- `basic_usage.dart` - Minimal usage
- `complete_setup.dart` - Full production setup
- `custom_error.dart` - Type-safe error handling

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines.

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Credits

- Inspired by best practices from the Flutter community
- Built on top of the excellent [Dio](https://pub.dev/packages/dio) package

## 🚀 Roadmap

- [ ] Cache interceptor
- [ ] File upload/download helpers
- [ ] GraphQL support
- [ ] WebSocket support
- [ ] Request policy (cache-first, network-first)

---

Made with ❤️ for the Flutter community