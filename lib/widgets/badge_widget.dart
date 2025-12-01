import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/badge_model.dart' as app;
// Düzeltilmiş Importlar

/// Bir rozeti, ikonu ve ismiyle birlikte şık bir kutu içinde gösteren widget.
class BadgeWidget extends StatelessWidget {
  final app.Badge badge;
  final double iconSize;
  final double fontSize;

  const BadgeWidget({
    super.key,
    required this.badge,
    this.iconSize = 12,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badge.color.withAlpha(38),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(badge.icon, color: badge.color, size: iconSize),
          const SizedBox(width: 5),
          Text(
            badge.name,
            style: TextStyle(color: badge.color, fontWeight: FontWeight.bold, fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}