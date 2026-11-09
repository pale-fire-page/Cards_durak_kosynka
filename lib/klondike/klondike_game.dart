import 'dart:math';

/// Логика косынки без привязки к интерфейсу.

enum PileType { stock, waste, foundation, tableau }

class PileRef {
  final PileType type;
  final int index;
  const PileRef(this.type, [this.index = 0]);

  static const stock = PileRef(PileType.stock);
  static const waste = PileRef(PileType.waste);
  const PileRef.foundation(int i) : this(PileType.foundation, i);
  const PileRef.tableau(int i) : this(PileType.tableau, i);

  @override
  bool operator ==(Object other) =>
      other is PileRef && other.type == type && other.index == index;
  @override
  int get hashCode => Object.hash(type, index);
  @override
  String toString() => '$type[$index]';
}

class PlayingCard {
  /// 0 ♠, 1 ♥, 2 ♦, 3 ♣
  final int suit;

  /// 1 (туз) … 13 (король)
  final int rank;
  bool faceUp;

  PlayingCard(this.suit, this.rank, {this.faceUp = false});

  int get id => suit * 13 + rank;
  bool get isRed => suit == 1 || suit == 2;
  PlayingCard copy() => PlayingCard(suit, rank, faceUp: faceUp);

  static const suits = ['♠', '♥', '♦', '♣'];
  static const ranks = ['', 'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  String get suitLabel => suits[suit];
  String get rankLabel => ranks[rank];
  @override
  String toString() => '$rankLabel$suitLabel${faceUp ? '' : '*'}';
}

class KlondikeState {
  List<PlayingCard> stock = [];
  List<PlayingCard> waste = [];
  List<List<PlayingCard>> foundations = List.generate(4, (_) => []);
  List<List<PlayingCard>> tableau = List.generate(7, (_) => []);
  int score = 0;
  int recycles = 0;

  KlondikeState();

  KlondikeState copy() {
    List<PlayingCard> c(List<PlayingCard> l) => l.map((e) => e.copy()).toList();
    return KlondikeState()
      ..stock = c(stock)
      ..waste = c(waste)
      ..foundations = foundations.map(c).toList()
      ..tableau = tableau.map(c).toList()
      ..score = score
      ..recycles = recycles;
  }
}

class KlondikeGame {
  int drawCount;
  final Random _rng;

  late KlondikeState s;
  final List<KlondikeState> _history = [];

  /// Очки считаются до первой отмены хода.
  bool scoring = true;
  int seconds = 0;
  bool started = false;
  bool won = false;
  int _autoIdle = 0;

  KlondikeGame({this.drawCount = 1, Random? rng}) : _rng = rng ?? Random() {
    newGame();
  }

  void newGame() {
    final deck = [
      for (var suit = 0; suit < 4; suit++)
        for (var rank = 1; rank <= 13; rank++) PlayingCard(suit, rank)
    ]..shuffle(_rng);
    s = KlondikeState();
    for (var i = 0; i < 7; i++) {
      for (var j = 0; j <= i; j++) {
        s.tableau[i].add(deck.removeLast()..faceUp = j == i);
      }
    }
    s.stock = deck;
    _history.clear();
    scoring = true;
    seconds = 0;
    started = false;
    won = false;
  }

  bool get canUndo => _history.isNotEmpty && !won;

  List<PlayingCard> pile(PileRef p) => switch (p.type) {
        PileType.stock => s.stock,
        PileType.waste => s.waste,
        PileType.foundation => s.foundations[p.index],
        PileType.tableau => s.tableau[p.index],
      };

  bool canPlaceOnFoundation(PlayingCard c, int i) {
    final f = s.foundations[i];
    if (f.isEmpty) return c.rank == 1;
    return f.last.suit == c.suit && f.last.rank + 1 == c.rank;
  }

  bool canPlaceOnTableau(PlayingCard c, int i) {
    final t = s.tableau[i];
    if (t.isEmpty) return c.rank == 13;
    final top = t.last;
    return top.faceUp && top.isRed != c.isRed && top.rank == c.rank + 1;
  }

  /// Можно ли взять карты [idx..] из стопки (для тапа и перетаскивания).
  bool canPick(PileRef src, int idx) {
    final from = pile(src);
    if (won || idx < 0 || idx >= from.length || !from[idx].faceUp) return false;
    return switch (src.type) {
      PileType.stock => false,
      PileType.waste || PileType.foundation => idx == from.length - 1,
      PileType.tableau => true,
    };
  }

  bool canMove(PileRef src, int idx, PileRef dst) {
    if (src == dst || !canPick(src, idx)) return false;
    final from = pile(src);
    final card = from[idx];
    return switch (dst.type) {
      PileType.foundation => idx == from.length - 1 && canPlaceOnFoundation(card, dst.index),
      PileType.tableau => canPlaceOnTableau(card, dst.index),
      _ => false,
    };
  }

  void _addScore(int n) {
    if (scoring) s.score = max(0, s.score + n);
  }

  void _begin() {
    _history.add(s.copy());
    started = true;
  }

  /// Ход карт [idx..] из src в dst. Возвращает true, если ход сделан.
  bool move(PileRef src, int idx, PileRef dst) {
    if (!canMove(src, idx, dst)) return false;
    _begin();
    final from = pile(src);
    final cards = from.sublist(idx);
    from.removeRange(idx, from.length);
    pile(dst).addAll(cards);

    final fromWaste = src.type == PileType.waste;
    final fromTab = src.type == PileType.tableau;
    if (fromWaste && dst.type == PileType.tableau) _addScore(5);
    if ((fromWaste || fromTab) && dst.type == PileType.foundation) _addScore(10);
    if (src.type == PileType.foundation && dst.type == PileType.tableau) _addScore(-15);
    if (fromTab && from.isNotEmpty && !from.last.faceUp) {
      from.last.faceUp = true;
      _addScore(5);
    }
    _checkWin();
    return true;
  }

  /// Тап по карте: сначала в дом, потом на стол (сначала на непустые колонки).
  bool autoMove(PileRef src, int idx) {
    if (src.type != PileType.foundation) {
      for (var i = 0; i < 4; i++) {
        if (move(src, idx, PileRef.foundation(i))) return true;
      }
    }
    final order = List.generate(7, (i) => i)
      ..sort((a, b) => (s.tableau[a].isEmpty ? 1 : 0) - (s.tableau[b].isEmpty ? 1 : 0));
    for (final i in order) {
      if (move(src, idx, PileRef.tableau(i))) return true;
    }
    return false;
  }

  void _draw() {
    for (var k = 0; k < drawCount && s.stock.isNotEmpty; k++) {
      s.waste.add(s.stock.removeLast()..faceUp = true);
    }
  }

  void _recycle() {
    s.stock = s.waste.reversed.map((c) => c..faceUp = false).toList();
    s.waste = [];
  }

  /// Тап по колоде: сдать карты или перевернуть сброс обратно.
  bool clickStock() {
    if (won) return false;
    if (s.stock.isNotEmpty) {
      _begin();
      _draw();
      return true;
    }
    if (s.waste.isNotEmpty) {
      _begin();
      _recycle();
      // Первое пролистывание бесплатно, штраф со второго.
      if (s.recycles++ > 0) _addScore(drawCount == 1 ? -100 : -20);
      return true;
    }
    return false;
  }

  /// Отмена хода. Первая отмена отключает очки до новой игры.
  bool undo() {
    if (!canUndo) return false;
    scoring = false;
    s = _history.removeLast();
    return true;
  }

  /// Вызывается раз в секунду.
  void tick() {
    if (!started || won) return;
    seconds++;
    if (seconds % 10 == 0) _addScore(-2);
  }

  int get timeBonus => scoring && seconds >= 30 ? (700000 / seconds).round() : 0;

  void _checkWin() {
    if (s.foundations.every((f) => f.length == 13)) {
      won = true;
      s.score += timeBonus;
    }
  }

  // ---------- Авторасклад ----------

  /// На столе не осталось закрытых карт.
  bool get allRevealed => s.tableau.every((col) => col.every((c) => c.faceUp));

  bool get canAutoFinish => !won && allRevealed;

  /// Начать авторасклад (одна запись в истории на весь авторасклад).
  void beginAutoFinish() {
    _begin();
    _autoIdle = 0;
  }

  /// Один шаг авторасклада. false — закончили (победа или тупик).
  bool autoFinishStep() {
    if (won) return false;
    final sources = [PileRef.waste, for (var i = 0; i < 7; i++) PileRef.tableau(i)];
    for (final src in sources) {
      final from = pile(src);
      if (from.isEmpty) continue;
      for (var i = 0; i < 4; i++) {
        if (canPlaceOnFoundation(from.last, i)) {
          s.foundations[i].add(from.removeLast());
          _addScore(10);
          _autoIdle = 0;
          _checkWin();
          return true;
        }
      }
    }
    // В дом ничего не идёт: листаем колоду без штрафа.
    if (_autoIdle > s.stock.length + s.waste.length + 2) return false;
    _autoIdle++;
    if (s.stock.isNotEmpty) {
      _draw();
    } else if (s.waste.isNotEmpty) {
      _recycle();
    } else {
      return false;
    }
    return true;
  }
}
