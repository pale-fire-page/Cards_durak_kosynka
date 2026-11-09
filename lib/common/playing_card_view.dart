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
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(borderRadius: radius, color: Colors.white, boxShadow: shadow),
      child: Stack(children: [
        Positioned(
          left: width * 0.07,
          top: width * 0.04,
          child: Text(
            '${card.rankLabel}${card.suitLabel}',
            style: TextStyle(
              color: color,
              fontSize: width * 0.36,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: -1,
            ),
          ),
        ),
        Positioned(
          right: width * 0.07,
          bottom: width * 0.04,
          child: Text(card.suitLabel,
              style: TextStyle(color: color, fontSize: width * 0.52, height: 1)),
        ),
      ]),
    );
  }
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
