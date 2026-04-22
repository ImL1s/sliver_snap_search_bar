# Changelog

## 0.1.0 — initial release

- `SliverSnapSearchBarDelegate` — `SliverPersistentHeaderDelegate` that
  compresses linearly as the user scrolls up and re-expands on
  scroll-down. `minExtent` is dynamic: 0 when not searching (can
  collapse) and equal to `maxExtent` when searching (pinned full
  height).
- Dual-track fade: outer shell shrinks via height, inner content fades
  twice as fast via `SliverSnapScope` (inherited widget).
- `SnapSearchBarController` — owns the gesture and offset side:
  - `maybeSnapOnPointerUp()` — on finger lift, if the scroll offset is
    in the half-compressed band `(0, totalHeight)`, animates it to the
    nearer end within 140ms.
  - `savePreSearchOffset()` / `restorePreSearchOffset()` — record +
    replay the scroll offset across entering / exiting search mode,
    with a monotonic version guard that aborts stale recursions
    (prevents a rapid enter/exit cycle from corrupting the saved
    offset).
  - `onRestoreExhausted` callback for logging when the maximum retry
    budget is spent before `hasContentDimensions` becomes true.
- `DefaultSnapSearchBarRow` — batteries-included search pill with
  centred-to-left alignment transition + cancel button. Reads
  `SliverSnapScope.of` so scroll-hide fade just works; override with
  your own widget if you need custom styling.
- `SnapSearchBarView` — convenience widget wrapping a `CustomScrollView`
  with everything wired up. Opt in for simple cases, compose the
  primitives for advanced ones.
- Public constants for tuning: `kDefaultSearchBarTotalHeight`,
  `kDefaultSnapDuration`, `kDefaultEarlyReturnRatio`, etc.
