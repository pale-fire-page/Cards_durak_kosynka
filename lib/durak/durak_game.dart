import 'dart:math';

/// Логика дурака (подкидной и переводной, 36 карт) без привязки к интерфейсу.

enum DurakMode { podkidnoy, perevodnoy }

class DCard {
  /// 0 ♠, 1 ♥, 2 ♦, 3 ♣
  final int suit;

  /// 6 … 14 (туз)
  final int rank;
  const DCard(this.suit, this.rank);

  bool get isRed => suit == 1 || suit == 2;
  int get id => suit * 20 + rank;

  static const suits = ['♠', '♥', '♦', '♣'];
  String get rankLabel => const {11: 'J', 12: 'Q', 13: 'K', 14: 'A'}[rank] ?? '$rank';
  @override
  bool operator ==(Object other) => other is DCard && other.suit == suit && other.rank == rank;
  @override
  int get hashCode => id;
  @override
  String toString() => '$rankLabel${suits[suit]}';
}

class TablePair {
  final DCard attack;
  DCard? defense;
  TablePair(this.attack, [this.defense]);
}

class DurakPlayer {
  final String name;
  final bool human;
  final List<DCard> hand = [];
  bool out = false;

  /// Реплика над игроком: «Беру», «Бито», «Пас», «Перевод».
  String say = '';
  DurakPlayer(this.name, {this.human = false});
}

enum ActKind { attack, defend, throwIn, end }

class Turn {
  final ActKind kind;
  final int who;
  const Turn(this.kind, [this.who = -1]);
}

class DurakGame {
  final DurakMode mode;
  final Random rng;
  late List<DurakPlayer> players;
  late List<DCard> talon; // берём с конца, talon[0] — открытый козырь
  late DCard trumpCard;
  late int trump;
  final List<DCard> discard = [];
  final List<TablePair> table = [];
  int attacker = 0, defender = 1;
  bool taking = false;
  bool firstBout = true;
  final Set<int> passed = {};
  bool over = false;

  /// Индекс дурака после конца партии, null — ничья.
  int? durak;
  String note = '';

  DurakGame({int opponents = 2, this.mode = DurakMode.podkidnoy, Random? rng, bool allBots = false})
      : rng = rng ?? Random() {
    players = [
      DurakPlayer('Вы', human: !allBots),
      for (var i = 1; i <= opponents; i++) DurakPlayer(opponents == 1 ? 'Бот' : 'Бот $i'),
    ];
    final deck = [for (var s = 0; s < 4; s++) for (var r = 6; r <= 14; r++) DCard(s, r)]..shuffle(this.rng);
    for (var k = 0; k < 6; k++) {
      for (final p in players) {
        p.hand.add(deck.removeLast());
      }
    }
    talon = deck;
    trumpCard = deck.first;
    trump = trumpCard.suit;
    // Первым ходит обладатель младшего козыря.
    int? bi;
    DCard? best;
    for (var i = 0; i < players.length; i++) {
      for (final c in players[i].hand) {
        if (c.suit == trump && (best == null || c.rank < best.rank)) {
          best = c;
          bi = i;
        }
      }
    }
    attacker = bi ?? this.rng.nextInt(players.length);
    defender = nextActive(attacker);
    if (best != null) note = 'Младший козырь $best у ${bi == 0 && !allBots ? 'вас' : players[bi!].name}';
  }

  DurakPlayer p(int i) => players[i];

  int nextActive(int i) {
    final n = players.length;
    for (var k = 1; k <= n; k++) {
      final j = (i + k) % n;
      if (!players[j].out) return j;
    }
    return i;
  }

  bool beats(DCard a, DCard d) => (d.suit == a.suit && d.rank > a.rank) || (d.suit == trump && a.suit != trump);
  List<int> get undefended => [for (var i = 0; i < table.length; i++) if (table[i].defense == null) i];
  int get limit => firstBout ? 5 : 6;
  List<DCard> get tableCards => [for (final t in table) ...[t.attack, if (t.defense != null) t.defense!]];
  Set<int> get tableRanks => tableCards.map((c) => c.rank).toSet();

  bool canThrow(DCard c) {
    if (table.isEmpty || !tableRanks.contains(c.rank)) return false;
    return table.length < limit && undefended.length < players[defender].hand.length;
  }

  bool canTransfer(DCard c) {
    if (mode != DurakMode.perevodnoy || taking || table.isEmpty || table.any((t) => t.defense != null)) return false;
    if (c.rank != table.first.attack.rank || table.length + 1 > limit) return false;
    final nd = nextActive(defender);
    return nd != defender && players[nd].hand.length >= table.length + 1;
  }

  /// Подкидывающие: с главного атакующего по кругу, кроме отбивающегося.
  List<int> get attackers {
    final n = players.length;
    return [
      for (var k = 0; k < n; k++)
        if ((attacker + k) % n != defender && !players[(attacker + k) % n].out) (attacker + k) % n
    ];
  }

  Turn? whoActs() {
    if (over) return null;
    if (table.isEmpty) return Turn(ActKind.attack, attacker);
    if (undefended.isNotEmpty && !taking) return Turn(ActKind.defend, defender);
    for (final a in attackers) {
      if (!passed.contains(a) && players[a].hand.any(canThrow)) return Turn(ActKind.throwIn, a);
    }
    return const Turn(ActKind.end);
  }

  // ---------- Действия ----------

  void _remove(int i, DCard c) => players[i].hand.remove(c);

  /// Первый ход или подкидывание.
  void attack(int i, DCard c) {
    _remove(i, c);
    table.add(TablePair(c));
    passed.clear();
    players[i].say = '';
  }

  void defend(DCard c, int idx) {
    _remove(defender, c);
    table[idx].defense = c;
    passed.clear();
  }

  void transfer(DCard c) {
    _remove(defender, c);
    table.add(TablePair(c));
    players[defender].say = 'Перевод';
    attacker = defender;
    defender = nextActive(defender);
    passed.clear();
  }

  void take() {
    taking = true;
    passed.clear();
    players[defender].say = 'Беру';
  }

  void pass(int i) {
    passed.add(i);
    players[i].say = taking ? 'Хватит' : (i == attacker ? 'Бито' : 'Пас');
  }

  void endBout() {
    final cards = tableCards;
    final d = defender;
    final me = !players[d].human ? players[d].name : null;
    int next;
    if (taking) {
      players[d].hand.addAll(cards);
      note = me == null ? 'Вы взяли ${cards.length} ${_plural(cards.length)}' : '$me взял ${cards.length} ${_plural(cards.length)}';
      next = nextActive(d);
    } else {
      discard.addAll(cards);
      note = me == null ? 'Вы отбились' : '$me отбился';
      next = d;
    }
    // Добор: главный атакующий, остальные по кругу, отбивающийся последним.
    for (final i in [...attackers, d]) {
      while (players[i].hand.length < 6 && talon.isNotEmpty) {
        players[i].hand.add(talon.removeLast());
      }
    }
    table.clear();
    taking = false;
    passed.clear();
    firstBout = false;
    for (final pl in players) {
      pl.say = '';
    }
    if (talon.isEmpty) {
      for (final pl in players) {
        if (!pl.out && pl.hand.isEmpty) pl.out = true;
      }
    }
    final active = [for (var i = 0; i < players.length; i++) if (!players[i].out) i];
    if (active.length <= 1) {
      over = true;
      durak = active.isEmpty ? null : active.first;
      return;
    }
    attacker = players[next].out ? nextActive(next) : next;
    defender = nextActive(attacker);
  }

  static String _plural(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'карту';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'карты';
    return 'карт';
  }

  // ---------- Бот («нормальный») ----------

  int cost(DCard c) => c.rank + (c.suit == trump ? 20 : 0);

  /// Карты, которых бот не видел: не у него, не в отбое и не на столе.
  List<DCard> unseen(int i) {
    final known = {...players[i].hand, ...discard, ...tableCards, if (talon.isNotEmpty) trumpCard};
    return [for (var s = 0; s < 4; s++) for (var r = 6; r <= 14; r++) if (!known.contains(DCard(s, r))) DCard(s, r)];
  }

  DCard botAttack(int i) {
    final h = [...players[i].hand];
    if (talon.isEmpty && h.length <= 3) {
      // Добивание: карта, которую соперникам нечем побить (по памяти), иначе младшая.
      final u = unseen(i);
      int threat(DCard c) => u.where((x) => beats(c, x)).length;
      h.sort((a, b) => threat(a) != threat(b) ? threat(a) - threat(b) : cost(a) - cost(b));
    } else {
      // Пара одного достоинства выгоднее: потом можно подкинуть вторую.
      int score(DCard c) => cost(c) - 2 * (h.where((x) => x.rank == c.rank).length - 1);
      h.sort((a, b) => score(a) - score(b));
    }
    return h.first;
  }

  DCard? botThrow(int i) {
    var cand = players[i].hand.where(canThrow).toList()..sort((a, b) => cost(a) - cost(b));
    if (talon.isNotEmpty) {
      cand = cand.where((c) => c.suit != trump && c.rank <= (taking ? 10 : 12)).toList();
    } else if (cand.any((c) => c.suit != trump)) {
      cand = cand.where((c) => c.suit != trump).toList();
    }
    return cand.isEmpty ? null : cand.first;
  }

  /// План отбоя: каждой неотбитой карте — самая дешёвая бьющая. null — отбиться нечем.
  List<(int, DCard)>? defensePlan(int i) {
    final pool = [...players[i].hand]..sort((a, b) => cost(a) - cost(b));
    final idxs = undefended..sort((a, b) => cost(table[b].attack) - cost(table[a].attack));
    final plan = <(int, DCard)>[];
    for (final idx in idxs) {
      final k = pool.indexWhere((c) => beats(table[idx].attack, c));
      if (k < 0) return null;
      plan.add((idx, pool.removeAt(k)));
    }
    return plan;
  }

  void botAct(Turn t) {
    final i = t.who;
    switch (t.kind) {
      case ActKind.attack:
        attack(i, botAttack(i));
      case ActKind.throwIn:
        final c = botThrow(i);
        c == null ? pass(i) : attack(i, c);
      case ActKind.defend:
        final tr = players[i].hand.where(canTransfer).toList()..sort((a, b) => cost(a) - cost(b));
        if (tr.isNotEmpty && (tr.first.suit != trump || talon.isEmpty)) {
          transfer(tr.first);
          return;
        }
        final plan = defensePlan(i);
        if (plan == null) {
          take();
          return;
        }
        // Пока колода большая, не отдаём старшие козыри за мелочь.
        final expensive = plan.any((e) => e.$2.suit == trump && e.$2.rank >= 12 && table[e.$1].attack.suit != trump);
        if (expensive && talon.length >= 8 && table.length <= 2) {
          take();
          return;
        }
        defend(plan.first.$2, plan.first.$1);
      case ActKind.end:
        endBout();
    }
  }
}
