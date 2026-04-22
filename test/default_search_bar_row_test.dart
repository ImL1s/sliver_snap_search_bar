import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sliver_snap_search_bar/sliver_snap_search_bar.dart';

void main() {
  group('DefaultSnapSearchBarRow style params', () {
    testWidgets('pillDecoration overrides pillColor', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      final deco = BoxDecoration(
        color: Colors.pink,
        border: Border.all(width: 2, color: Colors.deepPurple),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultSnapSearchBarRow(
              isSearching: false,
              controller: textCtrl,
              focusNode: focus,
              onTap: () {},
              onBack: () {},
              pillDecoration: deco,
            ),
          ),
        ),
      );

      final container = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.decoration is BoxDecoration);
      expect(container.decoration, deco);
    });

    testWidgets('hintStyle overrides theme default on TextField', (
      tester,
    ) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultSnapSearchBarRow(
              isSearching: true,
              controller: textCtrl,
              focusNode: focus,
              onTap: () {},
              onBack: () {},
              hintStyle: const TextStyle(fontSize: 99),
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintStyle?.fontSize, 99);
    });

    testWidgets('cancelStyle forwards to cancel button Text', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      const cancelTs = TextStyle(fontSize: 77, color: Colors.orange);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultSnapSearchBarRow(
              isSearching: true,
              controller: textCtrl,
              focusNode: focus,
              onTap: () {},
              onBack: () {},
              cancelStyle: cancelTs,
            ),
          ),
        ),
      );

      final cancelText = tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => t.data == 'Cancel');
      expect(cancelText.style?.fontSize, 77);
      expect(cancelText.style?.color, Colors.orange);
    });

    testWidgets('cursorColor forwards to TextField', (tester) async {
      final textCtrl = TextEditingController();
      final focus = FocusNode();
      addTearDown(textCtrl.dispose);
      addTearDown(focus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultSnapSearchBarRow(
              isSearching: true,
              controller: textCtrl,
              focusNode: focus,
              onTap: () {},
              onBack: () {},
              cursorColor: Colors.red,
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.cursorColor, Colors.red);
    });
  });
}
