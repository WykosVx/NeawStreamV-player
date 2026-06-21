import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/home_screen.dart';
import 'app_settings.dart';

final ValueNotifier<Color> globalAccentColor = ValueNotifier(Colors.blue);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await _loadInitialSettings();

  runApp(const NeawApp());
}

Future<void> _loadInitialSettings() async {
  try {
    final settings = await AppSettings.getSettings();
    final int savedColorValue = settings['themeColor'] ?? Colors.blue.value;
    globalAccentColor.value = Color(savedColorValue);
  } catch (e) {
    debugPrint("Error cargando settings: $e");
  }
}

class NeawApp extends StatelessWidget {
  const NeawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: globalAccentColor,
      builder: (context, accentColor, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Neaw Stream',
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accentColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
