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

  group('SliverSnapSearchBarDelegate pinned divider extents', () {
    test('pinnedDividerHeight increases maxExtent by dividerHeight', () {
      final d = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      expect(d.maxExtent, kDefaultSearchBarTotalHeight + 1.0);
    });

    test('pinnedDividerHeight sets minExtent = dividerHeight when not searching', () {
      final d = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      expect(d.minExtent, 1.0);
    });

    test('pinnedDividerHeight sets minExtent = maxExtent when searching', () {
      final d = SliverSnapSearchBarDelegate(
        isSearching: true,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      expect(d.minExtent, d.maxExtent);
    });

    test('null pinnedDividerHeight preserves v0.2.0 extents', () {
      final d = SliverSnapSearchBarDelegate(
        isSearching: false,
        child: const SizedBox(),
      );
      expect(d.minExtent, 0.0);
      expect(d.maxExtent, kDefaultSearchBarTotalHeight);
    });
  });

  group('SliverSnapSearchBarDelegate pinned divider build', () {
    testWidgets('pinned divider renders Container at bottom of Column', (tester) async {
      final delegate = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.red,
        child: const SizedBox(),
      );
      await _pumpDelegate(tester, delegate: delegate, shrinkOffset: 0);
      // Divider is a bare Container with height + color, no decoration.
      final divider = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration == null && c.color == Colors.red);
      expect(divider, isNotEmpty);
    });

    testWidgets('early-return branch still renders pinned divider', (tester) async {
      final delegate = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.red,
        child: const SizedBox(),
      );
      // shrinkOffset 54 -> ratio = 1 - 54/56 = 0.036 < 0.1 -> early return
      await _pumpDelegate(tester, delegate: delegate, shrinkOffset: 54);
      final divider = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.color == Colors.red);
      expect(divider, isNotEmpty);
    });

    testWidgets('progress denominator stays totalHeight (not totalHeight + dividerHeight)', (tester) async {
      // At shrinkOffset 28, progress must be 28/56 = 0.5, not 28/57.
      late SliverSnapScope captured;
      final delegate = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: Builder(builder: (ctx) {
          captured = SliverSnapScope.of(ctx);
          return const SizedBox();
        }),
      );
      await _pumpDelegate(tester, delegate: delegate, shrinkOffset: 28);
      expect(captured.progress, closeTo(0.5, 1e-9));
    });
  });

  group('SliverSnapSearchBarDelegate.shouldRebuild pinned divider', () {
    test('pinnedDividerHeight change triggers rebuild', () {
      final a = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      final b = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 2.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      expect(a.shouldRebuild(b), isTrue);
    });

    test('pinnedDividerColor change triggers rebuild', () {
      final a = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      final b = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.red,
        child: const SizedBox(),
      );
      expect(a.shouldRebuild(b), isTrue);
    });

    test('same pinned divider params do not trigger rebuild', () {
      final a = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      final b = SliverSnapSearchBarDelegate(
        isSearching: false,
        pinnedDividerHeight: 1.0,
        pinnedDividerColor: Colors.grey,
        child: const SizedBox(),
      );
      expect(a.shouldRebuild(b), isFalse);
    });
  });

  group('SliverSnapSearchBarDelegate pinned divider ctor', () {
    test('asserts pinnedDividerColor required when pinnedDividerHeight set', () {
      expect(
        () => SliverSnapSearchBarDelegate(
          isSearching: false,
          pinnedDividerHeight: 1.0,
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
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

  group('SliverSnapSearchBarDelegate SliverGeometry boundary (normal branch)', () {
    testWidgets('shrinkOffset mid-band does not violate layoutExtent <= paintExtent', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _delegate(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        ),
      );

      // Normal branch active: ratio > 0.1 → shrinkOffset < 0.9 * totalHeight = 50.4
      scroll.jumpTo(48);
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'normal-branch 5e-15 dp FP drift must not assert layoutExtent > paintExtent');
    });
  });

  group('SliverSnapController', () {
    late ScrollController scroll;
    late SliverSnapController controller;

    setUp(() {
      scroll = ScrollController();
      controller = SliverSnapController(scrollController: scroll);
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

    test('abortSnap is no-op when not snapping', () {
      controller.abortSnap();
      expect(controller.isSnapping, isFalse);
    });

    test('abortSnap after dispose asserts', () {
      controller.dispose();
      expect(() => controller.abortSnap(), throwsAssertionError);
    });
  });

  group('SliverSnapController.abortSnap with attached scroll', () {
    testWidgets('abortSnap stops inflight snap and clears flag', (tester) async {
      final scroll = ScrollController();
      final ctrl = SliverSnapController(scrollController: scroll);
      addTearDown(scroll.dispose);
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
        ),
      );

      // Jump to mid-band (within (0, totalHeight)) so maybeSnap starts.
      scroll.jumpTo(20);
      ctrl.maybeSnapOnPointerUp();
      expect(ctrl.isSnapping, isTrue);

      ctrl.abortSnap();
      expect(ctrl.isSnapping, isFalse);
    });

    testWidgets('abortSnap no-op when scroll has no clients', (tester) async {
      final scroll = ScrollController();
      final ctrl = SliverSnapController(scrollController: scroll);
      addTearDown(scroll.dispose);
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      ctrl.maybeSnapOnPointerUp(); // no-op, no clients
      ctrl.abortSnap(); // must not throw
      expect(ctrl.isSnapping, isFalse);
    });

    testWidgets(
      'abort then restart snap: old whenComplete does not clear new _isSnapping',
      (tester) async {
        // The snap-generation counter must guard against the
        // abort-then-resnap-within-same-event race: the aborted
        // animation's stale whenComplete would otherwise clear the new
        // snap's _isSnapping flag.
        final scroll = ScrollController();
        final ctrl = SliverSnapController(scrollController: scroll);
        addTearDown(scroll.dispose);
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                controller: scroll,
                slivers: const [
                  SliverToBoxAdapter(child: SizedBox(height: 2000)),
                ],
              ),
            ),
          ),
        );

        // 1. Start snap 1
        scroll.jumpTo(20);
        ctrl.maybeSnapOnPointerUp();
        expect(ctrl.isSnapping, isTrue);

        // 2. Abort snap 1
        ctrl.abortSnap();
        expect(ctrl.isSnapping, isFalse);

        // 3. Start snap 2
        scroll.jumpTo(20);
        ctrl.maybeSnapOnPointerUp();
        expect(ctrl.isSnapping, isTrue);

        // 4. Pump past snap 1's full duration — its stale whenComplete
        //    fires on the microtask queue. Without the generation
        //    counter, this would set _isSnapping = false, corrupting
        //    snap 2's guard.
        await tester.pump(const Duration(milliseconds: 200));

        // 5. Snap 2 is still in flight — generation counter protected it.
        expect(ctrl.isSnapping, isTrue);
      },
    );
  });

  group('SliverSnapController.restorePreSearchOffset retry', () {
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
        final ctl = SliverSnapController(
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
      final ctl = SliverSnapController(scrollController: scroll);
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

  group('SliverSnapController.restorePreSearchOffset pre-clear', () {
    testWidgets(
      'restorePreSearchOffset clears isSnapping so next pointerUp is not swallowed',
      (tester) async {
        final scroll = ScrollController();
        final ctrl = SliverSnapController(scrollController: scroll);
        addTearDown(scroll.dispose);
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                controller: scroll,
                slivers: const [
                  SliverToBoxAdapter(child: SizedBox(height: 2000)),
                ],
              ),
            ),
          ),
        );

        // 1. Save BEFORE inducing snap — save's _isSnapping=false runs while flag is already false (no-op).
        ctrl.savePreSearchOffset();

        // 2. NOW induce _isSnapping = true via a real mid-band snap.
        scroll.jumpTo(20);
        ctrl.maybeSnapOnPointerUp();
        expect(ctrl.isSnapping, isTrue);

        // 3. restorePreSearchOffset is the ONLY call that can clear the flag from this point.
        //    Pre-fix: doesn't touch _isSnapping → stays true → FAIL.
        //    Post-fix: pre-clears → PASS.
        ctrl.restorePreSearchOffset();
        expect(ctrl.isSnapping, isFalse,
            reason: 'restorePreSearchOffset must pre-clear _isSnapping '
                'so a fresh pointerUp is not swallowed by the guard');

        // 4. Confirm a fresh snap can start.
        scroll.jumpTo(20);
        ctrl.maybeSnapOnPointerUp();
        expect(ctrl.isSnapping, isTrue,
            reason: 'pointerUp after restore must start a new snap');
      },
    );
  });
}
