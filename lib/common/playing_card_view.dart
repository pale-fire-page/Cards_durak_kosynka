import 'package:flutter/material.dart';
import '../klondike/klondike_game.dart';

/// Карта (лицом или рубашкой) размера [width] × [width]*1.4.
class PlayingCardView extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final bool lifted;

  const PlayingCardView({super.key, required this.card, required this.width, this.lifted = false});

  static double heightFor(double width) => width * 1.4;

  @override
  Widget build(BuildContext context) {
    final h = heightFor(width);
    final radius = BorderRadius.circular(width * 0.1);
    final shadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: lifted ? 0.5 : 0.4),
        blurRadius: lifted ? 10 : 2,
        offset: Offset(0, lifted ? 5 : 1),
      )
    ];
    if (!card.faceUp) {
      return Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: const Color(0xFF2A4FA0),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: shadow,
        ),
        child: Container(
          margin: EdgeInsets.all(width * 0.08),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.06),
            border: Border.all(color: const Color(0xFF6F8FD6), width: 1.5),
          ),
        ),
      );
    }
    final color = card.isRed ? const Color(0xFFC62828) : const Color(0xFF111111);
    // Масть заметно меньше номинала, одинаковая в обоих углах.
    final suitSize = width * 0.22;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(borderRadius: radius, color: Colors.white, boxShadow: shadow),
      child: Stack(children: [
        Positioned(
          left: width * 0.07,
          top: width * 0.05,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(
              card.rankLabel,
              style: TextStyle(
                color: color,
                fontSize: width * 0.36,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -1,
              ),
            ),
            SizedBox(width: width * 0.03),
            SuitIcon(suit: card.suit, size: suitSize, color: color),
          ]),
        ),
        Positioned(
          right: width * 0.08,
          bottom: width * 0.08,
          child: SuitIcon(suit: card.suit, size: suitSize, color: color),
        ),
      ]),
    );
  }
}

/// Масть, нарисованная векторно: одинаково выглядит на любом телефоне
/// (символы ♠♥♦♣ из шрифта Android рисует жирными или как эмодзи).
class SuitIcon extends StatelessWidget {
  final int suit;
  final double size;
  final Color color;
  const SuitIcon({super.key, required this.suit, required this.size, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SuitPainter(suit, color));
}

class _SuitPainter extends CustomPainter {
  final int suit;
  final Color color;
  _SuitPainter(this.suit, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = Path();
    void m(double x, double y) => p.moveTo(x * s, y * s);
    void l(double x, double y) => p.lineTo(x * s, y * s);
    void c(double a, double b, double c2, double d, double e, double f) =>
        p.cubicTo(a * s, b * s, c2 * s, d * s, e * s, f * s);
    switch (suit) {
      case 1: // ♥
        m(.5, .92);
        c(.18, .66, .04, .48, .04, .31);
        c(.04, .16, .15, .06, .29, .06);
        c(.39, .06, .46, .12, .5, .21);
        c(.54, .12, .61, .06, .71, .06);
        c(.85, .06, .96, .16, .96, .31);
        c(.96, .48, .82, .66, .5, .92);
        p.close();
      case 2: // ♦
        m(.5, .02);
        l(.86, .5);
        l(.5, .98);
        l(.14, .5);
        p.close();
      case 0: // ♠
        m(.5, .04);
        c(.2, .3, .05, .45, .05, .6);
        c(.05, .74, .15, .82, .28, .82);
        c(.36, .82, .43, .78, .47, .72);
        l(.4, .98);
        l(.6, .98);
        l(.53, .72);
        c(.57, .78, .64, .82, .72, .82);
        c(.85, .82, .95, .74, .95, .6);
        c(.95, .45, .8, .3, .5, .04);
        p.close();
      default: // ♣
        p.addOval(Rect.fromCircle(center: Offset(.5 * s, .27 * s), radius: .2 * s));
        p.addOval(Rect.fromCircle(center: Offset(.27 * s, .58 * s), radius: .2 * s));
        p.addOval(Rect.fromCircle(center: Offset(.73 * s, .58 * s), radius: .2 * s));
        m(.5, .5);
        l(.6, .98);
        l(.4, .98);
        p.close();
        p.fillType = PathFillType.nonZero;
    }
    canvas.drawPath(p, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_SuitPainter old) => old.suit != suit || old.color != color;
}

/// Пустое место под стопку.
class EmptySlot extends StatelessWidget {
  final double width;
  final String label;
  const EmptySlot({super.key, required this.width, this.label = ''});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: PlayingCardView.heightFor(width),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        ),
        child: Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: width * 0.45)),
      );
}
