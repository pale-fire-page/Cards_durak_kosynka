import 'dart:math';
import 'package:cards/klondike/klondike_game.dart';
import 'package:flutter_test/flutter_test.dart';

PlayingCard c(int s, int r, [bool up = true]) => PlayingCard(s, r, faceUp: up);

KlondikeGame emptyGame({int draw = 1}) {
  final g = KlondikeGame(drawCount: draw, rng: Random(1));
  g.s = KlondikeState();
  return g;
}

void main() {
  test('раздача: 28 карт на столе, 24 в колоде, открыты только верхние', () {
    final g = KlondikeGame(rng: Random(42));
    for (var i = 0; i < 7; i++) {
      expect(g.s.tableau[i].length, i + 1);
      expect(g.s.tableau[i].last.faceUp, isTrue);
      expect(g.s.tableau[i].where((x) => x.faceUp).length, 1);
    }
    expect(g.s.stock.length, 24);
    final ids = {...g.s.stock.map((x) => x.id), for (final t in g.s.tableau) ...t.map((x) => x.id)};
    expect(ids.length, 52);
  });

  test('ход на стол: чередование цвета и убывание', () {
    final g = emptyGame();
    g.s.tableau[0] = [c(1, 8)]; // 8♥
    g.s.tableau[1] = [c(0, 7)]; // 7♠
    g.s.tableau[2] = [c(2, 7)]; // 7♦
    expect(g.move(const PileRef.tableau(2), 0, const PileRef.tableau(0)), isFalse);
    expect(g.move(const PileRef.tableau(1), 0, const PileRef.tableau(0)), isTrue);
  });

  test('на пустую колонку только король', () {
    final g = emptyGame();
    g.s.tableau[0] = [c(0, 12)];
    g.s.tableau[1] = [c(0, 13)];
    expect(g.move(const PileRef.tableau(0), 0, const PileRef.tableau(2)), isFalse);
    expect(g.move(const PileRef.tableau(1), 0, const PileRef.tableau(2)), isTrue);
  });

  test('очки: сброс→стол +5, в дом +10, открытие +5, из дома −15', () {
    final g = emptyGame();
    g.s.waste = [c(0, 1)];
    g.autoMove(PileRef.waste, 0);
    expect(g.s.score, 10);
    g.s.tableau[0] = [c(1, 5, false), c(1, 2)];
    g.autoMove(const PileRef.tableau(0), 1); // 2♥ никуда, кроме... дом ♥ пуст
    expect(g.s.score, 10);
    g.s.tableau[0] = [c(1, 5, false), c(0, 2)];
    expect(g.move(const PileRef.tableau(0), 1, const PileRef.foundation(0)), isTrue);
    expect(g.s.score, 25); // +10 и +5 за открытие
    g.s.tableau[1] = [c(1, 3)];
    expect(g.move(const PileRef.foundation(0), 1, const PileRef.tableau(1)), isTrue);
    expect(g.s.score, 10);
  });

  test('отмена: возвращает ход и отключает очки до новой игры', () {
    final g = emptyGame();
    g.s.waste = [c(0, 1)];
    g.autoMove(PileRef.waste, 0);
    expect(g.undo(), isTrue);
    expect(g.s.waste.length, 1);
    expect(g.scoring, isFalse);
    g.autoMove(PileRef.waste, 0);
    expect(g.scoring, isFalse);
    g.newGame();
    expect(g.scoring, isTrue);
  });

  test('отмена возможна до самого начала игры', () {
    final g = KlondikeGame(rng: Random(3));
    final first = g.s.stock.map((x) => x.id).toList();
    for (var i = 0; i < 10; i++) {
      g.clickStock();
    }
    while (g.undo()) {}
    expect(g.s.stock.map((x) => x.id).toList(), first);
    expect(g.s.waste, isEmpty);
  });

  test('первое пролистывание колоды бесплатно, дальше штраф', () {
    final g = emptyGame();
    g.s.stock = [c(0, 5, false)];
    g.s.score = 200;
    g.clickStock(); // сдали
    g.clickStock(); // 1-е пролистывание
    expect(g.s.score, 200);
    g.clickStock();
    g.clickStock(); // 2-е
    expect(g.s.score, 100);

    final g3 = emptyGame(draw: 3);
    g3.s.stock = [c(0, 5, false)];
    g3.s.score = 200;
    for (var i = 0; i < 4; i++) {
      g3.clickStock();
    }
    expect(g3.s.score, 180);
  });

  test('сдача по 3 карты', () {
    final g = KlondikeGame(drawCount: 3, rng: Random(5));
    g.clickStock();
    expect(g.s.waste.length, 3);
    expect(g.s.stock.length, 21);
  });

  test('время: −2 очка каждые 10 секунд, не ниже нуля', () {
    final g = emptyGame();
    g.s.waste = [c(0, 1)];
    g.autoMove(PileRef.waste, 0); // 10 очков, игра началась
    for (var i = 0; i < 20; i++) {
      g.tick();
    }
    expect(g.s.score, 6);
    for (var i = 0; i < 100; i++) {
      g.tick();
    }
    expect(g.s.score, 0);
  });

  test('авторасклад доводит до победы, когда всё открыто', () {
    final g = emptyGame();
    final all = [for (var s = 0; s < 4; s++) for (var r = 1; r <= 13; r++) c(s, r)];
    g.s.stock = all.where((x) => x.rank <= 4).toList().reversed.map((x) => x..faceUp = false).toList();
    const pairs = [[0, 1], [1, 0], [3, 2], [2, 3]];
    for (var i = 0; i < 4; i++) {
      for (var r = 13; r >= 5; r--) {
        g.s.tableau[i].add(c(r.isOdd ? pairs[i][0] : pairs[i][1], r));
      }
    }
    expect(g.canAutoFinish, isTrue);
    g.beginAutoFinish();
    var steps = 0;
    while (g.autoFinishStep()) {
      steps++;
      expect(steps, lessThan(1000));
    }
    expect(g.won, isTrue);
    expect(g.s.foundations.every((f) => f.length == 13), isTrue);
  });

  test('победа даёт бонус за время', () {
    final g = emptyGame();
    for (var s = 0; s < 4; s++) {
      g.s.foundations[s] = [for (var r = 1; r <= 13; r++) c(s, r)];
    }
    final k = g.s.foundations[3].removeLast();
    g.s.tableau[0] = [k];
    g.started = true;
    g.seconds = 100;
    g.autoMove(const PileRef.tableau(0), 0);
    expect(g.won, isTrue);
    expect(g.s.score, 10 + 7000);
  });
}
