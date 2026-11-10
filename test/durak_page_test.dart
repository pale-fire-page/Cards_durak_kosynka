import 'package:cards/durak/durak_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final opp in [1, 3]) {
    testWidgets('экран дурака на телефоне: $opp ботов, партия идёт без ошибок раскладки', (tester) async {
      SharedPreferences.setMockInitialValues({'durak.opp': opp, 'durak.mode': 'perevodnoy'});
      tester.view.physicalSize = const Size(360 * 3, 760 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: DurakPage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Переводной'), findsOneWidget);
      // Играем: жмём на первую доступную кнопку или карту, пока идёт партия.
      for (var k = 0; k < 400; k++) {
        if (find.text('Ещё партию').evaluate().isNotEmpty) break;
        Finder b(String t) => find.widgetWithText(FilledButton, t);
        final take = b('Беру'), done = b('Бито'), pass = b('Пас'), enough = b('Хватит');
        final status = find.textContaining('Ваш ход');
        if (status.evaluate().isNotEmpty) {
          await tester.tapAt(tester.getCenter(find.byType(GestureDetector).last));
        } else if (take.evaluate().isNotEmpty) {
          await tester.tap(take);
        } else {
          for (final f in [done, pass, enough]) {
            if (f.evaluate().isNotEmpty) await tester.tap(f);
          }
        }
        await tester.pump(const Duration(milliseconds: 1000));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
