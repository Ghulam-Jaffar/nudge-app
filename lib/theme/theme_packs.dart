import 'package:flutter/material.dart';

class ThemePack {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color surfaceColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color errorColor;
  final Gradient? backgroundGradient;
  final bool isDarkPack; // Whether this pack has dark backgrounds

  const ThemePack({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.cardColor,
    this.errorColor = const Color(0xFFE57373),
    this.backgroundGradient,
    this.isDarkPack = false,
  });
}

class ThemePacks {
  static const candy = ThemePack(
    id: 'candy',
    name: 'Candy',
    primaryColor: Color(0xFFFF6B9D),
    secondaryColor: Color(0xFFFFB4D2),
    accentColor: Color(0xFFFFC857),
    surfaceColor: Color(0xFFFFF5F8),
    backgroundColor: Color(0xFFFFF0F5),
    cardColor: Colors.white,
    errorColor: Color(0xFFFF6B6B),
  );

  static const midnight = ThemePack(
    id: 'midnight',
    name: 'Midnight',
    primaryColor: Color(0xFF7C3AED),
    secondaryColor: Color(0xFFA78BFA),
    accentColor: Color(0xFF22D3EE),
    surfaceColor: Color(0xFF1E1B4B),
    backgroundColor: Color(0xFF0F0D24),
    cardColor: Color(0xFF1E1B4B),
    errorColor: Color(0xFFF87171),
    isDarkPack: true,
  );

  static const matcha = ThemePack(
    id: 'matcha',
    name: 'Matcha',
    primaryColor: Color(0xFF84CC16),
    secondaryColor: Color(0xFFA3E635),
    accentColor: Color(0xFFFBBF24),
    surfaceColor: Color(0xFFF0FDF4),
    backgroundColor: Color(0xFFECFCCB),
    cardColor: Colors.white,
    errorColor: Color(0xFFEF4444),
  );

  static const ocean = ThemePack(
    id: 'ocean',
    name: 'Ocean',
    primaryColor: Color(0xFF0EA5E9),
    secondaryColor: Color(0xFF38BDF8),
    accentColor: Color(0xFF6366F1),
    surfaceColor: Color(0xFFF0F9FF),
    backgroundColor: Color(0xFFE0F2FE),
    cardColor: Colors.white,
    errorColor: Color(0xFFF43F5E),
  );

  static const lavender = ThemePack(
    id: 'lavender',
    name: 'Lavender',
    primaryColor: Color(0xFFA855F7),
    secondaryColor: Color(0xFFC084FC),
    accentColor: Color(0xFFF472B6),
    surfaceColor: Color(0xFFFAF5FF),
    backgroundColor: Color(0xFFF3E8FF),
    cardColor: Colors.white,
    errorColor: Color(0xFFEF4444),
  );

  static const sunset = ThemePack(
    id: 'sunset',
    name: 'Sunset',
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFFFB923C),
    accentColor: Color(0xFFFBBF24),
    surfaceColor: Color(0xFFFFF7ED),
    backgroundColor: Color(0xFFFFFBEB),
    cardColor: Colors.white,
    errorColor: Color(0xFFDC2626),
  );

  static const List<ThemePack> all = [candy, midnight, matcha, ocean, lavender, sunset];

  static ThemePack getById(String id) {
    return all.firstWhere(
      (pack) => pack.id == id,
      orElse: () => candy,
    );
  }
}
