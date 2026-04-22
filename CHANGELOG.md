# Changelog

## 0.2.0 — bug fixes + customization hooks + naming cleanup

Round-2 review pass (Codex + Claude `code-reviewer` + Claude
`architect`) surfaced 4 correctness bugs and a cluster of missing
style hooks; this release closes all of them and unifies the public
prefix to `SliverSnap*` ahead of 1.0.

### Breaking

- **API prefix unified to `SliverSnap*`.** The three public types have
  been renamed:
  - `SnapSearchBarController` → `SliverSnapController`
  - `SnapSearchBarView`       → `SliverSnapView`
  - `DefaultSnapSearchBarRow` → `DefaultSliverSnapRow`

  Old names are kept as `@Deprecated` `typedef` aliases for the 0.2.x
  cycle (migration warning, no compile break) and will be removed in
  v0.3.0. Run a find-replace on the three symbol names.

### Fixed

- **Pixel jump on the early-return boundary** (Codex #4). Below
  `earlyReturnRatio` the bar returned `SizedBox(height: contentHeight *
  ratio)` while the full-render branch sizes via `totalHeight * ratio`
  (content + 2× verticalPadding). The mismatch produced a visible
  single-frame jump at the crossover. Both branches now use the same
  `totalHeight * ratio` base.
- **Stale content after switching `child` ↔ `builder` mode** (Codex #1
  / CR-2). `shouldRebuild` now detects a `(child == null) !=
  (oldDelegate.child == null)` mode flip and triggers a rebuild.
  Identity comparison of `child` / `builder` is still intentionally
  skipped (callers rebuild widgets every frame in common patterns such
  as `ValueListenableBuilder`).
- **Snap controller desync on config change** (Codex #2).
  `SliverSnapView.didUpdateWidget` now recreates the internal
  `SliverSnapController` when `totalHeight` / `snapDuration` /
  `snapCurve` change, not only when the `scrollController` is swapped.
  Previously the delegate picked up new values but the controller
  retained stale snap-target math.
- **Silent drop of the saved offset when `hasClients == false`** (Codex
  #3). `SliverSnapController.restorePreSearchOffset` now retries on
  subsequent post-frames (up to `maxRestoreAttempts`) instead of
  bailing on the very first frame after a tab detach / reattach.
  `onRestoreExhausted` fires only when the retry budget is truly
  exhausted.

### Added

- `SliverSnapScope.progress` (0..1) published alongside
  `contentOpacity` — custom search rows can now drive non-linear
  effects (icon rotation, parallax, scale curves) from the raw shrink
  progress, not just the dual-track opacity (AR #1).
- `DefaultSliverSnapRow`:
  - `pillDecoration` — full `BoxDecoration` override with priority over
    `pillColor` + `pillCornerRadius`. Use for shadows, gradients,
    borders, or conditional focus rings.
  - `hintStyle`, `cancelStyle`, `cursorColor` — style hooks for the
    placeholder, cancel button, and `TextField` cursor.
  - `animationCurve` — configurable curve for the internal
    `AnimatedAlign` transitions (default remains `Curves.decelerate`).
  (CR-LOW + AR #2 + AR #3).
- `SliverSnapView.searchBarBuilder` — builder alternative to
  `searchBar` that receives `(context, contentOpacity)` so callers
  using the high-level View can still react to per-frame opacity
  without dropping down to primitives. An assert enforces exactly one
  of `searchBar` / `searchBarBuilder` (AR #5).
- `SliverSnapView.divider` — optional widget inserted as a
  `SliverToBoxAdapter` between the search-bar header and the content
  slivers. Saves every caller re-inventing the 1-px Telegram-style
  divider (AR #4 / CR-LOW).
- `kDefaultDisabledContentOpacity` is now wired through to
  `DefaultSliverSnapRow`'s disabled-state opacity (previously hardcoded
  0.4). The delegate constructor also asserts `totalHeight ≈
  contentHeight + 2 * verticalPadding` so mis-decomposed heights fail
  loud at construction (Codex #5).

### Changed

- SDK constraint widened:
  - `sdk: ^3.11.4` → `sdk: ^3.8.0`
  - `flutter: ">=3.0.0"` → `flutter: ">=3.32.0"` (honest floor —
    `Color.withValues(alpha: …)` needs Flutter 3.27+, and
    `flutter_lints: ^6.0.0` needs Dart ^3.8.0 which ships with Flutter
    3.32.0).
- GitHub Actions CI matrix added: `flutter: [3.32.0, stable]`.

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
