import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'models/canal_model.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    _verificarAdvertencia(); 
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
            backgroundColor: Colors.grey[900],
            title: const Text("Aviso Legal", style: TextStyle(color: Colors.white)),
            content: const Text(
              "Descargo de responsabilidad: NeawStreamVplayer no proporciona, aloja ni incluye ningún tipo de contenido multimedia. Es exclusivamente una herramienta de reproducción que permite a los usuarios reproducir su propio contenido legal (como listas M3U o códigos Xtream). No respaldamos ni facilitamos la transmisión de material protegido por derechos de autor sin la autorización de sus titulares.",
              style: TextStyle(color: Colors.white70),
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
    setState(() {
      _urlController.text = prefs.getString('user_url') ?? "";
    });
  }

  Future<void> _procesarURL(String url) async {
    if (url.isEmpty) return;
    setState(() => _cargando = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_url', url);
    LogManager.add("Descargando: $url");
    try {
      final response = await http.get(Uri.parse(url), headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
      });
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("¡Éxito! ${canales.length} canales cargados."),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, 
        title: const Text("Neaw Stream"), 
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: _mostrarLogs ? Colors.green : Colors.white), 
            onPressed: () => setState(() => _mostrarLogs = !_mostrarLogs)
          ),
          IconButton(
            icon: const Icon(Icons.settings), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())).then((_) => _cargarConfiguracion())
          ),
        ]
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
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(hintText: "URL...", filled: true, fillColor: Color(0xFF1E1E1E), border: OutlineInputBorder()),
                          ),
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.download, size: 40, color: Colors.blue), onPressed: () => _procesarURL(_urlController.text)),
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
                      child: Card(color: const Color(0xFF1E1E1E), clipBehavior: Clip.antiAlias, child: Stack(children: [
                        if (canal.logoUrl.isNotEmpty) Positioned.fill(child: Opacity(opacity: 0.3, child: Image.network(canal.logoUrl, fit: BoxFit.cover))),
                        Center(child: Text(canal.nombre, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ])),
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
                color: Colors.black.withOpacity(0.8), 
                child: ValueListenableBuilder<int>(
                  valueListenable: LogManager.logNotifier, 
                  builder: (_, __, ___) => ListView.builder(
                    itemCount: LogManager.logs.length, 
                    itemBuilder: (_, i) => Text(LogManager.logs[i], style: const TextStyle(color: Colors.greenAccent, fontSize: 9))
                  )
                )
              )
            ),
          if (_mostrarTeclado)
            Positioned(
              bottom: 0, left: 0, right: 0, 
              child: TecladoTV(
                onCerrar: () => setState(() => _mostrarTeclado = false),
                onTecla: (t) => setState(() {
                  if (t == "Borrar") {
                    if (_urlController.text.isNotEmpty) {
                      _urlController.text = _urlController.text.substring(0, _urlController.text.length - 1);
                    }
                  } else if (t == "Espacio") {
                    _urlController.text += " ";
                  } else {
                    _urlController.text += t;
                  }
                }),
              )
            ),
        ],
      ),
    );
  }
}

class TecladoTV extends StatelessWidget {
  final Function(String) onTecla;
  final VoidCallback onCerrar;
  TecladoTV({super.key, required this.onTecla, required this.onCerrar});

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
                    if (event.runtimeType.toString() == 'RawKeyDownEvent' && 
                       (event.logicalKey.keyLabel == "Select" || event.logicalKey.keyLabel == "Enter")) {
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
                          color: focused ? Colors.blue : Colors.grey[900],
                          border: focused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.grey[800]!),
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