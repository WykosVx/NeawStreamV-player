import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/canal_model.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import '../app_settings.dart';
import '../main.dart';

// --- Gestor de Logs ---
class LogManager {
  static final List<String> logs = [];
  static final ValueNotifier<int> logNotifier = ValueNotifier(0);
  static void add(String message) {
    String time = "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}";
    logs.add("$time - $message");
    if (logs.length > 50) logs.removeAt(0);
    logNotifier.value++;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final List<Canal> canales = [];
  bool _cargando = false;
  bool _mostrarLogs = false;
  bool _mostrarTeclado = false;
  bool _isTV = false;
  bool _hayActualizacion = false;
  String _urlDescarga = "";

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    _verificarAdvertencia();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final response = await http.get(Uri.parse('https://api.github.com/repos/WykosVx/NeawStreamV-player/releases/latest'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        String versionGithub = json['tag_name'];
        _urlDescarga = json['html_url'];

        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String versionActual = packageInfo.version;

        if (versionGithub != versionActual) {
          if (mounted) setState(() => _hayActualizacion = true);
        }
      }
    } catch (e) {
      debugPrint("No se pudo verificar actualización: $e");
    }
  }

  // --- Diálogo de confirmación ---
  void _mostrarDialogoActualizacion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Actualización disponible"),
        content: const Text("Se ha detectado una nueva versión de Neaw Stream. ¿Deseas descargarla ahora?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Luego")
          ),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _iniciarDescarga();
              },
              child: const Text("Actualizar")
          ),
        ],
      ),
    );
  }

  Future<void> _iniciarDescarga() async {
    if (Platform.isAndroid) {
      debugPrint("El usuario está en Android, redirigiendo a la descarga de APK...");
    } else {
      debugPrint("El usuario está en PC/TV, redirigiendo a la descarga de instalador...");
    }


    final Uri url = Uri.parse(_urlDescarga);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _verificarAdvertencia() async {
    final prefs = await SharedPreferences.getInstance();
    bool yaMostro = prefs.getBool('yaMostroAdvertencia') ?? false;
    if (!yaMostro) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text("Aviso Legal"),
            content: const Text(
              "Descargo de responsabilidad: NeawStreamVplayer no proporciona, aloja ni incluye contenido multimedia. Es una herramienta de reproducción para contenido legal.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  prefs.setBool('yaMostroAdvertencia', true);
                  Navigator.pop(ctx);
                },
                child: const Text("Aceptar"),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() => _isTV = MediaQuery.of(context).size.width > 800);
  }

  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    final data = await AppSettings.getSettings();
    setState(() {
      _urlController.text = prefs.getString('user_url') ?? "";
      _mostrarLogs = data['showLogs'] ?? false;
    });
  }

  Future<void> _procesarURL(String url) async {
    if (url.isEmpty) return;
    setState(() => _cargando = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_url', url);
    LogManager.add("Descargando: $url");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<String> lineas = response.body.split('\n');
        List<Canal> listaTemporal = [];
        String? nombre, logo;
        for (var linea in lineas) {
          linea = linea.trim();
          if (linea.startsWith("#EXTINF")) {
            nombre = linea.split(',').last.trim();
            var match = RegExp(r'tvg-logo="([^"]+)"').firstMatch(linea);
            logo = match != null ? match.group(1) : "";
          } else if (linea.isNotEmpty && !linea.startsWith("#") && nombre != null) {
            listaTemporal.add(Canal(nombre: nombre, url: linea, logoUrl: logo ?? ""));
            nombre = null; logo = null;
          }
        }
        setState(() {
          canales.clear();
          canales.addAll(listaTemporal);
        });
        LogManager.add("Canales cargados: ${canales.length}");
      }
    } catch (e) {
      LogManager.add("Error: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: globalAccentColor,
      builder: (context, accentColor, _) {
        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            title: const Text("Neaw Stream"),
            actions: [
              if (_hayActualizacion)
                IconButton(
                  icon: const Icon(Icons.cloud_download, color: Colors.greenAccent),
                  tooltip: "Nueva versión disponible 😎",
                  onPressed: _mostrarDialogoActualizacion,
                ),
              IconButton(
                icon: Icon(Icons.bug_report, color: _mostrarLogs ? accentColor : theme.colorScheme.onSurface),
                onPressed: () => setState(() => _mostrarLogs = !_mostrarLogs),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()))
                    .then((_) => _cargarConfiguracion()),
              ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _mostrarTeclado = true),
                            child: IgnorePointer(
                              ignoring: _isTV,
                              child: TextField(
                                controller: _urlController,
                                decoration: InputDecoration(
                                  hintText: "URL...",
                                  filled: true,
                                  fillColor: theme.colorScheme.surfaceContainerHighest,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.download, size: 40, color: accentColor),
                          onPressed: () => _procesarURL(_urlController.text),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
                      itemCount: canales.length,
                      itemBuilder: (context, i) {
                        final canal = canales[i];
                        return InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(listaCanales: canales, indiceInicial: i, titulo: canal.nombre, isTV: true))),
                          child: Card(
                            color: theme.colorScheme.surfaceContainer,
                            clipBehavior: Clip.antiAlias,
                            child: Stack(children: [
                              if (canal.logoUrl.isNotEmpty) Positioned.fill(child: Opacity(opacity: 0.3, child: Image.network(canal.logoUrl, fit: BoxFit.cover))),
                              Center(
                                child: Text(canal.nombre, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_mostrarLogs)
                Positioned(
                  bottom: 20, right: 20, width: 250, height: 200,
                  child: Container(
                    color: theme.colorScheme.surface.withOpacity(0.9),
                    child: ValueListenableBuilder<int>(
                      valueListenable: LogManager.logNotifier,
                      builder: (_, __, ___) => ListView.builder(
                        itemCount: LogManager.logs.length,
                        itemBuilder: (_, i) => Text(LogManager.logs[i], style: TextStyle(color: accentColor, fontSize: 9)),
                      ),
                    ),
                  ),
                ),
              if (_mostrarTeclado)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: TecladoTV(
                    accentColor: accentColor,
                    onCerrar: () => setState(() => _mostrarTeclado = false),
                    onTecla: (t) => setState(() {
                      if (t == "Borrar") {
                        if (_urlController.text.isNotEmpty) _urlController.text = _urlController.text.substring(0, _urlController.text.length - 1);
                      } else if (t == "Espacio") {
                        _urlController.text += " ";
                      } else if (t != "Cerrar") {
                        _urlController.text += t;
                      }
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TecladoTV extends StatelessWidget {
  final Function(String) onTecla;
  final VoidCallback onCerrar;
  final Color accentColor;
  TecladoTV({super.key, required this.onTecla, required this.onCerrar, required this.accentColor});

  final List<List<String>> filas = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ':'],
    ['/', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '.', '_'],
    ['-', 'Borrar', 'Espacio', 'Cerrar']
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.95),
      padding: const EdgeInsets.all(10),
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filas.map((fila) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: fila.map((tecla) {
                return Focus(
                  canRequestFocus: true,
                  onKey: (node, event) {
                    if (event is RawKeyDownEvent && (event.logicalKey.keyLabel == "Select" || event.logicalKey.keyLabel == "Enter")) {
                      tecla == 'Cerrar' ? onCerrar() : onTecla(tecla);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Builder(builder: (ctx) {
                    bool focused = Focus.of(ctx).hasFocus;
                    return InkWell(
                      onTap: () => tecla == 'Cerrar' ? onCerrar() : onTecla(tecla),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: focused ? accentColor : Colors.grey[900],
                          border: Border.all(color: focused ? Colors.white : Colors.grey[800]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tecla, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}
