import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight feature hint tracker using shared_preferences.
/// Tracks which hints have been shown so they only appear once.
class FeatureHints {
  static const _prefix = 'hint_shown_';

  static Future<bool> shouldShow(String hintKey) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_prefix$hintKey') ?? false);
  }

  static Future<void> markShown(String hintKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$hintKey', true);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Hint keys
  static const swipeHint = 'swipe_actions';
  static const filterHint = 'filter_tabs';
  static const spacesHint = 'spaces_tab';
  static const pingHint = 'ping_nudge';
}
