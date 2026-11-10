# Карты: Дурак и Косынка

Android-приложение на Flutter: пасьянс «Косынка» и «Дурак» против приложения (1–3 соперника).

- `lib/klondike/klondike_game.dart` — правила косынки (без интерфейса), тесты в `test/`.
- `lib/klondike/klondike_page.dart` — игровой экран.
- `lib/durak/durak_game.dart` — правила дурака (подкидной и переводной) и боты, `lib/durak/durak_page.dart` — экран.
- `prototype/klondike.html`, `prototype/durak.html` — HTML-прототипы для обсуждения, открываются в браузере.

Запуск тестов: `flutter test`. Сборка APK: `flutter build apk --release`.
