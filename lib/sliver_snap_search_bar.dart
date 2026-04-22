/// Scroll-hide + magnetic-snap search bar Sliver for Flutter, modeled
/// after Telegram iOS.
///
/// ## TL;DR
///
/// * [SliverSnapSearchBarDelegate] — drop-in `SliverPersistentHeaderDelegate`
///   that compresses smoothly as the user scrolls up and restores on
///   scroll down. Use with `SliverPersistentHeader(pinned: true)`.
/// * [SnapSearchBarController] — pairs with the delegate to add the
///   "snap on finger lift" gesture and safe enter/exit search offset
///   save/restore.
/// * [DefaultSnapSearchBarRow] — batteries-included search pill that
///   transitions between tappable placeholder ↔ `TextField` + Cancel.
///   Override with your own widget for custom designs; read
///   [SliverSnapScope.of] to apply the current fade opacity.
/// * [SnapSearchBarView] — convenience widget that wires everything
///   into a ready-to-use [CustomScrollView]. Use for simple cases,
///   compose the primitives for advanced ones.
///
/// ## Minimal usage
///
/// ```dart
/// SnapSearchBarView(
///   isSearching: _isSearching,
///   searchBar: DefaultSnapSearchBarRow(
///     isSearching: _isSearching,
///     controller: _textCtrl,
///     focusNode: _focus,
///     onTap: () => setState(() => _isSearching = true),
///     onBack: () => setState(() => _isSearching = false),
///   ),
///   slivers: [
///     SliverList.list(children: [
///       for (int i = 0; i < 50; i++) ListTile(title: Text('Item #$i')),
///     ]),
///   ],
/// );
/// ```
library;

export 'src/sliver_snap_constants.dart';
export 'src/sliver_snap_controller.dart';
export 'src/sliver_snap_search_delegate.dart';
export 'src/widgets/default_search_bar_row.dart';
export 'src/widgets/snap_search_bar_view.dart';
