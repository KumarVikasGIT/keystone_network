// ============================================================================
//  example/lib/screens/gallery_screen.dart
//
//  Demonstrates:
//    • ApiPaginator (page-number pagination)
//    • PaginatedListView widget (auto scroll-to-load, shimmer, empty)
//    • CachePolicy.cacheAndNetwork (instant render + background refresh)
//    • ApiState.empty() rendered by PaginatedListView automatically
//
//  The paginator is created once and lives for the widget's lifetime.
//  Calling paginator.loadFirst() again acts as a pull-to-refresh.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:keystone_network/config/keystone_network.dart';
import 'package:keystone_network/keystone_network.dart';

import '../data/models.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {

  // ── Paginator setup ───────────────────────────────────────────────────────
  //
  // ApiPaginator<Gallery, ApiError> manages:
  //   • page counter
  //   • hasMore flag
  //   • item accumulation across pages
  //   • loading / empty / error state
  //
  // The cache config here uses cacheAndNetwork: the paginator will immediately
  // emit any cached galleries (so the screen is never blank on revisit) and
  // then silently refresh from the network in the background.

  late final ApiPaginator<Gallery, ApiError> _paginator = ApiPaginator(
    request: (page) => KeystoneNetwork.dio.get(
      '/galleries',
      queryParameters: {'page': page, 'per_page': 20},
    ),
    parser:   Gallery.fromJson,
    pageSize: 20,
  );

  @override
  void initState() {
    super.initState();

    // Listen for paginator state changes so we can call setState.
    // PaginatedListView does this internally — you only need addListener if
    // you're building a custom list widget.
    _paginator.addListener(_onStateChange);

    // Load the first page when the screen mounts.
    _paginator.loadFirst();
  }

  @override
  void dispose() {
    _paginator.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galleries'),
        actions: [
          // Manual refresh button — same as pull-to-refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _paginator.loadFirst,
          ),
        ],
      ),

      // ── PaginatedListView ─────────────────────────────────────────────────
      //
      // PaginatedListView handles:
      //   • First-page shimmer (loadingBuilder)
      //   • Empty state (emptyBuilder)
      //   • Error with retry (errorBuilder)
      //   • Per-page footer loader as user scrolls
      //   • Auto-calling paginator.loadNext() at 90% scroll depth

      body: RefreshIndicator(
        onRefresh: _paginator.loadFirst,
        child: PaginatedListView<Gallery, ApiError>(
          paginator: _paginator,

          itemBuilder: (ctx, gallery) => GalleryTile(gallery: gallery),

          loadingBuilder: () => const _GalleryShimmer(),

          emptyBuilder: () => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No galleries yet', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          errorBuilder: (message) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _paginator.loadFirst,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

          separatorBuilder: (_, __) => const Divider(height: 1),
          loadMoreThreshold: 0.85,  // trigger loadNext at 85% scroll depth
        ),
      ),
    );
  }
}

// ── Gallery list tile ─────────────────────────────────────────────────────

class GalleryTile extends StatelessWidget {
  final Gallery gallery;
  const GalleryTile({super.key, required this.gallery});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          gallery.thumbnailUrl,
          width: 56, height: 56, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 56),
        ),
      ),
      title:    Text(gallery.title),
      subtitle: Text('${gallery.photoCount} photos'),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

// ── Loading shimmer placeholder ───────────────────────────────────────────

class _GalleryShimmer extends StatelessWidget {
  const _GalleryShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => ListTile(
        leading: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Container(height: 14, width: 160, color: Colors.grey.shade300),
        subtitle: Container(height: 12, width: 80, color: Colors.grey.shade200),
      ),
    );
  }
}
