import 'dart:math';
import 'package:cards/durak/durak_game.dart';
import 'package:flutter_test/flutter_test.dart';

const s = 0, h = 1, d = 2, c = 3; // ♠ ♥ ♦ ♣

/// Партия с заданными руками: козырь ♣, колода пуста, ход игрока 0 на игрока 1.
DurakGame setup(List<List<DCard>> hands, {DurakMode mode = DurakMode.podkidnoy, int trump = c}) {
  final g = DurakGame(opponents: hands.length - 1, mode: mode, rng: Random(1));
  for (var i = 0; i < hands.length; i++) {
    g.players[i].hand
      ..clear()
      ..addAll(hands[i]);
  }
  g.talon.clear();
  g.trump = trump;
  g.attacker = 0;
  g.defender = 1;
  g.firstBout = false;
  return g;
}

int totalCards(DurakGame g) =>
    g.talon.length + g.discard.length + g.tableCards.length + g.players.fold(0, (a, p) => a + p.hand.length);

void main() {
  test('раздача: по 6 карт, 36 карт всего, козырь — нижняя карта колоды', () {
    for (final n in [1, 2, 3]) {
      final g = DurakGame(opponents: n, rng: Random(n));
      expect(g.players.length, n + 1);
      expect(g.players.every((p) => p.hand.length == 6), isTrue);
      expect(totalCards(g), 36);
      expect(g.trump, g.talon.first.suit);
      expect(g.defender, g.nextActive(g.attacker));
    }
  });

  test('первым ходит обладатель младшего козыря', () {
    final g = DurakGame(opponents: 3, rng: Random(7));
    final trumps = [
      for (var i = 0; i < 4; i++)
        for (final x in g.players[i].hand)
          if (x.suit == g.trump) (i, x.rank)
    ]..sort((a, b) => a.$2 - b.$2);
    if (trumps.isNotEmpty) expect(g.attacker, trumps.first.$1);
  });

  test('бьётся старшей той же масти или козырем', () {
    final g = setup([[], []]);
    expect(g.beats(const DCard(h, 7), const DCard(h, 9)), isTrue);
    expect(g.beats(const DCard(h, 9), const DCard(h, 7)), isFalse);
    expect(g.beats(const DCard(h, 14), const DCard(c, 6)), isTrue);
    expect(g.beats(const DCard(c, 8), const DCard(c, 6)), isFalse);
    expect(g.beats(const DCard(h, 7), const DCard(s, 14)), isFalse);
  });

  test('подкидывать можно только достоинства со стола и не больше карт отбивающегося', () {
    final g = setup([
      [const DCard(s, 7), const DCard(d, 7), const DCard(h, 7), const DCard(s, 10)],
      [const DCard(h, 9), const DCard(c, 14)],
    ]);
    g.attack(0, const DCard(s, 7));
    expect(g.canThrow(const DCard(s, 10)), isFalse);
    expect(g.canThrow(const DCard(d, 7)), isTrue);
    g.attack(0, const DCard(d, 7));
    // У отбивающегося 2 карты и 2 неотбитые на столе — больше нельзя.
    expect(g.canThrow(const DCard(h, 7)), isFalse);
  });

  test('первый отбой — не больше 5 карт', () {
    final g = setup([
      [for (final x in [s, h, d]) DCard(x, 8), for (final x in [s, h, d]) DCard(x, 9)],
      [for (var r = 10; r <= 14; r++) DCard(c, r), const DCard(c, 6)],
    ]);
    g.firstBout = true;
    g.attack(0, const DCard(s, 8));
    g.defend(const DCard(c, 10), 0);
    g.attack(0, const DCard(h, 8));
    g.defend(const DCard(c, 11), 1);
    g.attack(0, const DCard(d, 8));
    g.defend(const DCard(c, 12), 2);
    // На столе 6, 8, 10, J, Q — подкидываем девятку? Девяток нет на столе.
    expect(g.canThrow(const DCard(s, 9)), isFalse);
    g.table.add(TablePair(const DCard(h, 12), const DCard(c, 13)));
    g.table.add(TablePair(const DCard(s, 12), const DCard(c, 14)));
    expect(g.table.length, 5);
    expect(g.canThrow(const DCard(s, 12)), isFalse);
  });

  test('бито: отбивающийся ходит следующим, карты уходят в отбой', () {
    final g = setup([
      [const DCard(s, 7), const DCard(h, 6)],
      [const DCard(s, 9), const DCard(h, 13)],
      [const DCard(d, 6), const DCard(d, 10)],
    ]);
    g.attack(0, const DCard(s, 7));
    g.defend(const DCard(s, 9), 0);
    expect(g.whoActs()!.kind, ActKind.end);
    g.endBout();
    expect(g.discard.length, 2);
    expect(g.attacker, 1);
    expect(g.defender, 2);
  });

  test('взял — пропускает ход, подкинутое вдогонку уходит к нему', () {
    final g = setup([
      [const DCard(s, 7), const DCard(h, 7), const DCard(h, 6)],
      [const DCard(s, 6), const DCard(d, 13)],
      [const DCard(d, 7), const DCard(d, 8)],
    ]);
    g.attack(0, const DCard(s, 7));
    g.take();
    expect(g.whoActs()!.kind, ActKind.throwIn);
    g.attack(0, const DCard(h, 7));
    // У отбивающегося 2 карты и 2 неотбитые — больше подкидывать нельзя.
    expect(g.canThrow(const DCard(d, 7)), isFalse);
    expect(g.whoActs()!.kind, ActKind.end);
    g.endBout();
    expect(g.players[1].hand.length, 4);
    expect(g.attacker, 2);
    expect(g.defender, 0);
  });

  test('перевод: карта того же достоинства, следующий становится отбивающимся', () {
    final g = setup([
      [const DCard(s, 7), const DCard(h, 6)],
      [const DCard(h, 7), const DCard(d, 13)],
      [const DCard(d, 6), const DCard(d, 8), const DCard(s, 8)],
    ], mode: DurakMode.perevodnoy);
    g.attack(0, const DCard(s, 7));
    expect(g.canTransfer(const DCard(h, 7)), isTrue);
    expect(g.canTransfer(const DCard(d, 13)), isFalse);
    g.transfer(const DCard(h, 7));
    expect(g.attacker, 1);
    expect(g.defender, 2);
    expect(g.table.length, 2);
  });

  test('в подкидном переводить нельзя; нельзя переводить на того, у кого мало карт', () {
    final g = setup([
      [const DCard(s, 7), const DCard(h, 6)],
      [const DCard(h, 7), const DCard(d, 13)],
      [const DCard(d, 6)],
    ]);
    g.attack(0, const DCard(s, 7));
    expect(g.canTransfer(const DCard(h, 7)), isFalse);
    final g2 = setup([
      [const DCard(s, 7), const DCard(h, 6)],
      [const DCard(h, 7), const DCard(d, 13)],
      [const DCard(d, 6)],
    ], mode: DurakMode.perevodnoy);
    g2.attack(0, const DCard(s, 7));
    expect(g2.canTransfer(const DCard(h, 7)), isFalse);
  });

  test('конец партии: последний с картами — дурак', () {
    final g = setup([
      [const DCard(s, 7)],
      [const DCard(s, 9), const DCard(h, 6)],
    ]);
    g.attack(0, const DCard(s, 7));
    g.defend(const DCard(s, 9), 0);
    g.endBout();
    expect(g.over, isTrue);
    expect(g.durak, 1);
  });

  test('боты доигрывают тысячи партий без ошибок и зацикливаний', () {
    for (final mode in DurakMode.values) {
      for (final n in [1, 2, 3]) {
        for (var k = 0; k < 150; k++) {
          final g = DurakGame(opponents: n, mode: mode, rng: Random(k * 7 + n), allBots: true);
          var steps = 0;
          while (!g.over && steps < 5000) {
            steps++;
            g.botAct(g.whoActs()!);
            expect(totalCards(g), 36);
            expect(g.table.length, lessThanOrEqualTo(6));
            for (final t in g.table) {
              if (t.defense != null) expect(g.beats(t.attack, t.defense!), isTrue);
            }
          }
          expect(g.over, isTrue, reason: 'партия $mode/$n/$k зациклилась');
        }
      }
    }
  });
}
