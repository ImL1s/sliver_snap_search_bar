import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_snap_search_bar/sliver_snap_search_bar.dart';

const double _totalH = kDefaultSearchBarTotalHeight; // 56

/// Sentinel so callers can pass an explicit `child: null` to exercise
/// builder-only mode without tripping the helper's default.
const Object _kUnset = Object();

SliverSnapSearchBarDelegate _delegate({
  bool isSearching = false,
  bool isDisabled = false,
  Object? child = _kUnset,
  Widget Function(BuildContext, double)? builder,
}) {
  final resolvedChild = identical(child, _kUnset)
      ? (builder == null ? const _OpacityProbe() : null)
      : child as Widget?;
  return SliverSnapSearchBarDelegate(
    isSearching: isSearching,
    isDisabled: isDisabled,
    child: resolvedChild,
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

  group('SliverSnapSearchBarDelegate early-return continuity', () {
    testWidgets(
      'early-return height uses totalHeight*ratio (no jump with padding frame)',
      (tester) async {
        // Just below threshold: ratio = 1 - 52/56 = 0.0714 < 0.1 → early return.
        // The outer padded branch at ratio ≈ 0.107 renders a total height of
        // totalHeight * ratio = 56 * 0.107 ≈ 6 px (content + padding). The
        // bare SizedBox should continue that curve, not drop to
        // contentHeight-only, otherwise there's a visible pixel jump on
        // the threshold frame.
        await _pumpDelegate(
          tester,
          delegate: _delegate(isSearching: false),
          shrinkOffset: 52,
        );
        final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
        expect(box.height, closeTo(_totalH * (1 - 52 / _totalH), 0.01));
      },
    );
  });

  group('SliverSnapSearchBarDelegate height decomposition assert', () {
    test('rejects totalHeight != contentHeight + 2*verticalPadding', () {
      expect(
        () => SliverSnapSearchBarDelegate(
          isSearching: false,
          totalHeight: 100, // mismatch: 40 + 2*8 = 56 != 100
          contentHeight: 40,
          verticalPadding: 8,
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });

    test('accepts matching decomposition', () {
      expect(
        () => SliverSnapSearchBarDelegate(
          isSearching: false,
          totalHeight: 72,
          contentHeight: 56,
          verticalPadding: 8,
          child: const SizedBox(),
        ),
        returnsNormally,
      );
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

    test('child → builder mode switch → rebuild', () {
      final a = _delegate(child: const SizedBox());
      final b = _delegate(child: null, builder: (ctx, op) => const SizedBox());
      expect(a.shouldRebuild(b), isTrue);
    });

    test('builder → child mode switch → rebuild', () {
      final a = _delegate(child: null, builder: (ctx, op) => const SizedBox());
      final b = _delegate(child: const SizedBox());
      expect(a.shouldRebuild(b), isTrue);
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

  group('SliverSnapScope.progress', () {
    testWidgets('progress equals shrinkOffset / totalHeight', (tester) async {
      late SliverSnapScope captured;
      final delegate = _delegate(
        child: Builder(
          builder: (ctx) {
            captured = SliverSnapScope.of(ctx);
            return const SizedBox();
          },
        ),
      );
      await _pumpDelegate(tester, delegate: delegate, shrinkOffset: 14);
      expect(captured.progress, closeTo(14 / _totalH, 1e-9));
    });

    testWidgets('progress is 0.0 at shrinkOffset 0', (tester) async {
      late SliverSnapScope captured;
      final delegate = _delegate(
        child: Builder(
          builder: (ctx) {
            captured = SliverSnapScope.of(ctx);
            return const SizedBox();
          },
        ),
      );
      await _pumpDelegate(tester, delegate: delegate, shrinkOffset: 0);
      expect(captured.progress, 0.0);
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

  group('SnapSearchBarController.restorePreSearchOffset retry', () {
    testWidgets(
      'retries while !hasClients and fires onRestoreExhausted after cap',
      (tester) async {
        // Orphan scroll controller — never attached to a scrollable —
        // so hasClients stays false for the entire test. Before the
        // retry fix, _restoreInternal bailed silently on the first
        // frame and onRestoreExhausted was never fired; after the fix
        // it retries up to maxRestoreAttempts then calls the callback.
        final scroll = ScrollController();
        addTearDown(scroll.dispose);

        final exhaustedOffsets = <double>[];
        final ctl = SnapSearchBarController(
          scrollController: scroll,
          maxRestoreAttempts: 3,
          onRestoreExhausted: exhaustedOffsets.add,
        );
        addTearDown(ctl.dispose);

        // Pump an empty app so the binding has a frame cadence.
        await tester.pumpWidget(const SizedBox.shrink(key: ValueKey('root')));

        ctl.savePreSearchOffset();
        ctl.restorePreSearchOffset();

        // Each retry schedules a new post-frame callback which only
        // fires after the next rendered frame. Dirty the tree each pump
        // to force a real frame; otherwise the binding can short-circuit.
        for (var i = 0; i < 12; i++) {
          await tester.pumpWidget(SizedBox.shrink(key: ValueKey('root-$i')));
        }

        expect(exhaustedOffsets, hasLength(1));
        expect(exhaustedOffsets.first, 0.0);
      },
    );

    testWidgets('does not throw when called with no clients', (tester) async {
      final scroll = ScrollController();
      final ctl = SnapSearchBarController(scrollController: scroll);
      addTearDown(scroll.dispose);
      addTearDown(ctl.dispose);

      await tester.pumpWidget(const SizedBox());
      ctl.savePreSearchOffset();
      ctl.restorePreSearchOffset();
      // Drain frames; must not throw even though hasClients is false.
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  });
}
