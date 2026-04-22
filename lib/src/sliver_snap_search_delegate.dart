import 'package:flutter/material.dart';

import 'sliver_snap_constants.dart';

/// A [SliverPersistentHeaderDelegate] that renders a search bar which
/// compresses and disappears as the user scrolls up, then re-expands as
/// the user scrolls back to the top — aligned to Telegram iOS behavior.
///
/// Use with `SliverPersistentHeader(pinned: true)`. The sticky behavior
/// is achieved via dynamic [minExtent]:
///
/// * When `isSearching` is `false` — `minExtent = 0` and the bar is
///   compressed to zero height as the user scrolls up, then restored as
///   they scroll back down.
/// * When `isSearching` is `true` — `minExtent = maxExtent` so the bar
///   stays fully visible regardless of scroll position. Pair this with
///   a `ScrollController.jumpTo(0)` on your host state when entering the
///   search mode.
///
/// ```dart
/// SliverPersistentHeader(
///   pinned: true,
///   delegate: SliverSnapSearchBarDelegate(
///     isSearching: isSearching,
///     child: MySearchBarRow(),
///   ),
/// );
/// ```
///
/// ### Dual-track fade
///
/// The delegate renders two independent fades:
/// 1. **Outer shell** — the optional [backgroundColor] container shrinks
///    via a `SizedBox` whose height is linearly scaled with the `ratio
///    = 1 - shrinkOffset / totalHeight`.
/// 2. **Inner content** — a `contentOpacity` is passed down via
///    `_SnapSearchBarScope`, defined as
///    `1.0 - clamp(progress * 2, 0, 1)`. Content fades twice as fast,
///    matching Telegram's "icon/text disappear first, then the pill
///    flattens".
///
/// ### Custom content via [builder]
///
/// If you need finer control (e.g. your own animated icon, custom
/// keyboard focus handling), pass a [builder] instead of [child]. The
/// builder receives the current `contentOpacity` as computed above and
/// is responsible for applying it.
///
/// ### Early return
///
/// When the compressed `ratio` falls below [earlyReturnRatio], the
/// delegate returns a bare `SizedBox` sized to the remaining height
/// instead of rendering the row. This avoids `TextField` intrinsic
/// height calculations overflowing at sub-pixel sizes. Default 0.1.
///
/// ### shouldRebuild
///
/// `shouldRebuild` compares only structural fields (isSearching,
/// isDisabled, totalHeight, padding, colours, thresholds). **It does not
/// compare widget instances by identity** — if your caller creates a new
/// `child` every frame (common when wrapping in `ValueListenableBuilder`),
/// element-level diffing in the widget tree handles the update without
/// forcing the delegate itself to rebuild every frame.
///
/// The one exception is a mode flip between [child] and [builder]: if the
/// caller swaps the two APIs, the delegate must rebuild so the correct
/// subtree takes over; this is detected via a nullness comparison on
/// [child], not instance identity.
class SliverSnapSearchBarDelegate extends SliverPersistentHeaderDelegate {
  SliverSnapSearchBarDelegate({
    required this.isSearching,
    this.isDisabled = false,
    this.totalHeight = kDefaultSearchBarTotalHeight,
    this.contentHeight = kDefaultSearchBarContentHeight,
    this.verticalPadding = kDefaultSearchBarVerticalPadding,
    this.horizontalPadding = 16.0,
    this.backgroundColor,
    this.earlyReturnRatio = kDefaultEarlyReturnRatio,
    this.child,
    this.builder,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       ),
       assert(
         child == null || builder == null,
         'Cannot pass both child and builder',
       );

  /// Whether the host is in search mode. When `true`, [minExtent] equals
  /// [maxExtent] so the bar stays fully visible.
  final bool isSearching;

  /// Whether the search bar should render in a visually disabled state.
  /// Passes the default disabled opacity to the content builder.
  final bool isDisabled;

  /// Total outer height of the bar (content + vertical padding on both
  /// sides). Must equal `contentHeight + verticalPadding * 2` for
  /// consistent rendering; the delegate asserts this in debug.
  final double totalHeight;

  /// Inner content height (just the pill / row), without padding.
  final double contentHeight;

  /// Vertical padding applied around the content on each side.
  final double verticalPadding;

  /// Horizontal padding applied around the content.
  final double horizontalPadding;

  /// Optional background color for the outer shell (covering the padded
  /// region). Leave `null` for a transparent bar that inherits the
  /// surrounding surface.
  final Color? backgroundColor;

  /// Threshold below which the bar renders as an empty `SizedBox`
  /// instead of the content. See [kDefaultEarlyReturnRatio].
  final double earlyReturnRatio;

  /// Static inner content. Exactly one of [child] or [builder] must be
  /// provided.
  final Widget? child;

  /// Builder that receives the current `contentOpacity`. Use this when
  /// you need the fade to be applied by your own widget (e.g. you want
  /// to combine it with another opacity source).
  final Widget Function(BuildContext context, double contentOpacity)? builder;

  @override
  double get minExtent => isSearching ? totalHeight : 0.0;

  @override
  double get maxExtent => totalHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / totalHeight).clamp(0.0, 1.0);
    final ratio = isSearching ? 1.0 : (1.0 - progress);
    final contentOpacity = isSearching
        ? 1.0
        : (1.0 - (progress * 2).clamp(0.0, 1.0));

    if (ratio < earlyReturnRatio) {
      // Use totalHeight (not contentHeight) so the compressed bare
      // SizedBox continues the same total-height curve as the padded
      // branch above, avoiding a pixel jump on the threshold frame.
      return SizedBox(height: totalHeight * ratio);
    }

    final inner = builder != null ? builder!(context, contentOpacity) : child!;

    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding * ratio,
      ),
      child: SizedBox(height: contentHeight * ratio, child: inner),
    );

    final body = backgroundColor == null
        ? padded
        : ColoredBox(color: backgroundColor!, child: padded);

    return ClipRect(
      child: _SnapSearchBarScope(
        contentOpacity: contentOpacity,
        isDisabled: isDisabled,
        child: body,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverSnapSearchBarDelegate oldDelegate) {
    return isSearching != oldDelegate.isSearching ||
        isDisabled != oldDelegate.isDisabled ||
        totalHeight != oldDelegate.totalHeight ||
        contentHeight != oldDelegate.contentHeight ||
        verticalPadding != oldDelegate.verticalPadding ||
        horizontalPadding != oldDelegate.horizontalPadding ||
        backgroundColor != oldDelegate.backgroundColor ||
        earlyReturnRatio != oldDelegate.earlyReturnRatio ||
        // Mode change: child <-> builder. Callers frequently rebuild the
        // widget instance every frame (e.g. ValueListenableBuilder), so
        // we deliberately do NOT compare `child` / `builder` by identity
        // — only detect the API mode flip by nullness.
        (child == null) != (oldDelegate.child == null);
  }
}

/// An [InheritedWidget] scope that publishes the current content
/// opacity and disabled state down to descendants (e.g. a
/// [DefaultSnapSearchBarRow]). Read via
/// [SliverSnapScope.of] / [SliverSnapScope.maybeOf].
class _SnapSearchBarScope extends InheritedWidget {
  const _SnapSearchBarScope({
    required this.contentOpacity,
    required this.isDisabled,
    required super.child,
  });

  final double contentOpacity;
  final bool isDisabled;

  @override
  bool updateShouldNotify(covariant _SnapSearchBarScope oldWidget) {
    return contentOpacity != oldWidget.contentOpacity ||
        isDisabled != oldWidget.isDisabled;
  }
}

/// Public accessor for the [_SnapSearchBarScope] inherited from an
/// ancestor [SliverSnapSearchBarDelegate.build].
///
/// Custom search bar rows can read [SliverSnapScope.of] to apply the
/// current opacity to their own painting.
class SliverSnapScope {
  const SliverSnapScope._({
    required this.contentOpacity,
    required this.isDisabled,
  });

  final double contentOpacity;
  final bool isDisabled;

  static SliverSnapScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'SliverSnapScope.of() called with no ancestor; the widget must be a '
      'descendant of a SliverSnapSearchBarDelegate.build output.',
    );
    return scope!;
  }

  static SliverSnapScope? maybeOf(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_SnapSearchBarScope>();
    if (inherited == null) return null;
    return SliverSnapScope._(
      contentOpacity: inherited.contentOpacity,
      isDisabled: inherited.isDisabled,
    );
  }
}
