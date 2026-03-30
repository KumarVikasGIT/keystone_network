import 'package:dio/dio.dart';
import '../widgets/api_state_widget.dart';
import 'error_handler.dart';
import 'failure_response.dart';

/// Page-number or cursor-based pagination with built-in state management.
///
/// Eliminates the 50-80 lines of boilerplate needed per list screen
/// (page counter, hasMore flag, loading state, append logic).
///
/// ## Page-number pagination
/// ```dart
/// final paginator = ApiPaginator<Gallery, ApiError>(
///   request: (page) => dio.get('/galleries', queryParameters: {'page': page}),
///   parser:  (json) => Gallery.fromJson(json),
///   pageSize: 20,
/// );
///
/// await paginator.loadFirst();
/// await paginator.loadNext(); // call on scroll end
///
/// paginator.items        // List<Gallery>
/// paginator.hasMore      // bool
/// paginator.isLoading    // bool
/// paginator.currentPage  // int
/// paginator.state        // ApiState<List<Gallery>, ApiError>
/// ```
///
/// ## Cursor-based pagination (e.g. Strapi v5)
/// ```dart
/// final paginator = ApiPaginator<Photo, ApiError>.cursor(
///   request: (cursor) => dio.get('/photos',
///     queryParameters: cursor != null ? {'cursor': cursor} : {}),
///   parser:  (json) => Photo.fromJson(json),
///   cursorExtractor: (response) => response['meta']['nextCursor'] as String?,
/// );
/// ```
///
/// ## Flutter widget integration
/// ```dart
/// // Rebuild on state changes by listening to the stream
/// paginator.stream.listen((_) => setState(() {}));
///
/// // Or use PaginatedListView
/// PaginatedListView(
///   paginator: _paginator,
///   itemBuilder: (ctx, item) => GalleryCard(item),
///   loadingBuilder: () => const GalleryShimmer(),
///   emptyBuilder:   () => const EmptyGalleries(),
/// )
/// ```
class ApiPaginator<T, E> {
  // ── Config ──────────────────────────────────────────────────────────────

  final Future<Response> Function(int page)? _pageRequest;
  final Future<Response> Function(String? cursor)? _cursorRequest;
  final T Function(dynamic json) _parser;
  final List<T> Function(dynamic json)? _listParser;
  final String? Function(dynamic responseData)? _cursorExtractor;
  final E Function(Map<String, dynamic>)? _errorParser;
  final int pageSize;

  /// Whether to reset items on [loadFirst] (default: true)
  final bool resetOnRefresh;

  // ── State ───────────────────────────────────────────────────────────────

  final List<T> _items = [];
  int _currentPage = 1;
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoading = false;
  ApiState<List<T>, E> _state = const ApiState.idle();

  final _listeners = <void Function()>[];

  // ── Constructors ─────────────────────────────────────────────────────────

  /// Page-number pagination.
  ///
  /// [request] receives the 1-based page number.
  /// [parser] parses a single item from a JSON element.
  /// [listParser] parses the whole list; defaults to
  /// `(json) => (json as List).map(parser).toList()`.
  ApiPaginator({
    required Future<Response> Function(int page) request,
    required T Function(dynamic json) parser,
    List<T> Function(dynamic json)? listParser,
    E Function(Map<String, dynamic>)? errorParser,
    this.pageSize = 20,
    this.resetOnRefresh = true,
  })  : _pageRequest = request,
        _cursorRequest = null,
        _parser = parser,
        _listParser = listParser,
        _cursorExtractor = null,
        _errorParser = errorParser;

  /// Cursor-based pagination.
  ///
  /// [request] receives null for the first page, then the cursor string.
  /// [cursorExtractor] pulls the next-cursor from the raw response data.
  ApiPaginator.cursor({
    required Future<Response> Function(String? cursor) request,
    required T Function(dynamic json) parser,
    required String? Function(dynamic responseData) cursorExtractor,
    List<T> Function(dynamic json)? listParser,
    E Function(Map<String, dynamic>)? errorParser,
    this.pageSize = 20,
    this.resetOnRefresh = true,
  })  : _pageRequest = null,
        _cursorRequest = request,
        _parser = parser,
        _listParser = listParser,
        _cursorExtractor = cursorExtractor,
        _errorParser = errorParser;

  // ── Public accessors ─────────────────────────────────────────────────────

  List<T> get items        => List.unmodifiable(_items);
  int  get currentPage     => _currentPage;
  bool get hasMore         => _hasMore;
  bool get isLoading       => _isLoading;
  bool get isEmpty         => _items.isEmpty;
  ApiState<List<T>, E> get state => _state;

  // ── Public actions ────────────────────────────────────────────────────────

  /// Load the first page (or refresh).
  Future<void> loadFirst() async {
    if (_isLoading) return;

    if (resetOnRefresh) {
      _items.clear();
      _currentPage = 1;
      _nextCursor = null;
      _hasMore = true;
    }

    await _load();
  }

  /// Load the next page. No-op if already loading or no more pages.
  Future<void> loadNext() async {
    if (_isLoading || !_hasMore) return;
    await _load();
  }

  /// Reset paginator to initial state without triggering a network request.
  void reset() {
    _items.clear();
    _currentPage = 1;
    _nextCursor = null;
    _hasMore = true;
    _isLoading = false;
    _setState(const ApiState.idle());
  }

  // ── State change listener ─────────────────────────────────────────────────

  /// Register a callback that fires on every state change.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Remove a previously registered listener.
  void removeListener(void Function() listener) => _listeners.remove(listener);

  // ── Private helpers ──────────────────────────────────────────────────────

  Future<void> _load() async {
    _isLoading = true;
    _setState(const ApiState.loading());

    try {
      final response = _pageRequest != null
          ? await _pageRequest(_currentPage)
          : await _cursorRequest!(_nextCursor);

      final newItems = _parseList(response.data);

      _items.addAll(newItems);

      // Update cursor or page counter
      if (_cursorExtractor != null) {
        _nextCursor = _cursorExtractor(response.data);
        _hasMore = _nextCursor != null;
      } else {
        _hasMore = newItems.length >= pageSize;
        if (_hasMore) _currentPage++;
      }

      _isLoading = false;

      if (_items.isEmpty) {
        _setState(const ApiState.empty());
      } else {
        _setState(ApiState.success(List<T>.from(_items)));
      }
    } catch (error) {
      _isLoading = false;

      final handler =
      ErrorHandler<E>.handle(error, parseError: _errorParser);
      final failure = handler.failure;

      if (failure.isNetworkError) {
        _setState(ApiState.networkError(failure));
      } else {
        _setState(ApiState.failed(failure));
      }
    }
  }

  List<T> _parseList(dynamic data) {
    if (_listParser != null) return _listParser(data);
    if (data is List) return data.map(_parser).toList();
    throw FormatException(
      'ApiPaginator: response data is not a List and no listParser was provided. '
          'Pass a listParser to handle custom response shapes.',
    );
  }

  void _setState(ApiState<List<T>, E> newState) {
    _state = newState;
    for (final l in _listeners) {
      l();
    }
  }
}