import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_packs.dart';
import 'auth_provider.dart';
import 'user_provider.dart';

class ThemeState {
  final AppThemeMode mode;
  final ThemePack pack;

  const ThemeState({
    this.mode = AppThemeMode.system,
    this.pack = ThemePacks.ocean, // Default to Ocean
  });

  ThemeState copyWith({
    AppThemeMode? mode,
    ThemePack? pack,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      pack: pack ?? this.pack,
    );
  }

  /// Determines if dark mode should be used based on mode setting
  bool _isSystemDark(BuildContext context) {
    switch (mode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  /// Gets the effective theme pack based on system dark/light mode
  /// If system is dark and pack is light, use Midnight
  /// If system is light and pack is dark, use Ocean
  ThemePack getEffectivePack(BuildContext context) {
    final systemDark = _isSystemDark(context);

    if (systemDark && !pack.isDarkPack) {
      // System is dark but pack is light - switch to Midnight
      return ThemePacks.midnight;
    } else if (!systemDark && pack.isDarkPack) {
      // System is light but pack is dark - switch to Ocean
      return ThemePacks.ocean;
    }

    // Pack matches system preference
    return pack;
  }

  bool isDark(BuildContext context) {
    final effectivePack = getEffectivePack(context);
    return effectivePack.isDarkPack;
  }

  ThemeData getTheme(BuildContext context) {
    final effectivePack = getEffectivePack(context);
    return AppTheme.buildTheme(
      pack: effectivePack,
      isDark: effectivePack.isDarkPack,
    );
  }

  static ThemeState fromUserTheme(UserThemeSettings? settings) {
    // Default to Ocean theme
    if (settings == null) return const ThemeState(pack: ThemePacks.ocean);

    AppThemeMode mode;
    switch (settings.mode) {
      case 'light':
        mode = AppThemeMode.light;
        break;
      case 'dark':
        mode = AppThemeMode.dark;
        break;
      default:
        mode = AppThemeMode.system;
    }

    return ThemeState(
      mode: mode,
      pack: ThemePacks.getById(settings.packId),
    );
  }

  UserThemeSettings toUserTheme() {
    String modeStr;
    switch (mode) {
      case AppThemeMode.light:
        modeStr = 'light';
        break;
      case AppThemeMode.dark:
        modeStr = 'dark';
        break;
      case AppThemeMode.system:
        modeStr = 'system';
    }

    return UserThemeSettings(
      mode: modeStr,
      packId: pack.id,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  final UserService _userService;
  final String? _uid;

  ThemeNotifier({
    UserService? userService,
    String? uid,
    ThemeState initialState = const ThemeState(),
  })  : _userService = userService ?? UserService(),
        _uid = uid,
        super(initialState);

  Future<void> setMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _saveToFirebase();
  }

  Future<void> setPack(ThemePack pack) async {
    state = state.copyWith(pack: pack);
    await _saveToFirebase();
  }

  void setPackById(String packId) {
    state = state.copyWith(pack: ThemePacks.getById(packId));
    _saveToFirebase();
  }

  Future<void> _saveToFirebase() async {
    if (_uid == null) return;
    await _userService.updateThemeSettings(_uid, state.toUserTheme());
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final user = ref.watch(currentUserProvider);
  final appUser = ref.watch(appUserProvider);

  // Create initial state from user's saved theme
  final initialState = ThemeState.fromUserTheme(appUser?.theme);

  return ThemeNotifier(
    uid: user?.uid,
    initialState: initialState,
  );
});
