import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'app_settings.dart';

final ValueNotifier<Color> globalAccentColor = ValueNotifier(Colors.blue);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(const NeawApp());
}

class NeawApp extends StatelessWidget {
  const NeawApp({super.key});

  Future<void> _initializeApp() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    try {
      final settings = await AppSettings.getSettings();
      final int savedColorValue = settings['themeColor'] ?? Colors.blue.value;
      globalAccentColor.value = Color(savedColorValue);
    } catch (e) {
      debugPrint("Error cargando settings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

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
      },
    );
  }
}
