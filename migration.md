# Migration Guide

This guide helps you migrate from vanilla Dio or other networking solutions to Network Kit.

## Table of Contents
- [From Vanilla Dio](#from-vanilla-dio)
- [From Retrofit](#from-retrofit)
- [From Other Libraries](#from-other-libraries)
- [Common Patterns](#common-patterns)

---

## From Vanilla Dio

### Basic GET Request

#### Before
```dart
try {
  setState(() => _loading = true);
  
  final response = await dio.get('/users');
  final users = (response.data as List)
    .map((e) => User.fromJson(e))
    .toList();
  
  setState(() {
    _users = users;
    _loading = false;
    _error = null;
  });
} on DioException catch (e) {
  setState(() {
    _error = e.message;
    _loading = false;
  });
}
```

#### After
```dart
final result = await ApiExecutor.execute<List<User>, dynamic>(
  request: () => dio.get('/users'),
  parser: (json) => (json as List).map((e) => User.fromJson(e)).toList(),
);

result.when(
  idle: () {},
  loading: () => setState(() => _loading = true),
  success: (users) => setState(() {
    _users = users;
    _loading = false;
  }),
  failed: (error) => setState(() => _error = error.message),
  networkError: (error) => showNoInternetDialog(),
);
```

### Authentication

#### Before
```dart
// Manual token management
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await getToken();
    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Manual refresh logic (often broken!)
      final refreshed = await refreshToken();
      if (refreshed) {
        // Retry request
        final opts = err.requestOptions;
        final token = await getToken();
        opts.headers['Authorization'] = 'Bearer $token';
        final response = await Dio().fetch(opts); // ❌ Loses interceptors!
        return handler.resolve(response);
      }
    }
    handler.next(err);
  }
}
```

#### After
```dart
// Implement TokenManager
class MyTokenManager implements TokenManager {
  @override
  Future<String?> getAccessToken() async {
    return await storage.read('access_token');
  }
  
  @override
  Future<bool> refreshToken() async {
    final refresh = await storage.read('refresh_token');
    final response = await Dio().post('/auth/refresh', 
      data: {'refresh_token': refresh}
    );
    await storage.write('access_token', response.data['access_token']);
    return true;
  }
  
  @override
  Future<void> clearTokens() async {
    await storage.deleteAll();
  }
}

// Use AuthInterceptor
NetworkKit.initialize(
  baseUrl: 'https://api.example.com',
  interceptors: [
    AuthInterceptor(
      tokenManager: MyTokenManager(),
      dioProvider: NetworkKit.dioProvider, // ✅ Keeps interceptors!
    ),
  ],
);
```

### Error Handling

#### Before
```dart
try {
  final response = await dio.post('/login', data: credentials);
  return User.fromJson(response.data);
} on DioException catch (e) {
  if (e.type == DioExceptionType.connectionTimeout) {
    throw 'Connection timeout';
  } else if (e.type == DioExceptionType.connectionError) {
    throw 'No internet';
  } else if (e.response?.statusCode == 401) {
    throw 'Invalid credentials';
  } else if (e.response?.statusCode == 422) {
    final errors = e.response?.data['errors'];
    throw errors;
  }
  throw 'Unknown error';
}
```

#### After
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

final result = await ApiExecutor.execute<User, LoginError>(
  request: () => dio.post('/login', data: credentials),
  parser: (json) => User.fromJson(json),
  errorParser: (json) => LoginError.fromJson(json),
);

result.when(
  success: (user) => print('Logged in as ${user.name}'),
  failed: (error) {
    if (error.errorData?.email != null) {
      print('Email error: ${error.errorData!.email}');
    }
  },
  networkError: (error) => print('No internet'),
  // ...
);
```

### Retry Logic

#### Before
```dart
Future<Response> retryRequest(RequestOptions options, int retries) async {
  for (int i = 0; i < retries; i++) {
    try {
      return await Dio().fetch(options);
    } catch (e) {
      if (i == retries - 1) rethrow;
      await Future.delayed(Duration(seconds: math.pow(2, i).toInt()));
    }
  }
  throw Exception('Max retries reached');
}

// Usage
try {
  final response = await dio.get('/data');
} catch (e) {
  final response = await retryRequest(requestOptions, 3);
}
```

#### After
```dart
// Just add the interceptor
NetworkKit.initialize(
  baseUrl: 'https://api.example.com',
  interceptors: [
    RetryInterceptor(
      config: RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(seconds: 1),
      ),
    ),
  ],
);

// All requests automatically retried on network errors
```

### Logging

#### Before
```dart
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('${options.method} ${options.uri}');
    print('Headers: ${options.headers}'); // ❌ Logs sensitive data!
    print('Data: ${options.data}'); // ❌ Logs passwords!
    handler.next(options);
  }
}
```

#### After
```dart
LoggingInterceptor(
  level: LogLevel.body,
  redactHeaders: ['authorization', 'cookie'],
  redactFields: ['password', 'token', 'ssn'],
)

// Automatic redaction:
// Headers:
//   Authorization: ***REDACTED***
// Body:
//   password: ***REDACTED***
```

---

## From Retrofit

### Service Definition

#### Before (Retrofit)
```dart
@RestApi(baseUrl: 'https://api.example.com')
abstract class ApiService {
  factory ApiService(Dio dio) = _ApiService;
  
  @GET('/users/{id}')
  Future<User> getUser(@Path() String id);
  
  @POST('/users')
  Future<User> createUser(@Body() Map<String, dynamic> data);
}

// Usage
final service = ApiService(dio);
final user = await service.getUser('123');
```

#### After (Network Kit)
```dart
// No code generation needed!
class UserApi {
  final Dio dio;
  
  UserApi(this.dio);
  
  Future<ApiState<User, dynamic>> getUser(String id) {
    return ApiExecutor.execute<User, dynamic>(
      request: () => dio.get('/users/$id'),
      parser: (json) => User.fromJson(json),
    );
  }
  
  Future<ApiState<User, ValidationError>> createUser(Map<String, dynamic> data) {
    return ApiExecutor.execute<User, ValidationError>(
      request: () => dio.post('/users', data: data),
      parser: (json) => User.fromJson(json),
      errorParser: (json) => ValidationError.fromJson(json),
    );
  }
}

// Usage
final api = UserApi(NetworkKit.dio);
final result = await api.getUser('123');

result.when(
  success: (user) => print(user.name),
  failed: (error) => print(error.message),
  // ...
);
```

---

## Common Patterns

### 1. Loading State in StatefulWidget

#### Before
```dart
class UserListScreen extends StatefulWidget {
  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _loading = false;
  List<User>? _users;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }
  
  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final response = await dio.get('/users');
      final users = (response.data as List)
        .map((e) => User.fromJson(e))
        .toList();
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) return CircularProgressIndicator();
    if (_error != null) return Text('Error: $_error');
    if (_users == null) return Text('No data');
    return ListView.builder(...);
  }
}
```

#### After
```dart
class UserListScreen extends StatefulWidget {
  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  ApiState<List<User>, dynamic> _state = const ApiState.idle();
  StreamSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }
  
  void _loadUsers() {
    _subscription = ApiExecutor.executeAsStateStream<List<User>, dynamic>(
      request: () => NetworkKit.dio.get('/users'),
      parser: (json) => (json as List).map((e) => User.fromJson(e)).toList(),
    ).listen((state) {
      setState(() => _state = state);
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return _state.when(
      idle: () => Text('Ready'),
      loading: () => CircularProgressIndicator(),
      success: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) => UserTile(users[index]),
      ),
      failed: (error) => ErrorWidget(error.message),
      networkError: (error) => NoInternetWidget(),
    );
  }
}
```

### 2. Form Validation Errors

#### Before
```dart
Map<String, String> _errors = {};

try {
  await dio.post('/users', data: formData);
} on DioException catch (e) {
  if (e.response?.statusCode == 422) {
    final errors = e.response?.data['errors'] as Map;
    setState(() {
      _errors = errors.map((k, v) => MapEntry(k, v.toString()));
    });
  }
}
```

#### After
```dart
class ValidationError {
  final Map<String, List<String>> fieldErrors;
  
  factory ValidationError.fromJson(Map<String, dynamic> json) {
    // Parse validation errors
  }
  
  List<String>? getErrors(String field) => fieldErrors[field];
}

final result = await ApiExecutor.execute<User, ValidationError>(
  request: () => NetworkKit.dio.post('/users', data: formData),
  parser: (json) => User.fromJson(json),
  errorParser: (json) => ValidationError.fromJson(json),
);

result.when(
  success: (user) => navigateToProfile(user),
  failed: (error) {
    final validationError = error.errorData;
    if (validationError != null) {
      final emailErrors = validationError.getErrors('email');
      if (emailErrors != null) {
        showFieldError('email', emailErrors.first);
      }
    }
  },
  // ...
);
```

### 3. Multiple Concurrent Requests

#### Before
```dart
Future<void> loadDashboard() async {
  setState(() => _loading = true);
  
  try {
    final results = await Future.wait([
      dio.get('/user'),
      dio.get('/stats'),
      dio.get('/notifications'),
    ]);
    
    setState(() {
      _user = User.fromJson(results[0].data);
      _stats = Stats.fromJson(results[1].data);
      _notifications = (results[2].data as List)
        .map((e) => Notification.fromJson(e))
        .toList();
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _loading = false;
    });
  }
}
```

#### After
```dart
Future<void> loadDashboard() async {
  final results = await Future.wait([
    ApiExecutor.execute<User, dynamic>(
      request: () => NetworkKit.dio.get('/user'),
      parser: (json) => User.fromJson(json),
    ),
    ApiExecutor.execute<Stats, dynamic>(
      request: () => NetworkKit.dio.get('/stats'),
      parser: (json) => Stats.fromJson(json),
    ),
    ApiExecutor.execute<List<Notification>, dynamic>(
      request: () => NetworkKit.dio.get('/notifications'),
      parser: (json) => (json as List)
        .map((e) => Notification.fromJson(e))
        .toList(),
    ),
  ]);
  
  // All results are ApiState, handle them appropriately
  if (results.every((r) => r.isSuccess)) {
    setState(() {
      _user = results[0].data;
      _stats = results[1].data;
      _notifications = results[2].data;
    });
  } else {
    // Handle errors
    final firstError = results.firstWhere((r) => r.hasError);
    setState(() => _error = firstError.error);
  }
}
```

---

## Benefits of Migration

### Code Reduction
- ✅ 40-60% less boilerplate code
- ✅ No manual state management
- ✅ No manual error handling

### Type Safety
- ✅ Fully typed states
- ✅ Custom error types
- ✅ No runtime type casting errors

### Features
- ✅ Automatic token refresh
- ✅ Smart retry with safety
- ✅ Clean logging
- ✅ Network error detection

### Maintainability
- ✅ Consistent patterns
- ✅ Less bug-prone
- ✅ Easier to test

---

## Need Help?

- Check the [README](README.md) for full documentation
- See [examples](example/) for complete code samples
- Open an issue on GitHub for support