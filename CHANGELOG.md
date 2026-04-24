# Changelog

## 0.3.2 — SliverGeometry + exit-search race fixes (no API changes)

Patch release backporting two correctness fixes from upstream. No API
changes; all 62 v0.3.1 tests still pass, plus 3 new regression tests.

### Fixed

- **SliverGeometry `layoutExtent exceeds paintExtent` assertion.** Flutter's
  framework computes `layoutExtent = (maxExtent - shrinkOffset).clamp(minExtent,
  maxExtent)`. Our delegate's `build()` was returning paint heights derived via
  a different formula path: normal branch composed `contentHeight * ratio + 2 *
  verticalPadding * ratio` (three floating-point ops accumulating ~5e-15 dp
  drift), early-return branch with `pinnedDividerHeight` painted only the
  divider height (e.g. 1 dp) against a framework-expected layoutExtent of
  several dp. Both sites now wrap their output in
  `SizedBox(height: (maxExtent - shrinkOffset).clamp(minExtent, maxExtent))`
  using the framework's exact formula — single FP op, zero precision
  divergence. Early-return also adds `ClipRect` for overflow symmetry with
  the normal branch. Fixes debug-log assertion spam (upstream reported ~142
  assertions in a 3K-line log). Backport of upstream `ea3b39f4e` + `57e9ef103`
  + `5b437b853`.

- **Exit-search `_isSnapping` race window.** When the user exits search mode
  while a snap animation is in flight, `restorePreSearchOffset`'s `jumpTo`
  interrupts `animateTo`, but the cancelled animation's `.whenComplete` fires
  on a later microtask. Between the two, a fresh `pointerUp` hitting
  `maybeSnapOnPointerUp` was swallowed by `if (_isSnapping) return`.
  `restorePreSearchOffset` now pre-clears `_isSnapping` and bumps
  `_snapGeneration` — symmetric with `savePreSearchOffset` (already clears the
  flag) and `abortSnap` (already bumps generation). Backport of upstream
  `f5d57a9e7`.

### Verification

- `flutter test --no-pub` — 65 tests pass (62 baseline + 3 new).
- `flutter analyze` — 0 issues.
- `flutter pub publish --dry-run` — 0 warnings.

## 0.3.1 — docs & discovery polish (no code changes)

Documentation, metadata, and example-only release. No changes under `lib/`.
All 62 tests from 0.3.0 still pass.

### Docs

- **README rewrite (top half)** — above-the-fold hook now leads with the
  demo gif, a "Why not SliverAppBar?" callout (fling-wait snap,
  re-entry race, minExtent flip), and a one-line value prop. Added a
  "Which widget do I use?" decision table in Getting Started
  (`SliverSnapView` vs primitives) and a `<details open>` "New in
  0.3.0" block surfacing `abortSnap()`, `pinnedDividerHeight`, and the
  deprecation-deferred-to-v0.4.0 note. Advanced usage, Custom row, API
  surface, Behavior details, and FAQ sections are preserved.
- **Example app** — `example/lib/main.dart` now demonstrates
  `pinnedDividerHeight: 1` + `pinnedDividerColor: Colors.grey.shade300`
  on `SliverSnapView`. This is a deliberate behavior demo: the
  divider stays pinned under the navbar when the bar fully
  compresses, replacing v0.3.0's scroll-away `SliverToBoxAdapter`
  divider.

### Discovery

- **`pubspec.yaml` topics** retargeted: `[sliver, search-bar, scroll,
  snap, widget]` → `[sliver, search-bar, appbar, telegram,
  animation]`. `scroll`/`snap`/`widget` were too generic; `appbar`
  captures developers searching for `SliverAppBar` alternatives,
  `telegram` encodes the visual reference, `animation` picks up the
  snap behavior.
- **GitHub repo About + topics** set via `gh`. Description encodes
  the differentiation: "Scroll-hide search bar Sliver for Flutter
  with pointer-up magnetic snap — reproduces the Telegram iOS
  chat-list UX." Topics: `flutter`, `flutter-widget`, `flutter-ui`,
  `sliver`, `search-bar`, `sliver-persistent-header`,
  `telegram-search-bar`, `dart`.

## 0.3.0 — upstream backports: pointerDown abort + pinned divider

Two UX improvements backported from the original upstream project
(`customer-im-client`, Round 4 / US-S4) that this package was
extracted from. Both are additive; v0.2.x callers compile unchanged.

### Added

- **`SliverSnapController.abortSnap()`** — cancels an in-flight snap
  animation synchronously via `jumpTo(currentPixels)` + `_isSnapping
  = false`. Idempotent (no-op when not snapping or when the scroll
  has no clients). `SliverSnapView` now wires this to
  `Listener.onPointerDown` so a fresh user touch immediately stops
  the tail of a 140 ms snap instead of fighting it — matches
  Telegram iOS tactile feel.
- **`SliverSnapSearchBarDelegate.pinnedDividerHeight` +
  `pinnedDividerColor`** (also forwarded on `SliverSnapView`) — a
  divider rendered inside the delegate output, always visible even
  when the search bar body is fully compressed. `minExtent` becomes
  `dividerHeight` (instead of 0) so the 1 px line stays pinned under
  the navbar. Matches Telegram iOS where the separator never scrolls
  away.

  Use `pinnedDivider*` for the TG iOS navbar-line behavior. Use the
  existing `SliverSnapView.divider` (free-floating
  `SliverToBoxAdapter`) when you want a scroll-away separator below
  the header. Both can coexist — they solve different visual
  problems.

### Fixed

- **Race between `abortSnap()` and an immediately-restarted snap.**
  The new internal `_snapGeneration` counter is captured pre-animate
  and checked in `whenComplete`, so the aborted animation's stale
  microtask cannot clear the newer snap's `_isSnapping` guard. Without
  this, a pointerDown+pointerUp within the same event turn could
  corrupt the flag and let a concurrent `animateTo` start.

### Changed

- `@Deprecated` typedef aliases (`SnapSearchBarController`,
  `SnapSearchBarView`, `DefaultSnapSearchBarRow`) now advertise
  **removal in v0.4.0** (was v0.3.0). v0.2.0 shipped the aliases the
  same release cycle as v0.3.0, so callers had zero grace period.
  Deferring one more minor gives time to migrate.

### Asserts

- `SliverSnapSearchBarDelegate` and `SliverSnapView` both assert
  `pinnedDividerColor != null` when `pinnedDividerHeight` is
  non-null. A `Container(height, color: null)` would render a
  transparent gap — almost certainly a caller bug.

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
