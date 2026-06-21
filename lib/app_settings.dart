import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String keyBufferSize = 'buffer_size';
  static const String keyShowLogs = 'auto_mostrar_logs';
  static const String keyThemeColor = 'theme_color';

  static Future<void> saveSettings(int buffer, bool showLogs, int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBufferSize, buffer);
    await prefs.setBool(keyShowLogs, showLogs);
    await prefs.setInt(keyThemeColor, colorValue);
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'buffer': prefs.getInt(keyBufferSize) ?? 128,
      'showLogs': prefs.getBool(keyShowLogs) ?? false,
      'themeColor': prefs.getInt(keyThemeColor) ?? Colors.blue.value,
    };
  }
}
