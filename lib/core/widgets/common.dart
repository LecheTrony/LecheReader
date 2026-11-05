import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
    this.size = 44,
    this.iconSize = 21,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;
  final double size;
  final double iconSize;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = foreground ?? (filled ? palette.onPrimary : palette.ink);
    final button = Material(
      color: filled ? palette.primary : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size * 0.34),
        side: filled
            ? BorderSide.none
            : BorderSide(color: palette.outline.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size * 0.34),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Pequeño adorno editorial: línea, rombo, línea.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.width = 120, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lineColor = color ?? palette.outline;
    return SizedBox(
      width: width,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: lineColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 5,
              height: 5,
              color: palette.gold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: lineColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
    this.count,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: palette.inkSoft,
                  ),
            ),
          ),
        ],
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: action,
            child: Text(actionLabel ?? 'Ver todo'),
          ),
      ],
    );
  }
}

/// Texto pequeño en mayúsculas con tracking amplio.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: AppType.ui,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: color ?? palette.inkSoft,
      ),
    );
  }
}
