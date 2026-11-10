import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/playing_card_view.dart';
import '../klondike/klondike_game.dart' show PlayingCard;
import 'durak_game.dart';

const _felt = Color(0xFF1E6B3A);
const _barColor = Color(0x40000000);
const _accent = Color(0xFFFFD54F);

/// Карта дурака в виде карты общего вида (туз у косынки — ранг 1).
PlayingCard _view(DCard c) => PlayingCard(c.suit, c.rank == 14 ? 1 : c.rank, faceUp: true);
final _back = PlayingCard(0, 1);

class DurakPage extends StatefulWidget {
  const DurakPage({super.key});

  @override
  State<DurakPage> createState() => _DurakPageState();
}

class _DurakPageState extends State<DurakPage> {
  int _opp = 2;
  DurakMode _mode = DurakMode.podkidnoy;
  int _games = 0, _lost = 0;
  DurakGame? _g;
  Timer? _timer;
  DCard? _sel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _opp = (p.getInt('durak.opp') ?? 2).clamp(1, 3);
      _mode = p.getString('durak.mode') == 'perevodnoy' ? DurakMode.perevodnoy : DurakMode.podkidnoy;
      _games = p.getInt('durak.games') ?? 0;
      _lost = p.getInt('durak.lost') ?? 0;
    } catch (_) {}
    _newGame();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('durak.opp', _opp);
      await p.setString('durak.mode', _mode.name);
      await p.setInt('durak.games', _games);
      await p.setInt('durak.lost', _lost);
    } catch (_) {}
  }

  void _newGame() {
    _timer?.cancel();
    _sel = null;
    setState(() => _g = DurakGame(opponents: _opp, mode: _mode));
    _step();
  }

  DurakGame get g => _g!;

  /// После каждого изменения: запускаем ход бота или конец отбоя, либо ждём человека.
  void _step() {
    _timer?.cancel();
    if (!mounted || g.over) return;
    final t = g.whoActs()!;
    final fast = g.players[0].out;
    if (t.kind == ActKind.end) {
      _timer = Timer(Duration(milliseconds: fast ? 400 : 900), () {
        setState(g.endBout);
        if (g.over) {
          _finish();
        } else {
          _step();
        }
      });
      return;
    }
    if (g.players[t.who].human) return;
    _timer = Timer(Duration(milliseconds: fast ? 250 : 700), () {
      setState(() => g.botAct(t));
      _step();
    });
  }

  void _finish() {
    _games++;
    if (g.durak == 0) _lost++;
    _save();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final d = g.durak;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(d == null ? 'Ничья' : d == 0 ? 'Вы дурак!' : 'Вы не дурак!', textAlign: TextAlign.center),
          content: Text(
            '${d == null ? 'Все вышли одновременно.' : d == 0 ? 'Карты остались только у вас.' : 'Дурак — ${g.players[d].name}.'}'
            '\n\nПартий $_games, в дураках $_lost',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c)..pop()..maybePop(), child: const Text('В меню')),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _newGame();
              },
              child: const Text('Ещё партию'),
            ),
          ],
        ),
      );
    });
  }

  // ---------- Ходы человека ----------

  void _human(void Function() f) {
    _sel = null;
    setState(f);
    _step();
  }

  void _tapHand(DCard c) {
    final t = g.whoActs();
    if (t == null || t.who != 0) return;
    switch (t.kind) {
      case ActKind.attack:
        _human(() => g.attack(0, c));
      case ActKind.throwIn:
        if (g.canThrow(c)) _human(() => g.attack(0, c));
      case ActKind.defend:
        final targets = g.undefended.where((i) => g.beats(g.table[i].attack, c)).toList();
        final tr = g.canTransfer(c);
        if (targets.length == 1 && !tr) {
          _human(() => g.defend(c, targets.first));
        } else if (targets.isEmpty && tr) {
          _human(() => g.transfer(c));
        } else if (targets.isNotEmpty || tr) {
          setState(() => _sel = _sel == c ? null : c);
        }
      case ActKind.end:
        break;
    }
  }

  void _tapTable(int idx) {
    final t = g.whoActs();
    final c = _sel;
    if (t == null || t.who != 0 || t.kind != ActKind.defend || c == null) return;
    final p = g.table[idx];
    if (p.defense == null && g.beats(p.attack, c)) _human(() => g.defend(c, idx));
  }

  Future<void> _confirmNew() async {
    if (g.over || g.players[0].out) {
      _newGame();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: const Text('Начать новую партию? Текущая не засчитается.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Продолжить')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Начать заново')),
        ],
      ),
    );
    if (ok == true) _newGame();
  }

  Future<void> _settings() async {
    var opp = _opp;
    var mode = _mode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Настройки'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Противников'),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
              ],
              selected: {opp},
              onSelectionChanged: (v) => set(() => opp = v.first),
            ),
            const SizedBox(height: 16),
            const Text('Правила'),
            const SizedBox(height: 6),
            SegmentedButton<DurakMode>(
              segments: const [
                ButtonSegment(value: DurakMode.podkidnoy, label: Text('Подкидной')),
                ButtonSegment(value: DurakMode.perevodnoy, label: Text('Переводной')),
              ],
              selected: {mode},
              onSelectionChanged: (v) => set(() => mode = v.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Новая партия')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    _opp = opp;
    _mode = mode;
    _save();
    _newGame();
  }

  // ---------- Отрисовка ----------

  Widget _bots(Turn? t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Row(children: [
        for (var i = 1; i < g.players.length; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(child: _botBox(i, t)),
        ],
      ]),
    );
  }

  Widget _botBox(int i, Turn? t) {
    final p = g.players[i];
    final role = p.out
        ? 'вышел'
        : i == g.defender
            ? 'отбивается'
            : i == g.attacker
                ? 'ходит'
                : '';
    final n = min(p.hand.length, 12);
    return Opacity(
      opacity: p.out ? 0.5 : 1,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
          decoration: BoxDecoration(
            color: const Color(0x2E000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t?.who == i ? _accent : Colors.transparent, width: 2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.name} · ${p.hand.length}',
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
            // Роль отдельной строкой: при трёх ботах на узком экране в одну строку не влезает.
            Text(role.isEmpty ? ' ' : role,
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: _accent, fontSize: 11)),
            const SizedBox(height: 4),
            SizedBox(
              height: 34,
              child: LayoutBuilder(builder: (_, bc) {
                final step = n > 1 ? min(12.0, (bc.maxWidth - 24) / (n - 1)) : 0.0;
                return Stack(children: [
                  for (var k = 0; k < n; k++) Positioned(left: k * step, child: PlayingCardView(card: _back, width: 24)),
                ]);
              }),
            ),
          ]),
        ),
        if (p.say.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: -10,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(p.say, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _table(BoxConstraints bc) {
    final w = bc.maxWidth, h = bc.maxHeight;
    final tw = min(64.0, (w / 6.2).floorToDouble()), th = PlayingCardView.heightFor(tw);
    const label = TextStyle(color: Color(0xBFFFFFFF), fontSize: 12);
    final kids = <Widget>[];
    // Козырь лежит открытым под колодой, видна его левая половина с номиналом.
    if (g.talon.isNotEmpty) {
      kids.add(Positioned(left: 8, top: 8, child: PlayingCardView(card: _view(g.trumpCard), width: tw)));
      if (g.talon.length > 1) {
        kids.add(Positioned(left: 8 + tw * .55, top: 8, child: PlayingCardView(card: _back, width: tw)));
      }
    }
    kids.add(Positioned(
      left: 8,
      top: th + 14,
      child: g.talon.isNotEmpty
          ? Text('колода ${g.talon.length}', style: label)
          : Row(children: [
              const Text('козырь ', style: label),
              SuitIcon(suit: g.trump, size: 13, color: g.trumpCard.isRed ? const Color(0xFFFF8A80) : Colors.white),
            ]),
    ));
    if (g.discard.isNotEmpty) {
      kids.add(Positioned(right: 8, top: 8, child: Text('бито ${g.discard.length}', style: label)));
    }
    // Пары на столе: до трёх в ряд.
    final n = g.table.length, rows = max(1, (n / 3).ceil());
    final pw = tw * 1.3, ph = th * 1.28, gx = tw * .25;
    final top0 = max(th * 1.55 + 10, (h - rows * ph) / 2);
    final targets = _sel == null ? const <int>[] : g.undefended.where((i) => g.beats(g.table[i].attack, _sel!)).toList();
    for (var i = 0; i < n; i++) {
      final r = i ~/ 3, col = i % 3, inRow = min(3, n - r * 3);
      final x = (w - inRow * pw - (inRow - 1) * gx) / 2 + col * (pw + gx), y = top0 + r * ph;
      final p = g.table[i];
      kids.add(Positioned(
        left: x,
        top: y,
        child: GestureDetector(
          onTap: () => _tapTable(i),
          child: Container(
            decoration: targets.contains(i)
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(tw * .1),
                    boxShadow: const [BoxShadow(color: _accent, spreadRadius: 3)],
                  )
                : null,
            child: PlayingCardView(card: _view(p.attack), width: tw),
          ),
        ),
      ));
      if (p.defense != null) {
        kids.add(Positioned(
          left: x + tw * .3,
          top: y + th * .25,
          child: IgnorePointer(child: PlayingCardView(card: _view(p.defense!), width: tw)),
        ));
      }
    }
    return Stack(children: kids);
  }

  List<DCard> _sortedHand() {
    int order(int s) => s == g.trump ? 9 : const [0, 1, 3, 2].indexOf(s); // чередуем цвета, козыри справа
    return [...g.players[0].hand]..sort((a, b) => order(a.suit) != order(b.suit) ? order(a.suit) - order(b.suit) : a.rank - b.rank);
  }

  Widget _hand(Turn? t, double w) {
    final hw = min(72.0, (w / 5.6).floorToDouble()), hh = PlayingCardView.heightFor(hw);
    final cards = _sortedHand(), m = cards.length;
    final step = m > 1 ? min(hw + 4, (w - 16 - hw) / (m - 1)) : 0.0;
    final x0 = (w - (hw + step * (m - 1))) / 2;
    final myTurn = t != null && t.who == 0;
    return SizedBox(
      height: hh + 26,
      child: Stack(children: [
        for (var k = 0; k < m; k++)
          Builder(builder: (_) {
            final c = cards[k];
            var playable = true;
            if (myTurn && t.kind == ActKind.throwIn) playable = g.canThrow(c);
            if (myTurn && t.kind == ActKind.defend) {
              playable = g.undefended.any((i) => g.beats(g.table[i].attack, c)) || g.canTransfer(c);
            }
            final sel = _sel == c;
            return AnimatedPositioned(
              key: ValueKey(c.id),
              duration: const Duration(milliseconds: 150),
              left: x0 + k * step,
              top: sel ? 2 : 18,
              child: GestureDetector(
                onTap: () => _tapHand(c),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: myTurn && !playable ? 0.4 : 0), BlendMode.srcATop),
                  child: Container(
                    decoration: sel
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(hw * .1),
                            boxShadow: const [BoxShadow(color: _accent, spreadRadius: 3)],
                          )
                        : null,
                    child: PlayingCardView(card: _view(c), width: hw, lifted: sel),
                  ),
                ),
              ),
            );
          }),
      ]),
    );
  }

  String _status(Turn? t) {
    if (g.players[0].out && !g.over) return 'Вы вышли! Боты доигрывают…';
    if (t == null || t.kind == ActKind.end) return g.note;
    if (t.who == 0) {
      switch (t.kind) {
        case ActKind.attack:
          return 'Ваш ход: выберите карту';
        case ActKind.throwIn:
          return g.taking ? 'Соперник берёт: можно подкинуть вдогонку' : 'Можно подкинуть';
        default:
          final tr = g.mode == DurakMode.perevodnoy && g.players[0].hand.any(g.canTransfer);
          return 'Отбивайтесь${tr ? ', переводите' : ''} или берите';
      }
    }
    final who = g.players[t.who].name;
    if (t.kind == ActKind.defend) return 'Отбивается $who';
    return 'Ходит $who${g.defender == 0 ? ' · вы отбиваетесь' : ''}';
  }

  List<Widget> _actions(Turn? t) {
    if (t == null || t.who != 0) return [];
    Widget btn(String text, VoidCallback f) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: const Color(0xFF15202B)),
            onPressed: f,
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
    if (t.kind == ActKind.throwIn) {
      return [btn(g.taking ? 'Хватит' : (g.attacker == 0 ? 'Бито' : 'Пас'), () => _human(() => g.pass(0)))];
    }
    if (t.kind == ActKind.defend) {
      final sel = _sel;
      return [
        if (sel != null && g.canTransfer(sel)) btn('Перевести', () => _human(() => g.transfer(sel))),
        btn('Беру', () => _human(g.take)),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white, fontSize: 14);
    final game = _g;
    final t = game?.whoActs();
    return Scaffold(
      backgroundColor: _felt,
      body: SafeArea(
        child: game == null
            ? const SizedBox()
            : Column(children: [
                Container(
                  color: _barColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Text(
                        '${game.mode == DurakMode.perevodnoy ? 'Переводной' : 'Подкидной'} · партий $_games, в дураках $_lost',
                        style: white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Настройки',
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _settings,
                    ),
                    IconButton(
                      tooltip: 'Новая партия',
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _confirmNew,
                    ),
                  ]),
                ),
                _bots(t),
                Expanded(child: LayoutBuilder(builder: (_, bc) => _table(bc))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(_status(t),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t?.who == 0 ? _accent : Colors.white, fontSize: 15)),
                ),
                SizedBox(
                  height: 44,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: _actions(t)),
                ),
                LayoutBuilder(builder: (_, bc) => _hand(t, bc.maxWidth)),
              ]),
      ),
    );
  }
}
