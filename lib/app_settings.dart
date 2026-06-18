import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String keyBufferSize = 'buffer_size';
  static const String keyUserAgent = 'user_agent';
  static const String keyShowLogs = 'auto_mostrar_logs';

  static Future<void> saveSettings(int buffer, String ua, bool showLogs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBufferSize, buffer);
    await prefs.setString(keyUserAgent, ua);
    await prefs.setBool(keyShowLogs, showLogs); 
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'buffer': prefs.getInt(keyBufferSize) ?? 128,
      'ua': prefs.getString(keyUserAgent) ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'showLogs': prefs.getBool(keyShowLogs) ?? false, 
    };
  }
}