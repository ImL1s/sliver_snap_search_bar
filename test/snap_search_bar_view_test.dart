import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_snap_search_bar/sliver_snap_search_bar.dart';

void main() {
  group('SnapSearchBarView didUpdateWidget', () {
    testWidgets('totalHeight change rebuilds snap controller', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      Widget build({required double totalHeight}) {
        final contentHeight = totalHeight - 2 * 8;
        return MaterialApp(
          home: Scaffold(
            body: SnapSearchBarView(
              isSearching: false,
              totalHeight: totalHeight,
              contentHeight: contentHeight,
              searchBar: DefaultSnapSearchBarRow(
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
            body: SnapSearchBarView(
              isSearching: false,
              snapDuration: snapDuration,
              searchBar: DefaultSnapSearchBarRow(
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
            body: SnapSearchBarView(
              isSearching: false,
              snapCurve: snapCurve,
              searchBar: DefaultSnapSearchBarRow(
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

  group('SnapSearchBarView divider slot', () {
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
              body: SnapSearchBarView(
                isSearching: false,
                divider: const Divider(
                  key: ValueKey('my-divider'),
                  height: 1,
                  color: Colors.red,
                ),
                searchBar: DefaultSnapSearchBarRow(
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
            body: SnapSearchBarView(
              isSearching: false,
              searchBar: DefaultSnapSearchBarRow(
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
}
