import 'package:flutter/material.dart';

/// Mascot variants available in assets/mascot/
enum MascotVariant {
  happy,
  waving,
  thinking,
  sad,
  celebrating,
  nudge,
}

/// A widget that displays a mascot image with graceful fallback.
/// If the asset is missing or fails to load, shows a themed Material icon instead.
class MascotImage extends StatelessWidget {
  final MascotVariant variant;
  final double size;
  final IconData fallbackIcon;

  const MascotImage({
    super.key,
    required this.variant,
    this.size = 120,
    this.fallbackIcon = Icons.notifications_active_rounded,
  });

  String get _assetPath => 'assets/mascot/mascot_${variant.name}.png';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Graceful fallback: show a themed icon in a circle
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            fallbackIcon,
            size: size * 0.5,
            color: colorScheme.primary,
          ),
        );
      },
    );
  }
}
