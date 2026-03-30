// ============================================================================
//  example/lib/main.dart
//
//  keystone_network v1.0.0 — Full Example Application
//
//  This project demonstrates every major feature of keystone_network:
//
//    1. Initialization with all interceptors
//    2. ApiState with the new empty state
//    3. buildWidget() UI helper
//    4. Type-safe ApiError with switch pattern matching
//    5. ApiExecutor.execute() with emptyCheck + cache
//    6. Upload with real-time progress stream
//    7. Pagination with ApiPaginator + PaginatedListView
//    8. Custom TokenManager and environment config
//
//  Run with: flutter run
// ============================================================================

import 'package:flutter/material.dart';
import 'package:keystone_network/config/keystone_network.dart';
import 'package:keystone_network/keystone_network.dart';

import 'config/app_config.dart';
import 'data/token_manager.dart';
import 'screens/gallery_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Pick environment ─────────────────────────────────────────────────
  //
  // In a real app you would read this from dart-define or a build flavor.
  // e.g. const env = String.fromEnvironment('ENV', defaultValue: 'development');
  const config = AppConfig(Environment.development);

  // ── 2. Initialize KeystoneNetwork ───────────────────────────────────────
  //
  // Call this exactly once before runApp().
  // All interceptors share the same DioProvider so retry/auth never lose
  // the interceptor chain.
  KeystoneNetwork.initialize(
    baseUrl: config.baseUrl,
    connectTimeout: config.connectTimeout,
    receiveTimeout: config.receiveTimeout,
    headers: config.headers,
    interceptors: [
      // Auth — injects Bearer token and refreshes on 401

    ],
  );
  KeystoneNetwork.dio.interceptors.addAll([
    AuthInterceptor(
      tokenManager: AppTokenManager(),
      dioProvider: KeystoneNetwork.dioProvider,
    ),

    // Retry — exponential backoff for network errors and 5xx
    RetryInterceptor(
      dioProvider: KeystoneNetwork.dioProvider,
      config: const RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(seconds: 1),
        multiplier: 2.0,
      ),
    ),

    // Logging — full body in debug, none in production
    LoggingInterceptor(
      level: config.enableLogging ? LogLevel.body : LogLevel.none,
      // Redact sensitive fields from logs
      redactFields: const ['password', 'token', 'access_token', 'refresh_token'],
    ),
  ]);

  // ── 3. (Optional) Replace the default in-memory cache with persistent ──
  //
  // Uncomment and configure your preferred backend:
  //
  //   ApiCache.storage = HiveCacheStorage();
  //   ApiCache.storage = SharedPrefsCacheStorage();
  //
  // The default InMemoryCacheStorage works out of the box with no extra deps.

  runApp(const GalleryApp());
}

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'keystone_network Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A56DB)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

/// Bottom-nav shell that hosts the three demo screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    GalleryScreen(),   // Demonstrates pagination + cache + empty state
    UploadScreen(),    // Demonstrates upload with progress stream
    ProfileScreen(),   // Demonstrates execute() + type-safe error handling
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Gallery'),
          NavigationDestination(icon: Icon(Icons.upload_file),   label: 'Upload'),
          NavigationDestination(icon: Icon(Icons.person),        label: 'Profile'),
        ],
      ),
    );
  }
}
