import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/playing_card_view.dart';
import 'klondike_game.dart';

const _felt = Color(0xFF1E6B3A);
const _barColor = Color(0x40000000);

class KlondikePage extends StatefulWidget {
  const KlondikePage({super.key});

  @override
  State<KlondikePage> createState() => _KlondikePageState();
}

/// Геометрия стола для текущего размера экрана.
class _Layout {
  final double w, h, pad, gap, cw, ch, tabTop;
  _Layout._(this.w, this.h, this.pad, this.gap, this.cw, this.ch, this.tabTop);

  factory _Layout.of(double w, double h) {
    const pad = 6.0;
    final gap = max(4.0, w * 0.015);
    final cw = ((w - 2 * pad - 6 * gap) / 7).floorToDouble();
    final ch = PlayingCardView.heightFor(cw);
    return _Layout._(w, h, pad, gap, cw, ch, pad + ch + gap * 2);
  }

  double x(int col) => pad + col * (cw + gap);
  double get top => pad;
}

class _Placed {
  final PlayingCard card;
  final PileRef pile;
  final int idx;
  final Offset pos;
  _Placed(this.card, this.pile, this.idx, this.pos);
}

class _KlondikePageState extends State<KlondikePage> {
  late KlondikeGame game;
  Timer? _clock;
  Timer? _auto;
  bool _ready = false;

  // Перетаскивание
  PileRef? _dragPile;
  int _dragIdx = 0;
  Offset _dragDelta = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    game = KlondikeGame();
    _loadSettings();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (game.started && !game.won) setState(game.tick);
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = prefs.getInt('klondike.drawCount') ?? 1;
      if (d != game.drawCount) game = KlondikeGame(drawCount: d == 3 ? 3 : 1);
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _saveDraw(int d) async {
    try {
      (await SharedPreferences.getInstance()).setInt('klondike.drawCount', d);
    } catch (_) {}
  }

  @override
  void dispose() {
    _clock?.cancel();
    _auto?.cancel();
    super.dispose();
  }

  bool get _busy => _auto != null;

  // ---------- Действия ----------

  void _afterAction() {
    if (game.won) {
      _showWin();
    } else if (game.canAutoFinish && !_busy) {
      game.beginAutoFinish();
      _auto = Timer.periodic(const Duration(milliseconds: 110), (t) {
        final more = game.autoFinishStep();
        setState(() {});
        if (!more) {
          t.cancel();
          _auto = null;
          if (game.won) _showWin();
        }
      });
    }
  }

  void _tapStock() {
    if (_busy) return;
    setState(game.clickStock);
  }

  void _tapCard(PileRef p, int idx) {
    if (_busy || !game.canPick(p, idx)) return;
    setState(() => game.autoMove(p, idx));
    _afterAction();
  }

  void _newGame() {
    _auto?.cancel();
    _auto = null;
    setState(game.newGame);
  }

  void _undo() {
    if (_busy) return;
    setState(game.undo);
  }

  Future<void> _changeDraw(int d) async {
    if (d == game.drawCount) return;
    if (game.started && !game.won) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: const Text('Сменить сдачу и начать новую игру?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Да')),
          ],
        ),
      );
      if (ok != true) return;
    }
    _saveDraw(d);
    _auto?.cancel();
    _auto = null;
    setState(() => game = KlondikeGame(drawCount: d));
  }

  void _showWin() {
    final text = game.scoring ? 'Очки: ${game.s.score}' : 'Очки не считались';
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Победа!', textAlign: TextAlign.center),
          content: Text('$text\nВремя: ${_fmt(game.seconds)}', textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _newGame();
              },
              child: const Text('Новая игра'),
            ),
          ],
        ),
      );
    });
  }

  // ---------- Перетаскивание ----------

  void _panStart(PileRef p, int idx) {
    if (_busy || !game.canPick(p, idx)) return;
    setState(() {
      _dragPile = p;
      _dragIdx = idx;
      _dragDelta = Offset.zero;
      _dragging = true;
    });
  }

  void _panUpdate(DragUpdateDetails d) {
    if (_dragPile == null) return;
    setState(() => _dragDelta += d.delta);
  }

  void _panEnd(_Layout l, Offset startPos) {
    final src = _dragPile;
    if (src == null) return;
    // Куда бросили: по центру верхней перетаскиваемой карты
    final cx = startPos.dx + _dragDelta.dx + l.cw / 2;
    final cy = startPos.dy + _dragDelta.dy + l.ch / 2;
    final col = ((cx - l.pad - l.cw / 2) / (l.cw + l.gap)).round();
    PileRef? dst;
    if (col >= 0 && col < 7) {
      if (cy >= l.tabTop - l.gap) {
        dst = PileRef.tableau(col);
      } else if (col >= 3) {
        dst = PileRef.foundation(col - 3);
      }
    }
    setState(() {
      if (dst != null) game.move(src, _dragIdx, dst);
      _dragPile = null;
      _dragging = false;
    });
    _afterAction();
  }

  // ---------- Раскладка ----------

  List<_Placed> _place(_Layout l) {
    final out = <_Placed>[];
    final s = game.s;
    if (s.stock.isNotEmpty) {
      out.add(_Placed(s.stock.last, PileRef.stock, s.stock.length - 1, Offset(l.x(0), l.top)));
    }
    final show = game.drawCount == 3 ? 3 : 1;
    final from = max(0, s.waste.length - show);
    for (var k = 0; k < s.waste.length; k++) {
      // Карты под веером лежат на месте первой видимой
      final shift = k < from ? 0 : (k - from) * l.cw * 0.3;
      out.add(_Placed(s.waste[k], PileRef.waste, k, Offset(l.x(1) + shift, l.top)));
    }
    for (var i = 0; i < 4; i++) {
      final f = s.foundations[i];
      for (var k = 0; k < f.length; k++) {
        out.add(_Placed(f[k], PileRef.foundation(i), k, Offset(l.x(3 + i), l.top)));
      }
    }
    for (var i = 0; i < 7; i++) {
      final col = s.tableau[i];
      var down = l.cw * 0.18, up = l.cw * 0.42;
      final nd = col.where((c) => !c.faceUp).length;
      final need = nd * down + max(0, col.length - nd - 1) * up;
      final avail = l.h - l.tabTop - l.ch - 6;
      if (need > avail && need > 0) {
        down *= avail / need;
        up *= avail / need;
      }
      var y = l.tabTop;
      for (var k = 0; k < col.length; k++) {
        out.add(_Placed(col[k], PileRef.tableau(i), k, Offset(l.x(i), y)));
        y += col[k].faceUp ? up : down;
      }
    }
    return out;
  }

  Widget _board(BoxConstraints bc) {
    final l = _Layout.of(bc.maxWidth, bc.maxHeight);
    final placed = _place(l);
    bool isDragged(_Placed p) => _dragPile != null && p.pile == _dragPile && p.idx >= _dragIdx;
    // Перетаскиваемые карты рисуем последними, чтобы они были сверху
    final ordered = [...placed.where((p) => !isDragged(p)), ...placed.where(isDragged)];
    final dragStart = placed.where(isDragged).firstOrNull?.pos ?? Offset.zero;

    Widget slot(double x, double y, String label, {VoidCallback? onTap}) => Positioned(
          left: x,
          top: y,
          child: GestureDetector(onTap: onTap, child: EmptySlot(width: l.cw, label: label)),
        );

    return Stack(clipBehavior: Clip.none, children: [
      slot(l.x(0), l.top, game.s.stock.isEmpty ? '↻' : '', onTap: _tapStock),
      slot(l.x(1), l.top, ''),
      for (var i = 0; i < 4; i++) slot(l.x(3 + i), l.top, 'A'),
      for (var i = 0; i < 7; i++) slot(l.x(i), l.tabTop, ''),
      for (final p in ordered)
        AnimatedPositioned(
          key: ValueKey(p.card.id),
          duration: isDragged(p) && _dragging ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          left: p.pos.dx + (isDragged(p) ? _dragDelta.dx : 0),
          top: p.pos.dy + (isDragged(p) ? _dragDelta.dy : 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: p.pile == PileRef.stock ? _tapStock : () => _tapCard(p.pile, p.idx),
            onPanStart: p.pile == PileRef.stock ? null : (_) => _panStart(p.pile, p.idx),
            onPanUpdate: p.pile == PileRef.stock ? null : _panUpdate,
            onPanEnd: p.pile == PileRef.stock ? null : (_) => _panEnd(l, dragStart),
            child: PlayingCardView(card: p.card, width: l.cw, lifted: isDragged(p)),
          ),
        ),
    ]);
  }

  static String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white, fontSize: 15);
    return Scaffold(
      backgroundColor: _felt,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: _barColor,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
              Text('Очки: ${game.scoring ? game.s.score : '—'}', style: white),
              const SizedBox(width: 16),
              Text(_fmt(game.seconds), style: white),
              const Spacer(),
              DropdownButton<int>(
                value: game.drawCount,
                dropdownColor: const Color(0xFF2E5E3E),
                style: white,
                iconEnabledColor: Colors.white,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('По 1 карте')),
                  DropdownMenuItem(value: 3, child: Text('По 3 карты')),
                ],
                onChanged: (v) => _changeDraw(v!),
              ),
              const SizedBox(width: 8),
            ]),
          ),
          if (!game.scoring)
            Container(
              width: double.infinity,
              color: _barColor,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: const Text('После отмены хода очки не считаются до новой игры',
                  style: TextStyle(color: Color(0xFFFFD54F), fontSize: 12)),
            ),
          Expanded(child: _ready ? LayoutBuilder(builder: (_, bc) => _board(bc)) : const SizedBox()),
          Container(
            color: _barColor,
            padding: const EdgeInsets.all(8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton.tonal(onPressed: _newGame, child: const Text('Новая игра')),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: game.canUndo && !_busy ? _undo : null,
                child: const Text('Отменить ход'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
