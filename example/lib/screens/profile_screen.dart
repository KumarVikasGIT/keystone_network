// ============================================================================
//  example/lib/screens/profile_screen.dart
//
//  Demonstrates:
//    • ApiExecutor.execute() with emptyCheck and cache
//    • ApiState.buildWidget() — eliminates per-screen switch boilerplate
//    • Type-safe ApiError via switch expression pattern matching
//    • ValidationError field-level messages (from a form update)
//    • CachePolicy.networkFirst with manual cache invalidation
// ============================================================================

import 'package:flutter/material.dart';
import 'package:keystone_network/config/keystone_network.dart';
import 'package:keystone_network/keystone_network.dart';

import '../data/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  // Start as idle — no request fired yet.
  ApiState<User, ApiError> _state = const ApiState.idle();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Load profile ──────────────────────────────────────────────────────────
  //
  // execute() does NOT emit loading — we set it manually here so we have full
  // control over when loading starts (useful for pull-to-refresh scenarios
  // where you want to keep showing old data while refreshing).
  //
  // CachePolicy.networkFirst: always tries the network; if the network fails
  // (e.g. offline) it returns the last cached response instead of showing
  // an error.

  Future<void> _loadProfile() async {
    setState(() => _state = const ApiState.loading());

    final result = await ApiExecutor.execute<User, ApiError>(
      request:  () => KeystoneNetwork.dio.get('/user/me'),
      parser:   User.fromJson,

      // emptyCheck: parser returns a User object so empty isn't relevant here.
      // Shown here for completeness — omit when not needed.
      // emptyCheck: (user) => user.name.isEmpty,

      cache: const CacheConfig(
        policy:   CachePolicy.networkFirst,
        key:      'user_profile',
        duration: Duration(minutes: 10),
      ),
    );

    // Update state from the Future result
    if (mounted) setState(() => _state = result);
  }

  // ── Update profile (demonstrates ValidationError handling) ───────────────

  Future<void> _updateDisplayName(String newName) async {
    try {
      await KeystoneNetwork.dio.patch(
        '/user/me',
        data: {'name': newName},
      );

      // Invalidate cache so next load fetches fresh data
      await ApiCache.invalidate('user_profile');
      await _loadProfile();

    } on DioException catch (e) {
      // Convert to typed ApiError
      final handler = ErrorHandler<ApiError>.handle(e);

      // ── Pattern match on ApiError subtypes ─────────────────────────────────
      //
      // This is the key benefit of the type-safe error hierarchy.
      // Each case gets the exact fields it needs — no casting required.

      final message = switch (handler.apiError) {
        // 422: Show field-level validation errors from the server
        ValidationError(:final fields) =>
          fields['name']?.first ?? 'Validation failed',

        // 401: Token expired between load and update
        UnauthorizedError() =>
          'Session expired. Please log in again.',

        // Network issues
        NetworkError()  => 'No internet. Check your connection.',
        TimeoutError()  => 'Request timed out. Try again.',

        // Everything else
        _ => handler.apiError.message,
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfile,
          ),
        ],
      ),

      // ── buildWidget() — the one-liner that replaces 20+ lines of if/switch ──
      //
      // Each builder is called only for its matching state.
      // idle and networkError use their default fallbacks (SizedBox.shrink
      // and the error handler respectively) — you only override what you need.

      body: _state.buildWidget(
        loading: () => const Center(child: CircularProgressIndicator()),

        success: (user) => _ProfileBody(
          user: user,
          onUpdateName: _updateDisplayName,
        ),

        // empty: omitted — falls back to SizedBox.shrink()
        // We don't expect /user/me to return empty data.

        error: (message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),

        networkError: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('No internet connection'),
              const SizedBox(height: 8),
              const Text(
                'Showing cached data if available.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile body ──────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final User user;
  final Future<void> Function(String name) onUpdateName;

  const _ProfileBody({required this.user, required this.onUpdateName});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundImage: NetworkImage(user.avatarUrl),
          ),
        ),
        const SizedBox(height: 24),
        _InfoTile(label: 'Name',  value: user.name),
        _InfoTile(label: 'Email', value: user.email),
        _InfoTile(label: 'ID',    value: '#${user.id}'),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => _showEditDialog(context),
          child: const Text('Edit Display Name'),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdateName(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label,
              style: const TextStyle(color: Colors.grey))),
          const SizedBox(width: 16),
          Expanded(child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
