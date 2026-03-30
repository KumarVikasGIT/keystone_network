// ============================================================================
//  example/lib/config/app_config.dart
//
//  Demonstrates MultiEnvironmentConfig — define all environments in one class.
//  KeystoneNetwork picks the right base URL, headers, and timeouts based on
//  the active Environment enum value.
// ============================================================================

import 'package:keystone_network/keystone_network.dart';

class AppConfig extends MultiEnvironmentConfig {
  const AppConfig(super.environment);

  // ── Base URLs ─────────────────────────────────────────────────────────────

  @override
  String getBaseUrl(Environment env) => switch (env) {
    Environment.development => 'https://dev-api.example.com/v1',
    Environment.staging     => 'https://staging-api.example.com/v1',
    Environment.production  => 'https://api.example.com/v1',
  };

  // ── Default headers ───────────────────────────────────────────────────────
  //
  // These are merged with Accept/Content-Type that KeystoneNetwork adds by
  // default. You can override any header here.

  @override
  Map<String, dynamic> getHeaders(Environment env) => {
    'X-App-Version': '1.0.0',
    'X-Platform':    'flutter',
    'X-Env':         env.name,
  };

  // ── Timeouts ──────────────────────────────────────────────────────────────
  //
  // Development gets a longer timeout so you can pause in debugger or use
  // a slow local server. Production is tighter.

  @override
  Duration getConnectTimeout(Environment env) => switch (env) {
    Environment.development => const Duration(seconds: 60),
    _                       => const Duration(seconds: 30),
  };

  @override
  Duration getReceiveTimeout(Environment env) => switch (env) {
    Environment.development => const Duration(seconds: 60),
    _                       => const Duration(seconds: 30),
  };
}
