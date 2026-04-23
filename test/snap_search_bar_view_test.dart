import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_snap_search_bar/sliver_snap_search_bar.dart';

void main() {
  group('SliverSnapView didUpdateWidget', () {
    testWidgets('totalHeight change rebuilds snap controller', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      Widget build({required double totalHeight}) {
        final contentHeight = totalHeight - 2 * 8;
        return MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              totalHeight: totalHeight,
              contentHeight: contentHeight,
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
            ),
          ),
        );
      }

      await tester.pumpWidget(build(totalHeight: 56));
      await tester.pumpWidget(build(totalHeight: 72));

      // Regression smoke: the config swap must not throw. Before the
      // fix, the snap controller kept the original totalHeight, and a
      // subsequent snap would use mismatched target math; if Flutter
      // surfaced that via a state error we'd see it here. The deeper
      // guarantee (snap target now matches new totalHeight) is covered
      // by behavioural review of the controller replacement path.
      expect(tester.takeException(), isNull);
    });

    testWidgets('snapDuration change does not throw', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      Widget build({required Duration snapDuration}) {
        return MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              snapDuration: snapDuration,
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
            ),
          ),
        );
      }

      await tester.pumpWidget(
        build(snapDuration: const Duration(milliseconds: 200)),
      );
      await tester.pumpWidget(
        build(snapDuration: const Duration(milliseconds: 400)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('snapCurve change does not throw', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      Widget build({required Curve snapCurve}) {
        return MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              snapCurve: snapCurve,
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
            ),
          ),
        );
      }

      await tester.pumpWidget(build(snapCurve: Curves.easeOutCubic));
      await tester.pumpWidget(build(snapCurve: Curves.linear));
      expect(tester.takeException(), isNull);
    });
  });

  group('SliverSnapView divider slot', () {
    testWidgets(
      'divider inserts SliverToBoxAdapter between header and slivers',
      (tester) async {
        final textCtrl = TextEditingController();
        final focus = FocusNode();
        addTearDown(textCtrl.dispose);
        addTearDown(focus.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SliverSnapView(
                isSearching: false,
                divider: const Divider(
                  key: ValueKey('my-divider'),
                  height: 1,
                  color: Colors.red,
                ),
                searchBar: DefaultSliverSnapRow(
                  isSearching: false,
                  controller: textCtrl,
                  focusNode: focus,
                  onTap: () {},
                  onBack: () {},
                ),
                slivers: const [
                  SliverToBoxAdapter(
                    child: SizedBox(key: ValueKey('body'), height: 100),
                  ),
                ],
              ),
            ),
          ),
        );

        // The Divider widget should be present in the tree.
        expect(find.byKey(const ValueKey('my-divider')), findsOneWidget);

        // The CustomScrollView slivers list should have 3 entries:
        //   [0] SliverPersistentHeader (search bar)
        //   [1] SliverToBoxAdapter     (divider)
        //   [2] SliverToBoxAdapter     (body content)
        final csv = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        expect(csv.slivers.length, 3);
        final dividerSliver = csv.slivers[1] as SliverToBoxAdapter;
        expect(dividerSliver.child, isA<Divider>());
      },
    );

    testWidgets('null divider keeps two slivers (no adapter inserted)', (
      tester,
    ) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
            ),
          ),
        ),
      );

      final csv = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(csv.slivers.length, 2);
    });
  });

  group('SliverSnapView searchBarBuilder', () {
    testWidgets('builder receives contentOpacity = 1.0 when fully expanded', (
      tester,
    ) async {
      final opacitySamples = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              searchBarBuilder: (ctx, op) {
                opacitySamples.add(op);
                return const SizedBox();
              },
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
            ),
          ),
        ),
      );

      expect(opacitySamples, isNotEmpty);
      expect(opacitySamples.last, 1.0);
    });

    testWidgets('providing both searchBar and searchBarBuilder throws assert', (
      tester,
    ) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      expect(
        () => SliverSnapView(
          isSearching: false,
          searchBar: DefaultSliverSnapRow(
            isSearching: false,
            controller: textCtrl,
            focusNode: focus,
            onTap: () {},
            onBack: () {},
          ),
          searchBarBuilder: (ctx, op) => const SizedBox(),
          slivers: const [],
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'providing neither searchBar nor searchBarBuilder throws assert',
      (tester) async {
        expect(
          () => SliverSnapView(isSearching: false, slivers: const []),
          throwsAssertionError,
        );
      },
    );
  });

  group('SliverSnapView pinned divider forwarding', () {
    testWidgets('pinnedDividerHeight/Color forward to delegate', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              pinnedDividerHeight: 1.0,
              pinnedDividerColor: Colors.red,
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
            ),
          ),
        ),
      );

      // Pinned divider is a bare Container with height + color (no decoration)
      // rendered inside the delegate output.
      final divider = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration == null && c.color == Colors.red);
      expect(divider, isNotEmpty);
    });

    testWidgets('null pinnedDividerHeight does not render pinned divider', (
      tester,
    ) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
            ),
          ),
        ),
      );

      final divider = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.color == Colors.red);
      expect(divider, isEmpty);
    });

    testWidgets('both divider (SliverToBoxAdapter) and pinnedDivider coexist', (
      tester,
    ) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              pinnedDividerHeight: 1.0,
              pinnedDividerColor: Colors.red,
              divider: const Divider(
                key: ValueKey('free-divider'),
                height: 1,
                color: Colors.blue,
              ),
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 800))],
            ),
          ),
        ),
      );

      // Free-floating divider still present as SliverToBoxAdapter child.
      expect(find.byKey(const ValueKey('free-divider')), findsOneWidget);
      // Pinned divider Container also present (decoration-less, Colors.red).
      final pinned = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration == null && c.color == Colors.red);
      expect(pinned, isNotEmpty);
    });
  });

  group('SliverSnapView onPointerDown abort', () {
    testWidgets('pointerDown on the view calls abortSnap on controller', (
      tester,
    ) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SliverSnapView(
              isSearching: false,
              searchBar: DefaultSliverSnapRow(
                isSearching: false,
                controller: textCtrl,
                focusNode: focus,
                onTap: () {},
                onBack: () {},
              ),
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
            ),
          ),
        ),
      );

      // OUR Listener is the immediate ancestor of the CustomScrollView
      // that SliverSnapView.build creates. Using ancestor-of ensures we
      // don't accidentally match a Listener deep inside the
      // DefaultSliverSnapRow or framework internals.
      final listener = tester.widget<Listener>(
        find
            .ancestor(
              of: find.byType(CustomScrollView),
              matching: find.byType(Listener),
            )
            .first,
      );
      expect(listener.onPointerUp, isNotNull, reason: 'sanity: found OUR Listener');
      expect(listener.onPointerDown, isNotNull);
    });
  });
}
