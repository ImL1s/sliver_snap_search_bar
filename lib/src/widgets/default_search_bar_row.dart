import 'package:flutter/material.dart';

import '../sliver_snap_constants.dart';
import '../sliver_snap_search_delegate.dart';

/// A batteries-included search-bar content row that works out of the
/// box with [SliverSnapSearchBarDelegate]. Reads [SliverSnapScope.of]
/// to apply the current content opacity, so scroll-hide fading "just
/// works" without extra wiring.
///
/// The row toggles between two layouts:
///
/// * **Inactive** (`isSearching == false`) — a pill-shaped tappable
///   surface with a centred search icon + placeholder text, like the
///   Telegram "Search" bar.
/// * **Active** (`isSearching == true`) — the icon and [TextField]
///   slide to left-aligned via `AnimatedAlign`, and a trailing cancel
///   button expands on the right via `AnimatedAlign(widthFactor)` +
///   `AnimatedOpacity`.
///
/// Both states sit inside the same pill container whose background
/// color is [pillColor]. The whole row fades via
/// `Opacity(contentOpacity)` so the icon/text disappear before the bar
/// flattens (see [SliverSnapSearchBarDelegate] dual-track fade).
///
/// For more elaborate needs (custom icons, assistant chip, multiple
/// trailing actions) skip this widget and build your own, reading
/// [SliverSnapScope.of] yourself.
class DefaultSnapSearchBarRow extends StatelessWidget {
  const DefaultSnapSearchBarRow({
    super.key,
    required this.isSearching,
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.onBack,
    this.trailing,
    this.hintText = 'Search',
    this.cancelText = 'Cancel',
    this.pillColor,
    this.pillCornerRadius = 100.0,
    this.pillDecoration,
    this.hintStyle,
    this.cancelStyle,
    this.cursorColor,
    this.searchIcon,
    this.clearIcon,
    this.animationDuration = const Duration(milliseconds: 300),
    this.cancelFadeDuration = const Duration(milliseconds: 400),
    this.animationCurve = Curves.decelerate,
  });

  /// Whether the host is in search mode. When `true`, the TextField is
  /// editable and the cancel button is visible.
  final bool isSearching;

  /// The text controller. Caller owns + disposes.
  final TextEditingController controller;

  /// Focus node for the [TextField]. Caller owns + disposes.
  final FocusNode focusNode;

  /// Callback when the user taps the bar in the inactive state.
  /// Typically toggles the host's search mode on.
  final VoidCallback onTap;

  /// Callback when the user taps the cancel button in the active
  /// state. Typically toggles the host's search mode off.
  final VoidCallback onBack;

  /// Optional trailing widget shown to the left of the cancel button
  /// when `isSearching == true` (e.g. an AI assistant chip).
  final Widget? trailing;

  /// Placeholder text shown in the inactive state and as the
  /// TextField hint in the active state. Default `"Search"`.
  final String hintText;

  /// Text of the cancel button shown in the active state. Default
  /// `"Cancel"`.
  final String cancelText;

  /// Background color of the pill container. Defaults to
  /// `Theme.of(context).colorScheme.surfaceContainerHighest` with a
  /// light alpha — fine for most themes but override if your design
  /// system has a specific search-bar token.
  final Color? pillColor;

  /// Corner radius of the pill. Default 100 (fully rounded).
  final double pillCornerRadius;

  /// Full [BoxDecoration] override for the pill container. Takes
  /// priority over [pillColor] + [pillCornerRadius] if provided. Use
  /// this for shadows, gradients, borders, or conditional focus rings.
  final Decoration? pillDecoration;

  /// Override for the hint [TextStyle] (inactive placeholder + TextField
  /// hint). Defaults to `theme.textTheme.bodyLarge` with secondary
  /// content color.
  final TextStyle? hintStyle;

  /// Override for the cancel-button [TextStyle]. Defaults to
  /// `theme.textTheme.bodyLarge` coloured `theme.colorScheme.primary`.
  final TextStyle? cancelStyle;

  /// Override for the [TextField] cursor colour.
  final Color? cursorColor;

  /// Optional custom search icon. Default a `Icons.search` with
  /// secondary content color.
  final Widget? searchIcon;

  /// Optional custom clear-text icon. Default `Icons.cancel` in
  /// secondary content color.
  final Widget? clearIcon;

  /// Duration of the icon/text alignment transition + cancel button
  /// width transition. Default 300ms.
  final Duration animationDuration;

  /// Duration of the cancel button opacity transition. Default 400ms
  /// (longer than width so the text fades in after space is made).
  final Duration cancelFadeDuration;

  /// Curve used for all internal [AnimatedAlign] transitions (pill
  /// alignment + cancel button expand). Default [Curves.decelerate].
  final Curve animationCurve;

  static const double _clearButtonWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    final scope = SliverSnapScope.maybeOf(context);
    final contentOpacity = scope?.contentOpacity ?? 1.0;
    final isDisabled = scope?.isDisabled ?? false;

    final theme = Theme.of(context);
    final resolvedPillColor =
        pillColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.06);
    final resolvedHintStyle =
        hintStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );

    final tapHandler = isDisabled
        ? null
        : () {
            if (!isSearching) {
              onTap();
              return;
            }
            if (!focusNode.hasFocus) focusNode.requestFocus();
          };

    return Opacity(
      opacity: isDisabled && !isSearching
          ? kDefaultDisabledContentOpacity
          : 1.0,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: tapHandler,
              child: _buildPill(
                context,
                contentOpacity: contentOpacity,
                pillColor: resolvedPillColor,
                hintStyle: resolvedHintStyle,
              ),
            ),
          ),
          if (trailing != null)
            _AnimatedExpandFade(
              visible: isSearching,
              widthAnimationDuration: animationDuration,
              opacityDuration: cancelFadeDuration,
              curve: animationCurve,
              child: trailing!,
            ),
          _AnimatedExpandFade(
            visible: isSearching,
            widthAnimationDuration: animationDuration,
            opacityDuration: cancelFadeDuration,
            curve: animationCurve,
            child: GestureDetector(
              onTap: onBack,
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Text(
                  cancelText,
                  style:
                      cancelStyle ??
                      theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required double contentOpacity,
    required Color pillColor,
    required TextStyle? hintStyle,
  }) {
    return Container(
      decoration:
          pillDecoration ??
          BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(pillCornerRadius),
          ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Opacity(
        opacity: contentOpacity,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final hasText = controller.text.isNotEmpty;
            return Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    right: hasText ? _clearButtonWidth : 0.0,
                  ),
                  child: AnimatedAlign(
                    duration: animationDuration,
                    curve: animationCurve,
                    alignment: isSearching
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: _buildInputRow(context, hintStyle: hintStyle),
                  ),
                ),
                if (hasText)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: controller.clear,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: clearIcon ?? const Icon(Icons.cancel, size: 20),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context, {required TextStyle? hintStyle}) {
    final theme = Theme.of(context);
    return IntrinsicWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          searchIcon ??
              Icon(
                Icons.search,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          const SizedBox(width: 4),
          Flexible(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: isSearching,
              cursorColor: cursorColor ?? theme.colorScheme.primary,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: hintStyle,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Combined width + opacity transition used for the trailing + cancel
/// widgets so they animate in sync.
class _AnimatedExpandFade extends StatelessWidget {
  const _AnimatedExpandFade({
    required this.visible,
    required this.widthAnimationDuration,
    required this.opacityDuration,
    required this.curve,
    required this.child,
  });

  final bool visible;
  final Duration widthAnimationDuration;
  final Duration opacityDuration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      duration: widthAnimationDuration,
      alignment: Alignment.centerLeft,
      curve: curve,
      widthFactor: visible ? 1.0 : 0.0,
      heightFactor: visible ? 1.0 : 0.0,
      child: AnimatedOpacity(
        duration: opacityDuration,
        opacity: visible ? 1.0 : 0.0,
        child: child,
      ),
    );
  }
}
