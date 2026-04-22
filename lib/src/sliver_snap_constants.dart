/// Shared constants for the scroll-hide + magnetic-snap search bar.
///
/// These are exposed publicly so callers can read the snap animation
/// duration (to sync other transitions) or tune the visual thresholds.
library;

import 'package:flutter/foundation.dart';

/// Default content height of the search bar (without vertical padding).
///
/// Matches Telegram iOS at 40 logical pixels.
const double kDefaultSearchBarContentHeight = 40.0;

/// Default vertical padding wrapping the search bar content on each side.
///
/// Total outer height = [kDefaultSearchBarContentHeight] + 2 * [kDefaultSearchBarVerticalPadding] = 56.
const double kDefaultSearchBarVerticalPadding = 8.0;

/// Default total outer height of the search bar (content + vertical padding).
const double kDefaultSearchBarTotalHeight =
    kDefaultSearchBarContentHeight + kDefaultSearchBarVerticalPadding * 2;

/// Ratio below which the delegate skips rendering the search row entirely.
///
/// When the bar is compressed below this ratio, an empty `SizedBox` is
/// returned instead of the `child` to avoid intrinsic-height layout cost
/// (TextField / Row with alignment can overflow at sub-pixel heights).
///
/// Default is 0.1 (10% of full height). Keep low enough that the transition
/// remains visually smooth; a too-high value makes the bar "hard cut" and
/// appear to disappear instead of shrink.
const double kDefaultEarlyReturnRatio = 0.1;

/// Default duration for the magnetic snap animation when the user lifts
/// their finger in a mid-compressed state.
///
/// 140 ms matches Telegram iOS "tap and release" snap feel; values above
/// 200 ms feel sluggish, below 100 ms feel jarring.
const Duration kDefaultSnapDuration = Duration(milliseconds: 140);

/// Default content opacity applied when the host indicates a "disabled"
/// state (e.g. an edit/multi-select mode on a chat list).
///
/// Only the inner content fades; the bar itself remains laid out so it
/// does not cause re-layout in the sliver chain.
const double kDefaultDisabledContentOpacity = 0.4;

/// Maximum number of `addPostFrameCallback` retries the offset restorer
/// will perform while waiting for `ScrollPosition.hasContentDimensions`
/// to become true.
///
/// Covers the transition frame when a sliver's `minExtent` changes and
/// the scroll position has not yet measured content. After the limit is
/// reached, the restorer falls back to `jumpTo(0)` rather than silently
/// failing.
const int kDefaultRestoreMaxAttempts = 5;

/// Internal flag used only in assertions / debugPrint gating.
@visibleForTesting
const bool kDebugSnapSearchBar = false;
