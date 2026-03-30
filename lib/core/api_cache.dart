import 'dart:convert';
import 'dart:collection';

// ── Cache policy ─────────────────────────────────────────────────────────────

/// Controls how [ApiExecutor.execute] interacts with the cache.
enum CachePolicy {
  /// Try the network first; fall back to cache on failure.
  /// Default – always tries to return fresh data.
  networkFirst,

  /// Return cache immediately, then refresh in background.
  /// Best for perceived performance on list screens.
  cacheFirst,

  /// Return cache only; never hit the network.
  /// Use for offline mode.
  cacheOnly,

  /// Always hit the network; never read or write cache.
  /// Use for real-time data.
  networkOnly,

  /// Return cached data immediately AND emit fresh network data once available.
  /// Best UX for list screens (instant render + background refresh).
  cacheAndNetwork,
}

// ── Cache config ─────────────────────────────────────────────────────────────

/// Cache configuration for a single [ApiExecutor.execute] call.
///
/// Example:
/// ```dart
/// final result = await ApiExecutor.execute<List<Gallery>>(
///   request: () => dio.get('/galleries'),
///   parser:  (json) => (json as List).map(Gallery.fromJson).toList(),
///   cache: CacheConfig(
///     policy:   CachePolicy.networkFirst,
///     key:      'user_galleries',
///     duration: Duration(minutes: 5),
///   ),
/// );
/// ```
class CacheConfig {
  /// Cache key (required – must be unique per logical resource)
  final String key;

  /// How long the cached value is considered fresh
  final Duration duration;

  /// Which policy to use (default: [CachePolicy.networkFirst])
  final CachePolicy policy;

  const CacheConfig({
    required this.key,
    required this.duration,
    this.policy = CachePolicy.networkFirst,
  });
}

// ── Cache storage interface ───────────────────────────────────────────────────

/// Storage backend for the cache layer.
///
/// Default implementation is [InMemoryCacheStorage] (no dependencies).
///
/// Swap in your own for persistent storage:
/// ```dart
/// class HiveCacheStorage implements CacheStorage {
///   @override Future<String?> get(String key) async => Hive.box('cache').get(key);
///   @override Future<void>    set(String key, String value, Duration ttl) async {
///     await Hive.box('cache').put(key, value);
///     // store expiry separately, etc.
///   }
///   @override Future<void> delete(String key) => Hive.box('cache').delete(key);
///   @override Future<void> clear()            => Hive.box('cache').clear();
/// }
///
/// ApiCache.storage = HiveCacheStorage();
/// ```
abstract class CacheStorage {
  /// Retrieve a previously stored value, or null if missing / expired.
  Future<String?> get(String key);

  /// Store [value] under [key] with the given TTL.
  Future<void> set(String key, String value, Duration ttl);

  /// Delete a single entry.
  Future<void> delete(String key);

  /// Wipe the entire cache.
  Future<void> clear();

  /// Return all keys (used by pattern-based invalidation).
  Future<List<String>> keys();
}

// ── In-memory implementation ──────────────────────────────────────────────────

class _CacheEntry {
  final String value;
  final DateTime expiresAt;

  _CacheEntry(this.value, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Default in-memory cache storage.
///
/// Data is lost on app restart. Swap for a persistent implementation if needed.
class InMemoryCacheStorage implements CacheStorage {
  final _store = LinkedHashMap<String, _CacheEntry>();

  @override
  Future<String?> get(String key) async {
    final entry = _store[key];
    if (entry == null || entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  @override
  Future<void> set(String key, String value, Duration ttl) async {
    _store[key] = _CacheEntry(value, ttl);
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<List<String>> keys() async => _store.keys.toList();
}

// ── ApiCache facade ───────────────────────────────────────────────────────────

/// Global cache management facade.
///
/// Use this to invalidate entries or replace the storage backend.
///
/// ```dart
/// // Replace with persistent storage once at startup
/// ApiCache.storage = HiveCacheStorage();
///
/// // Invalidate a single entry
/// await ApiCache.invalidate('user_galleries');
///
/// // Invalidate by prefix pattern
/// await ApiCache.invalidatePattern('gallery_');
///
/// // Wipe everything
/// await ApiCache.clear();
/// ```
class ApiCache {
  /// Active storage backend. Defaults to [InMemoryCacheStorage].
  /// Replace early in app startup to persist across restarts.
  static CacheStorage storage = InMemoryCacheStorage();

  ApiCache._();

  /// Store serialised data under [key].
  static Future<void> set(String key, dynamic data, Duration ttl) async {
    final json = jsonEncode(data);
    await storage.set(key, json, ttl);
  }

  /// Retrieve and decode data for [key], or null if missing/expired.
  static Future<dynamic> get(String key) async {
    final raw = await storage.get(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  /// Delete a single cache entry.
  static Future<void> invalidate(String key) => storage.delete(key);

  /// Delete all entries whose keys start with [prefix].
  ///
  /// ```dart
  /// await ApiCache.invalidatePattern('gallery_');
  /// // removes gallery_1, gallery_2, gallery_list, etc.
  /// ```
  static Future<void> invalidatePattern(String prefix) async {
    final allKeys = await storage.keys();
    for (final k in allKeys.where((k) => k.startsWith(prefix))) {
      await storage.delete(k);
    }
  }

  /// Clear the entire cache.
  static Future<void> clear() => storage.clear();
}