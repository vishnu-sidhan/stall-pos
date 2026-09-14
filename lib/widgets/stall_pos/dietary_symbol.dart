import 'package:flutter/material.dart';
import '../../data/models/dietary_type.dart';

/// Renders a standard food dietary indicator symbol (Veg, Non-Veg, Egg)
/// consisting of a rounded square box with a centered colored mark (green/red/amber).
class DietarySymbol extends StatelessWidget {
  final ItemDietaryType type;
  final double size;
  final bool showLabel;
  final TextStyle? labelStyle;

  const DietarySymbol({
    super.key,
    required this.type,
    this.size = 13.0,
    this.showLabel = false,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (type == ItemDietaryType.none) {
      return const SizedBox.shrink();
    }

    final symbol = Tooltip(
      message: type.displayName,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.22),
          border: Border.all(
            color: type.borderColor,
            width: size > 16 ? 1.4 : 1.1,
          ),
        ),
        child: Container(
          width: size * 0.48,
          height: size * 0.48,
          decoration: BoxDecoration(
            color: type.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    if (!showLabel) {
      return symbol;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        symbol,
        const SizedBox(width: 4),
        Text(
          type.displayName,
          style: labelStyle ??
              TextStyle(
                fontSize: size * 0.85,
                fontWeight: FontWeight.w600,
                color: type.color,
              ),
        ),
      ],
    );
  }
}
