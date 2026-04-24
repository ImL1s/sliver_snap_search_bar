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
    this.pinnedDividerHeight,
    this.pinnedDividerColor,
    this.child,
    this.builder,
  }) : assert(
         child != null || builder != null,
         'Either child or builder must be provided',
       ),
       assert(
         child == null || builder == null,
         'Cannot pass both child and builder',
       ),
       assert(
         (totalHeight - (contentHeight + 2 * verticalPadding)).abs() < 0.01,
         'totalHeight must equal contentHeight + 2 * verticalPadding '
         '(got totalHeight=$totalHeight, contentHeight=$contentHeight, '
         'verticalPadding=$verticalPadding).',
       ),
       assert(
         pinnedDividerHeight == null || pinnedDividerColor != null,
         'pinnedDividerColor is required when pinnedDividerHeight is non-null.',
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

  /// Height of a divider rendered pinned at the bottom of the delegate
  /// output. When non-null, [minExtent] becomes this height (not 0) so
  /// the divider stays visible even when the search bar body is fully
  /// compressed — matching Telegram iOS's 1 px bottom border under the
  /// navbar.
  ///
  /// Use `pinnedDividerHeight` + [pinnedDividerColor] for the TG iOS
  /// navbar-line behavior. Use `SliverSnapView.divider` instead when
  /// you want a scroll-away separator below the header.
  ///
  /// Leave `null` (default) for v0.2.0-compatible behavior where
  /// `minExtent = 0` and no divider is rendered inside the delegate.
  final double? pinnedDividerHeight;

  /// Color of the pinned divider. Required when [pinnedDividerHeight]
  /// is non-null (enforced by a constructor assert); ignored otherwise.
  final Color? pinnedDividerColor;

  /// Static inner content. Exactly one of [child] or [builder] must be
  /// provided.
  final Widget? child;

  /// Builder that receives the current `contentOpacity`. Use this when
  /// you need the fade to be applied by your own widget (e.g. you want
  /// to combine it with another opacity source).
  final Widget Function(BuildContext context, double contentOpacity)? builder;

  @override
  double get minExtent {
    if (isSearching) return maxExtent;
    return pinnedDividerHeight ?? 0.0;
  }

  @override
  double get maxExtent => totalHeight + (pinnedDividerHeight ?? 0.0);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // progress denominator stays totalHeight even when pinnedDividerHeight
    // widens maxExtent — the divider does NOT participate in compression,
    // so the search bar body still fades over its original range.
    final progress = (shrinkOffset / totalHeight).clamp(0.0, 1.0);
    final ratio = isSearching ? 1.0 : (1.0 - progress);
    final contentOpacity = isSearching
        ? 1.0
        : (1.0 - (progress * 2).clamp(0.0, 1.0));
    final expectedH = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);

    if (ratio < earlyReturnRatio) {
      // Use totalHeight (not contentHeight) so the compressed bare
      // SizedBox continues the same total-height curve as the padded
      // branch above, avoiding a pixel jump on the threshold frame.
      if (pinnedDividerHeight != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.shrink(),
            Container(
              height: pinnedDividerHeight,
              color: pinnedDividerColor,
            ),
          ],
        );
      }
      return SizedBox(height: expectedH);
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

    final content = pinnedDividerHeight == null
        ? body
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              body,
              Container(
                height: pinnedDividerHeight,
                color: pinnedDividerColor,
              ),
            ],
          );

    return SizedBox(
      height: expectedH,
      child: ClipRect(
        child: _SnapSearchBarScope(
          progress: progress,
          contentOpacity: contentOpacity,
          isDisabled: isDisabled,
          child: content,
        ),
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
        pinnedDividerHeight != oldDelegate.pinnedDividerHeight ||
        pinnedDividerColor != oldDelegate.pinnedDividerColor ||
        // Mode change: child <-> builder. Callers frequently rebuild the
        // widget instance every frame (e.g. ValueListenableBuilder), so
        // we deliberately do NOT compare `child` / `builder` by identity
        // — only detect the API mode flip by nullness.
        (child == null) != (oldDelegate.child == null);
  }
}

/// An [InheritedWidget] scope that publishes the current scroll
/// progress, content opacity, and disabled state down to descendants
/// (e.g. a [DefaultSliverSnapRow]). Read via
/// [SliverSnapScope.of] / [SliverSnapScope.maybeOf].
class _SnapSearchBarScope extends InheritedWidget {
  const _SnapSearchBarScope({
    required this.progress,
    required this.contentOpacity,
    required this.isDisabled,
    required super.child,
  });

  final double progress;
  final double contentOpacity;
  final bool isDisabled;

  @override
  bool updateShouldNotify(covariant _SnapSearchBarScope oldWidget) {
    return progress != oldWidget.progress ||
        contentOpacity != oldWidget.contentOpacity ||
        isDisabled != oldWidget.isDisabled;
  }
}

/// Public accessor for the [_SnapSearchBarScope] inherited from an
/// ancestor [SliverSnapSearchBarDelegate.build].
///
/// Custom search bar rows can read [SliverSnapScope.of] to apply the
/// current opacity or react to raw scroll [progress] (0 = fully
/// expanded, 1 = fully collapsed) for non-linear effects such as icon
/// rotation or parallax.
class SliverSnapScope {
  const SliverSnapScope._({
    required this.progress,
    required this.contentOpacity,
    required this.isDisabled,
  });

  /// Raw compression ratio in the range `[0, 1]`.
  /// `0` = bar fully expanded; `1` = bar fully collapsed.
  /// Equals `shrinkOffset / totalHeight` clamped to `[0, 1]`.
  final double progress;

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
      progress: inherited.progress,
      contentOpacity: inherited.contentOpacity,
      isDisabled: inherited.isDisabled,
    );
  }
}
