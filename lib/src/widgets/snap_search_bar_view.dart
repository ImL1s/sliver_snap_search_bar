import 'package:flutter/material.dart';

import '../sliver_snap_constants.dart';
import '../sliver_snap_controller.dart';
import '../sliver_snap_search_delegate.dart';

/// A higher-level convenience widget that builds a [CustomScrollView]
/// with a scroll-hide + magnetic-snap search bar wired up end to end.
///
/// Use when you just want the behavior without writing the gesture
/// plumbing yourself. For any non-trivial integration (custom
/// scroll physics, additional slivers above the search bar, multi-tab
/// search content, etc.) compose the primitives directly instead:
///
/// * [SliverSnapSearchBarDelegate] — the rendering primitive.
/// * [SnapSearchBarController] — the gesture + offset-restore helper.
///
/// ### Example
///
/// ```dart
/// SnapSearchBarView(
///   searchBar: DefaultSnapSearchBarRow(
///     isSearching: _isSearching,
///     controller: _textCtrl,
///     focusNode: _focus,
///     onTap: _enterSearch,
///     onBack: _exitSearch,
///   ),
///   isSearching: _isSearching,
///   slivers: [
///     SliverList.list(children: [for (int i = 0; i < 50; i++) ListTile(title: Text('#$i'))]),
///   ],
///   searchResultSliver: _isSearching
///       ? SliverFillRemaining(child: MySearchResults())
///       : null,
/// )
/// ```
class SnapSearchBarView extends StatefulWidget {
  const SnapSearchBarView({
    super.key,
    required this.isSearching,
    this.searchBar,
    this.searchBarBuilder,
    required this.slivers,
    this.searchResultSliver,
    this.divider,
    this.scrollController,
    this.physics,
    this.totalHeight = kDefaultSearchBarTotalHeight,
    this.contentHeight = kDefaultSearchBarContentHeight,
    this.verticalPadding = kDefaultSearchBarVerticalPadding,
    this.horizontalPadding = 16.0,
    this.snapDuration = kDefaultSnapDuration,
    this.snapCurve = Curves.easeOutCubic,
    this.earlyReturnRatio = kDefaultEarlyReturnRatio,
    this.backgroundColor,
    this.isDisabled = false,
  }) : assert(
         (searchBar == null) != (searchBarBuilder == null),
         'Provide exactly one of searchBar or searchBarBuilder.',
       );

  /// Whether the host is in search mode. When `true`, the sliver header
  /// becomes pinned at full height and the list is replaced by
  /// [searchResultSliver] (if provided).
  final bool isSearching;

  /// The inner content of the search bar. Typically
  /// `DefaultSnapSearchBarRow(...)` or your own custom row reading
  /// [SliverSnapScope.of] for the current opacity.
  ///
  /// Exactly one of [searchBar] or [searchBarBuilder] must be provided.
  final Widget? searchBar;

  /// Builder alternative to [searchBar] for callers that need access to
  /// the per-frame `contentOpacity` value. The builder receives the
  /// current [BuildContext] and the `contentOpacity` in `[0, 1]`.
  ///
  /// Exactly one of [searchBar] or [searchBarBuilder] must be provided.
  final Widget Function(BuildContext context, double contentOpacity)?
  searchBarBuilder;

  /// The list / content slivers displayed below the search bar when
  /// not in search mode.
  final List<Widget> slivers;

  /// Optional sliver to replace [slivers] when `isSearching` is
  /// `true`. Typically a `SliverFillRemaining` containing your search
  /// results view. If `null`, [slivers] are kept during search mode.
  final Widget? searchResultSliver;

  /// Optional divider widget inserted between the search bar sliver and
  /// the content [slivers]. When non-null, it is wrapped in a
  /// [SliverToBoxAdapter] and placed at index 1 of the
  /// [CustomScrollView] slivers list.
  final Widget? divider;

  /// Optional external scroll controller. If `null`, an internal one
  /// is created and disposed with the widget.
  final ScrollController? scrollController;

  /// Optional scroll physics. Defaults to the platform default.
  final ScrollPhysics? physics;

  /// Full outer height of the search bar. See
  /// [kDefaultSearchBarTotalHeight].
  final double totalHeight;

  /// Content height (pill). See [kDefaultSearchBarContentHeight].
  final double contentHeight;

  /// Vertical padding around the content. See
  /// [kDefaultSearchBarVerticalPadding].
  final double verticalPadding;

  /// Horizontal padding around the content.
  final double horizontalPadding;

  /// Duration of the magnetic snap animation.
  final Duration snapDuration;

  /// Curve of the magnetic snap animation.
  final Curve snapCurve;

  /// Ratio below which the bar renders as an empty `SizedBox`. See
  /// [kDefaultEarlyReturnRatio].
  final double earlyReturnRatio;

  /// Optional background color of the bar's outer shell. `null` for
  /// transparent.
  final Color? backgroundColor;

  /// Whether the bar should render in a visually disabled state.
  final bool isDisabled;

  @override
  State<SnapSearchBarView> createState() => _SnapSearchBarViewState();
}

class _SnapSearchBarViewState extends State<SnapSearchBarView> {
  late ScrollController _scrollCtrl;
  late SnapSearchBarController _snapCtrl;
  bool _ownsScrollCtrl = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = widget.scrollController ?? ScrollController();
    _ownsScrollCtrl = widget.scrollController == null;
    _snapCtrl = SnapSearchBarController(
      scrollController: _scrollCtrl,
      totalHeight: widget.totalHeight,
      snapDuration: widget.snapDuration,
      snapCurve: widget.snapCurve,
    );
  }

  @override
  void didUpdateWidget(covariant SnapSearchBarView old) {
    super.didUpdateWidget(old);

    final scrollChanged = old.scrollController != widget.scrollController;
    // Any caller-facing snap config delta must propagate to the
    // controller or the snap target math desyncs from the rendered
    // bar height — a silent UX bug. See Codex #2.
    final configChanged =
        old.totalHeight != widget.totalHeight ||
        old.snapDuration != widget.snapDuration ||
        old.snapCurve != widget.snapCurve;

    if (scrollChanged) {
      if (_ownsScrollCtrl) _scrollCtrl.dispose();
      _scrollCtrl = widget.scrollController ?? ScrollController();
      _ownsScrollCtrl = widget.scrollController == null;
    }

    if (scrollChanged || configChanged) {
      _snapCtrl.dispose();
      _snapCtrl = SnapSearchBarController(
        scrollController: _scrollCtrl,
        totalHeight: widget.totalHeight,
        snapDuration: widget.snapDuration,
        snapCurve: widget.snapCurve,
      );
    }

    // Enter search mode → save offset + jump to 0 on next frame so the
    // pinned bar anchors at full height. Exit search mode → restore.
    if (old.isSearching != widget.isSearching) {
      if (widget.isSearching) {
        _snapCtrl.savePreSearchOffset();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollCtrl.hasClients) return;
          if (_scrollCtrl.offset != 0) _scrollCtrl.jumpTo(0);
        });
      } else {
        _snapCtrl.restorePreSearchOffset();
      }
    }
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    if (_ownsScrollCtrl) _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (_) => _snapCtrl.maybeSnapOnPointerUp(),
      onPointerCancel: (_) => _snapCtrl.maybeSnapOnPointerUp(),
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: widget.physics,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: SliverSnapSearchBarDelegate(
              isSearching: widget.isSearching,
              isDisabled: widget.isDisabled,
              totalHeight: widget.totalHeight,
              contentHeight: widget.contentHeight,
              verticalPadding: widget.verticalPadding,
              horizontalPadding: widget.horizontalPadding,
              backgroundColor: widget.backgroundColor,
              earlyReturnRatio: widget.earlyReturnRatio,
              // Exactly one of searchBar / searchBarBuilder is set
              // (enforced by the widget-level assert).
              child: widget.searchBar,
              builder: widget.searchBarBuilder,
            ),
          ),
          if (widget.divider != null)
            SliverToBoxAdapter(child: widget.divider!),
          if (widget.isSearching && widget.searchResultSliver != null)
            widget.searchResultSliver!
          else
            ...widget.slivers,
        ],
      ),
    );
  }
}
