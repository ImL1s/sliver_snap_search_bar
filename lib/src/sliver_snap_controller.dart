import 'package:flutter/material.dart';

import 'sliver_snap_constants.dart';

/// Coordinator for the magnetic-snap + offset-restore behavior that
/// pairs with [SliverSnapSearchBarDelegate].
///
/// The delegate owns the render side (how the bar compresses). The
/// controller owns the gesture side:
///
/// * **Magnetic snap** — on finger lift, if the scroll offset is
///   between `(0, totalHeight)` (a mid-compressed state), the scroll
///   animates to the nearer end (0 or totalHeight) within [snapDuration].
/// * **Pre-search offset save/restore** — when entering search mode
///   the host can call [savePreSearchOffset] to record the current
///   `ScrollController.offset`; on exit, [restorePreSearchOffset]
///   replays it, retrying up to [maxRestoreAttempts] if the scroll
///   position has not measured its content yet (common during the
///   frame where the delegate's `minExtent` changes).
/// * **Race safety** — each `savePreSearchOffset` and
///   `restorePreSearchOffset` bumps an internal version. In-flight
///   restore recursions check the version on each frame and abort
///   if the host has re-entered / re-exited search mode in between.
///
/// ### Typical usage
///
/// ```dart
/// class _MyPageState extends State<MyPage> {
///   final _scrollCtrl = ScrollController();
///   late final _snapCtrl = SnapSearchBarController(scrollController: _scrollCtrl);
///   bool _isSearching = false;
///
///   void _enterSearch() {
///     _snapCtrl.savePreSearchOffset();
///     setState(() => _isSearching = true);
///     // After the delegate switches to pinned (minExtent = totalHeight)
///     // in the next frame, jump the scroll to 0 so the bar is fully
///     // visible on the search screen.
///     WidgetsBinding.instance.addPostFrameCallback((_) {
///       if (_scrollCtrl.hasClients && _scrollCtrl.offset != 0) {
///         _scrollCtrl.jumpTo(0);
///       }
///     });
///   }
///
///   void _exitSearch() {
///     setState(() => _isSearching = false);
///     _snapCtrl.restorePreSearchOffset();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Listener(
///       onPointerUp: (_) => _snapCtrl.maybeSnapOnPointerUp(),
///       onPointerCancel: (_) => _snapCtrl.maybeSnapOnPointerUp(),
///       child: CustomScrollView(
///         controller: _scrollCtrl,
///         slivers: [
///           SliverPersistentHeader(
///             pinned: true,
///             delegate: SliverSnapSearchBarDelegate(
///               isSearching: _isSearching,
///               child: MySearchBarRow(),
///             ),
///           ),
///           // ... your list ...
///         ],
///       ),
///     );
///   }
///
///   @override
///   void dispose() {
///     _snapCtrl.dispose();
///     _scrollCtrl.dispose();
///     super.dispose();
///   }
/// }
/// ```
class SnapSearchBarController {
  SnapSearchBarController({
    required this.scrollController,
    this.totalHeight = kDefaultSearchBarTotalHeight,
    this.snapDuration = kDefaultSnapDuration,
    this.snapCurve = Curves.easeOutCubic,
    this.maxRestoreAttempts = kDefaultRestoreMaxAttempts,
    this.onRestoreExhausted,
  });

  /// The scroll controller driving the scroll view that contains the
  /// snap search bar. Owned by the caller (caller disposes).
  final ScrollController scrollController;

  /// Full outer height of the search bar (must match the paired
  /// [SliverSnapSearchBarDelegate.totalHeight]).
  final double totalHeight;

  /// Duration of the magnetic snap animation.
  final Duration snapDuration;

  /// Curve of the magnetic snap animation.
  final Curve snapCurve;

  /// Maximum number of retries waiting for `hasContentDimensions`.
  final int maxRestoreAttempts;

  /// Optional callback fired when [restorePreSearchOffset] exhausts all
  /// retries and falls back to `jumpTo(0)`. Use for instrumentation /
  /// logging.
  final void Function(double preSearchOffset)? onRestoreExhausted;

  bool _isSnapping = false;
  bool _disposed = false;

  double _preSearchOffset = 0.0;

  /// Monotonically incremented on every savePreSearchOffset /
  /// restorePreSearchOffset. Used by in-flight restore recursions to
  /// detect that the host has re-entered / re-exited search and the
  /// recursion's captured offset is stale.
  int _version = 0;

  /// Current recorded pre-search offset.
  @visibleForTesting
  double get preSearchOffset => _preSearchOffset;

  /// Whether a snap animation is currently in progress.
  bool get isSnapping => _isSnapping;

  /// Saves the current `scrollController.offset` so it can be restored
  /// later via [restorePreSearchOffset].
  ///
  /// Offsets in the half-compressed band `(0, totalHeight)` are
  /// normalised to `0` — the inverse of [restorePreSearchOffset]'s
  /// same-band handling, which guarantees a re-entry sequence
  /// (rapid enter/exit) cannot corrupt the saved offset.
  ///
  /// Also bumps the internal version, invalidating any in-flight
  /// restore recursion and clearing [isSnapping] (a snap animation in
  /// progress should not leak across a search mode transition).
  void savePreSearchOffset() {
    _assertNotDisposed();
    _version++;
    _isSnapping = false;
    final offset = scrollController.hasClients ? scrollController.offset : 0.0;
    _preSearchOffset = offset > totalHeight ? offset : 0.0;
  }

  /// Replays the offset recorded by the last
  /// [savePreSearchOffset]. If the scroll position has not measured
  /// its content dimensions yet (typically the frame where the paired
  /// delegate's `minExtent` changes), retries on subsequent frames
  /// up to [maxRestoreAttempts] times before falling back to
  /// `jumpTo(0)` — never silently fails.
  void restorePreSearchOffset() {
    _assertNotDisposed();
    _version++;
    _restoreInternal(_version);
  }

  void _restoreInternal(int version, [int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || version != _version) return;
      // Codex #3: hasClients may be false on the first post-frame after
      // a tab detach/re-attach or on the very first frame of a fresh
      // CustomScrollView. Retry instead of silently abandoning the
      // saved offset.
      if (!scrollController.hasClients) {
        if (attempt < maxRestoreAttempts) {
          _restoreInternal(version, attempt + 1);
        } else {
          onRestoreExhausted?.call(_preSearchOffset);
        }
        return;
      }
      final position = scrollController.position;
      if (!position.hasContentDimensions) {
        if (attempt < maxRestoreAttempts) {
          _restoreInternal(version, attempt + 1);
        } else {
          onRestoreExhausted?.call(_preSearchOffset);
          scrollController.jumpTo(0);
        }
        return;
      }
      final safeOffset = _preSearchOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      scrollController.jumpTo(safeOffset < totalHeight ? 0.0 : safeOffset);
    });
  }

  /// Inspects the current scroll offset and, if it is stuck in a
  /// half-compressed band, animates it to the nearer of `0` (fully
  /// revealed) or `totalHeight` (fully hidden). Call from your
  /// `Listener.onPointerUp` / `onPointerCancel`.
  ///
  /// Does nothing when:
  /// * A snap is already in progress (re-entry guard).
  /// * The scroll has no clients.
  /// * The current offset is outside `(0, totalHeight)`.
  void maybeSnapOnPointerUp() {
    _assertNotDisposed();
    if (_isSnapping) return;
    if (!scrollController.hasClients) return;

    final pixels = scrollController.position.pixels;
    if (pixels <= 0 || pixels >= totalHeight) return;

    final target = pixels < totalHeight / 2 ? 0.0 : totalHeight;
    _isSnapping = true;
    // jumpTo stops any in-flight fling synchronously; immediately
    // following animateTo then takes over. These two calls must be
    // contiguous — nothing else may write to the scroll position in
    // between.
    scrollController.jumpTo(pixels);
    scrollController
        .animateTo(target, duration: snapDuration, curve: snapCurve)
        .then(
          (_) {},
          onError: (Object err, StackTrace st) {
            // ScrollController.animateTo failure paths (detached,
            // disposed, no attached positions) are all FlutterError
            // subclasses. Swallow as expected lifecycle noise.
            if (err is FlutterError) return;
            // Re-throw anything else — that indicates a real bug.
            throw err; // ignore: only_throw_errors
          },
        )
        .whenComplete(() {
          if (!_disposed) _isSnapping = false;
        });
  }

  /// Clears the in-progress snap flag without cancelling the animation.
  /// Useful if your host widget detaches / re-attaches (e.g. bottom
  /// tab switch) and wants to reset the guard. Prefer calling this in
  /// the place where you would otherwise hit the "flag stuck" edge
  /// case rather than whenever "just to be safe".
  void resetSnapFlag() {
    _isSnapping = false;
  }

  /// Releases internal resources. Does **not** dispose the
  /// [scrollController] — the caller owns it.
  void dispose() {
    _disposed = true;
  }

  void _assertNotDisposed() {
    assert(
      !_disposed,
      'SnapSearchBarController used after dispose(). Create a new '
      'controller instead of reusing a disposed one.',
    );
  }
}
