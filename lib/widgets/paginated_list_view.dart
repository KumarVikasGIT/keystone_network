import 'package:flutter/material.dart';
import '../core/api_paginator.dart';
import 'api_state_widget.dart';

/// A drop-in [ListView] that handles pagination automatically.
///
/// Attach it to an [ApiPaginator] and it will:
/// - Render items with [itemBuilder]
/// - Show a shimmer / loading indicator while the first page loads
/// - Show an empty view when there are no results
/// - Append a per-page loader at the bottom while fetching the next page
/// - Trigger [paginator.loadNext()] when the user scrolls near the end
///
/// Example:
/// ```dart
/// PaginatedListView<Gallery, ApiError>(
///   paginator: _paginator,
///   itemBuilder:    (ctx, item) => GalleryCard(item),
///   loadingBuilder: () => const GalleryShimmer(),
///   emptyBuilder:   () => const EmptyGalleries(),
///   errorBuilder:   (msg) => ErrorView(msg, onRetry: _paginator.loadFirst),
/// )
/// ```
class PaginatedListView<T, E> extends StatefulWidget {
  final ApiPaginator<T, E> paginator;

  /// Called for each item in the list
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Shown while the very first page is loading
  final Widget Function()? loadingBuilder;

  /// Shown when the list is empty after a successful load
  final Widget Function()? emptyBuilder;

  /// Shown when an error occurs
  final Widget Function(String message)? errorBuilder;

  /// Shown as a footer while subsequent pages are loading
  final Widget Function()? pageLoadingBuilder;

  /// Fraction of the scroll extent that triggers loadNext (default: 0.9 = 90%)
  final double loadMoreThreshold;

  /// Physics for the inner [ListView]
  final ScrollPhysics? physics;

  /// Padding for the inner [ListView]
  final EdgeInsetsGeometry? padding;

  /// Scroll controller (optional; one is created internally if omitted)
  final ScrollController? scrollController;

  /// Separator widget between items (uses [ListView.separated] when provided)
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  const PaginatedListView({
    super.key,
    required this.paginator,
    required this.itemBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.pageLoadingBuilder,
    this.loadMoreThreshold = 0.9,
    this.physics,
    this.padding,
    this.scrollController,
    this.separatorBuilder,
  });

  @override
  State<PaginatedListView<T, E>> createState() =>
      _PaginatedListViewState<T, E>();
}

class _PaginatedListViewState<T, E>
    extends State<PaginatedListView<T, E>> {
  late final ScrollController _scrollController;
  bool _ownsScrollController = false;

  @override
  void initState() {
    super.initState();

    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }

    _scrollController.addListener(_onScroll);
    widget.paginator.addListener(_onPaginatorChange);

    // Kick off first load if paginator is idle
    if (widget.paginator.state.isIdle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.paginator.loadFirst();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    widget.paginator.removeListener(_onPaginatorChange);
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  void _onPaginatorChange() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * widget.loadMoreThreshold) {
      widget.paginator.loadNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginator = widget.paginator;
    final state = paginator.state;
    final items = paginator.items;

    // First-page loading
    if (state.isLoading && items.isEmpty) {
      return widget.loadingBuilder?.call() ??
          const Center(child: CircularProgressIndicator());
    }

    // Error with no items
    if (state.isError && items.isEmpty) {
      final msg = state.error?.message ?? 'Something went wrong.';
      return widget.errorBuilder?.call(msg) ??
          Center(child: Text(msg));
    }

    // Empty
    if (state.isEmpty || items.isEmpty) {
      return widget.emptyBuilder?.call() ??
          const Center(child: Text('No items found.'));
    }

    // Item count + optional footer loader
    final showFooter = paginator.isLoading && items.isNotEmpty;
    final itemCount = items.length + (showFooter ? 1 : 0);

    if (widget.separatorBuilder != null) {
      return ListView.separated(
        controller: _scrollController,
        physics: widget.physics,
        padding: widget.padding,
        itemCount: itemCount,
        separatorBuilder: (ctx, i) =>
        i < items.length - 1
            ? widget.separatorBuilder!(ctx, i)
            : const SizedBox.shrink(),
        itemBuilder: (ctx, i) => _buildItem(ctx, i, items, showFooter),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: widget.physics,
      padding: widget.padding,
      itemCount: itemCount,
      itemBuilder: (ctx, i) => _buildItem(ctx, i, items, showFooter),
    );
  }

  Widget _buildItem(
      BuildContext context,
      int index,
      List<T> items,
      bool showFooter,
      ) {
    if (showFooter && index == items.length) {
      return widget.pageLoadingBuilder?.call() ??
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
    }
    return widget.itemBuilder(context, items[index]);
  }
}