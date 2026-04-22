import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_snap_search_bar/sliver_snap_search_bar.dart';

const double _totalH = kDefaultSearchBarTotalHeight; // 56

SliverSnapSearchBarDelegate _delegate({
  bool isSearching = false,
  bool isDisabled = false,
  Widget? child,
  Widget Function(BuildContext, double)? builder,
}) {
  return SliverSnapSearchBarDelegate(
    isSearching: isSearching,
    isDisabled: isDisabled,
    child: child ?? const _OpacityProbe(),
    builder: builder,
  );
}

/// Reads the content opacity from [SliverSnapScope] and paints a
/// single `Opacity` node so tests can assert on it by type.
class _OpacityProbe extends StatelessWidget {
  const _OpacityProbe();

  @override
  Widget build(BuildContext context) {
    final scope = SliverSnapScope.of(context);
    return Opacity(
      opacity: scope.contentOpacity,
      child: const SizedBox.expand(),
    );
  }
}

Future<void> _pumpDelegate(
  WidgetTester tester, {
  required SliverSnapSearchBarDelegate delegate,
  required double shrinkOffset,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => delegate.build(context, shrinkOffset, false),
        ),
      ),
    ),
  );
}

double _readOpacity(WidgetTester tester) {
  final finder = find.byType(Opacity);
  expect(finder, findsOneWidget);
  return tester.widget<Opacity>(finder).opacity;
}

void main() {
  group('SliverSnapSearchBarDelegate extents', () {
    test('non-searching: minExtent = 0, maxExtent = totalHeight', () {
      final d = _delegate(isSearching: false);
      expect(d.minExtent, 0);
      expect(d.maxExtent, _totalH);
    });

    test('searching: min == max == totalHeight (pinned)', () {
      final d = _delegate(isSearching: true);
      expect(d.minExtent, _totalH);
      expect(d.maxExtent, _totalH);
    });

    test('custom total height propagates to both extents', () {
      final d = SliverSnapSearchBarDelegate(
        isSearching: true,
        totalHeight: 64,
        contentHeight: 48,
        verticalPadding: 8,
        child: const SizedBox(),
      );
      expect(d.minExtent, 64);
      expect(d.maxExtent, 64);
    });
  });

  group('SliverSnapSearchBarDelegate fade keyframes', () {
    testWidgets('shrinkOffset 0 → content opacity 1.0', (tester) async {
      await _pumpDelegate(
        tester,
        delegate: _delegate(isSearching: false),
        shrinkOffset: 0,
      );
      expect(_readOpacity(tester), 1.0);
    });

    testWidgets('shrinkOffset 14 (25%) → 0.5', (tester) async {
      await _pumpDelegate(
        tester,
        delegate: _delegate(isSearching: false),
        shrinkOffset: 14,
      );
      expect(_readOpacity(tester), closeTo(0.5, 1e-9));
    });

    testWidgets('shrinkOffset 28 (50%) → 0.0 (inner fade finishes)', (
      tester,
    ) async {
      await _pumpDelegate(
        tester,
        delegate: _delegate(isSearching: false),
        shrinkOffset: 28,
      );
      expect(_readOpacity(tester), closeTo(0.0, 1e-9));
    });

    testWidgets('searching: opacity stays 1.0 regardless of shrinkOffset', (
      tester,
    ) async {
      await _pumpDelegate(
        tester,
        delegate: _delegate(isSearching: true),
        shrinkOffset: _totalH,
      );
      expect(_readOpacity(tester), 1.0);
    });
  });

  group('SliverSnapSearchBarDelegate early return', () {
    testWidgets('ratio < earlyReturnRatio returns SizedBox (no child)', (
      tester,
    ) async {
      // ratio = 1 - 54/56 = 0.0357 < 0.1 → early return
      await _pumpDelegate(
        tester,
        delegate: _delegate(isSearching: false),
        shrinkOffset: 54,
      );
      expect(find.byType(_OpacityProbe), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('ratio just above threshold still renders child', (
      tester,
    ) async {
      // ratio = 1 - 50/56 = 0.107 > 0.1
      await _pumpDelegate(
        tester,
        delegate: _delegate(isSearching: false),
        shrinkOffset: 50,
      );
      expect(find.byType(_OpacityProbe), findsOneWidget);
    });
  });

  group('SliverSnapSearchBarDelegate.shouldRebuild', () {
    test('isSearching change → rebuild', () {
      final a = _delegate(isSearching: false);
      final b = _delegate(isSearching: true);
      expect(a.shouldRebuild(b), isTrue);
    });

    test('isDisabled change → rebuild', () {
      final a = _delegate(isDisabled: false);
      final b = _delegate(isDisabled: true);
      expect(a.shouldRebuild(b), isTrue);
    });

    test('child identity change alone → no rebuild', () {
      final a = _delegate(child: const SizedBox(width: 10));
      final b = _delegate(child: const SizedBox(width: 20));
      expect(a.shouldRebuild(b), isFalse);
    });
  });

  group('SliverSnapScope', () {
    testWidgets('maybeOf returns null when outside the delegate build', (
      tester,
    ) async {
      SliverSnapScope? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = SliverSnapScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(captured, isNull);
    });

    testWidgets('of returns the scope under the delegate build', (
      tester,
    ) async {
      // A child widget (not a builder) builds under _SnapSearchBarScope,
      // so its BuildContext resolves the scope correctly. This is the
      // canonical way to consume contentOpacity from a custom row.
      await _pumpDelegate(tester, delegate: _delegate(), shrinkOffset: 14);
      // _OpacityProbe reads SliverSnapScope.of(context) and paints an
      // Opacity; we asserted the value already in the fade keyframes
      // group — here we just re-verify a non-null scope reachable.
      expect(find.byType(Opacity), findsOneWidget);
    });
  });

  group('SnapSearchBarController', () {
    late ScrollController scroll;
    late SnapSearchBarController controller;

    setUp(() {
      scroll = ScrollController();
      controller = SnapSearchBarController(scrollController: scroll);
    });

    tearDown(() {
      controller.dispose();
      scroll.dispose();
    });

    test('isSnapping starts false', () {
      expect(controller.isSnapping, isFalse);
    });

    test('savePreSearchOffset with no clients records 0', () {
      controller.savePreSearchOffset();
      expect(controller.preSearchOffset, 0.0);
    });

    test('savePreSearchOffset clears snap flag (atomic with save)', () {
      controller.resetSnapFlag();
      controller.savePreSearchOffset();
      expect(controller.isSnapping, isFalse);
    });

    test('maybeSnapOnPointerUp with no clients is a no-op', () {
      controller.maybeSnapOnPointerUp();
      expect(controller.isSnapping, isFalse);
    });

    test('dispose then maybeSnap asserts', () {
      controller.dispose();
      expect(() => controller.maybeSnapOnPointerUp(), throwsAssertionError);
    });
  });
}
