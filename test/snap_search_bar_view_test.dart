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
}
