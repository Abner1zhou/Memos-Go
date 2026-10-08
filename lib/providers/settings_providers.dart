import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings persisted in shared_preferences.
class Settings {
  const Settings({this.themeMode = ThemeMode.system, this.localeCode = ''});

  /// Empty string = follow system.
  final ThemeMode themeMode;
  final String localeCode;

  Locale? get locale =>
      localeCode.isEmpty ? null : Locale(localeCode);

  Settings copyWith({ThemeMode? themeMode, String? localeCode}) => Settings(
        themeMode: themeMode ?? this.themeMode,
        localeCode: localeCode ?? this.localeCode,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _themeKey = 'settings.themeMode';
  static const _localeKey = 'settings.localeCode';

  @override
  Settings build() {
    _load();
    return const Settings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    final locale = prefs.getString(_localeKey) ?? '';
    state = Settings(
      themeMode: themeIndex != null && themeIndex >= 0 && themeIndex < 3
          ? ThemeMode.values[themeIndex]
          : ThemeMode.system,
      localeCode: locale,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setLocaleCode(String code) async {
    state = state.copyWith(localeCode: code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
