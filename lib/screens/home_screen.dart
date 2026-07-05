import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/canal_model.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import '../app_settings.dart';
import '../main.dart';

// --- Funciones ---
List<Canal> _parsearLista(String body) {
  List<String> lineas = body.split('\n');
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
  return listaTemporal;
}

class LogManager {
  static final List<String> logs = [];
  static final ValueNotifier<int> logNotifier = ValueNotifier(0);
  static void add(String message) {
    logs.add("${DateTime.now().hour}:${DateTime.now().minute} - $message");
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
  final TextEditingController _busquedaController = TextEditingController();
  final List<Canal> _canalesCompletos = [];
  final List<Canal> _canalesMostrar = [];
  final ScrollController _scrollController = ScrollController();
  final int _itemsPorPagina = 50;
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _busquedaFocusNode = FocusNode();

  bool _cargando = false;
  bool _mostrarLogs = false;
  bool _mostrarTeclado = false;
  bool _buscando = false;
  bool _isTV = false;
  bool _hayActualizacion = false;
  String _urlDescarga = "";

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _inicializarApp();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarAdvertencia());
  }
  Future<void> _verificarAdvertencia() async {
    final prefs = await SharedPreferences.getInstance();
    bool aceptado = prefs.getBool('aviso_aceptado') ?? false;

    if (!aceptado && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Aviso Legal"),
          content: const Text(
            "Descargo de responsabilidad: NeawStreamV-player no proporciona, aloja ni incluye ningún tipo de contenido multimedia. "
                "Es exclusivamente una herramienta de reproducción que permite a los usuarios reproducir su propio contenido legal "
                "(como listas M3U o códigos Xtream). No respaldamos ni facilitamos la transmisión de material protegido por "
                "derechos de autor sin la autorización de sus titulares.",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setBool('aviso_aceptado', true);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text("Aceptar"),
            ),
          ],
        ),
      );
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() => _isTV = MediaQuery.of(context).size.width > 800);
  }

  void _activarTeclado(bool esBusqueda) {
    setState(() {
      _buscando = esBusqueda;
      _mostrarTeclado = true;
    });
  }

  Future<void> _inicializarApp() async {
    await _cargarConfiguracion();
    _checkUpdate();
    if (_urlController.text.isNotEmpty) _procesarURL(_urlController.text);
  }

  void _mostrarDialogoActualizacion() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Actualización"),
      content: const Text("Hay una nueva versión disponible."),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cerrar")), FilledButton(onPressed: () => launchUrl(Uri.parse(_urlDescarga)), child: const Text("Descargar"))],
    ));
  }

  Future<void> _checkUpdate() async {
    try {
      final response = await http.get(Uri.parse('https://api.github.com/repos/WykosVx/NeawStreamV-player/releases/latest'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _urlDescarga = json['html_url'];
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        if (json['tag_name'] != packageInfo.version && mounted) setState(() => _hayActualizacion = true);
      }
    } catch (e) { LogManager.add("Error update: $e"); }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) _cargarMas();
  }

  void _cargarMas() {
    if (_canalesMostrar.length < _canalesCompletos.length && !_cargando) {
      int inicio = _canalesMostrar.length;
      int fin = (inicio + _itemsPorPagina > _canalesCompletos.length) ? _canalesCompletos.length : inicio + _itemsPorPagina;
      setState(() => _canalesMostrar.addAll(_canalesCompletos.sublist(inicio, fin)));
    }
  }

  Future<void> _procesarURL(String url) async {
    if (url.isEmpty) return;
    setState(() => _cargando = true);
    LogManager.add("Descargando: $url");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final lista = await compute(_parsearLista, response.body);
        LogManager.add("Canales cargados: ${lista.length}");
        setState(() {
          _canalesCompletos.clear(); _canalesCompletos.addAll(lista);
          _canalesMostrar.clear(); _canalesMostrar.addAll(_canalesCompletos.take(_itemsPorPagina));
        });
      } else {
        LogManager.add("Error servidor: ${response.statusCode}");
      }
    } catch (e) {
      LogManager.add("Error: $e");
    } finally { setState(() => _cargando = false); }
  }

  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    final data = await AppSettings.getSettings();
    setState(() {
      _urlController.text = prefs.getString('user_url') ?? "";
      _mostrarLogs = data['showLogs'] ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(valueListenable: globalAccentColor, builder: (context, accentColor, _) {
      return Scaffold(
        appBar: AppBar(title: const Text("Neaw Stream"), actions: [
          IconButton(icon: Icon(Icons.search, color: _buscando ? accentColor : null), onPressed: () => setState(() => _buscando = !_buscando)),
          if (_hayActualizacion) IconButton(icon: const Icon(Icons.cloud_download, color: Colors.greenAccent), onPressed: _mostrarDialogoActualizacion),
          IconButton(icon: Icon(Icons.bug_report, color: _mostrarLogs ? accentColor : null), onPressed: () => setState(() => _mostrarLogs = !_mostrarLogs)),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())).then((_) => _cargarConfiguracion())),
        ]),
        body: Stack(
            children: [
              Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                            children: [
                              Expanded(
                                child: _isTV
                                    ? InkWell(
                                  onTap: () => setState(() {
                                    _buscando = false;
                                    _mostrarTeclado = true;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: Text(
                                      _urlController.text.isEmpty ? "URL..." : _urlController.text,
                                      style: const TextStyle(fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                    : TextField(
                                  controller: _urlController,
                                  focusNode: _urlFocusNode,
                                  readOnly: _isTV,
                                  showCursor: !_isTV,
                                  decoration: InputDecoration(
                                    hintText: "URL...",
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
              IconButton(icon: Icon(Icons.download, color: accentColor), onPressed: () => _procesarURL(_urlController.text)),
            ])),
                    if (_buscando)
                      Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                              children: [
                                Expanded(
                                  child: _isTV
                                      ? InkWell(
                                    onTap: () => setState(() => _mostrarTeclado = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: Text(
                                        _busquedaController.text.isEmpty ? "Buscar..." : _busquedaController.text,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  )
                                      : TextField(
                                    controller: _busquedaController,
                                    decoration: const InputDecoration(hintText: "Buscar...", filled: true),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () {
                                    setState(() {
                                      _canalesMostrar.clear();
                                      _canalesMostrar.addAll(_canalesCompletos.where((c) =>
                                          c.nombre.toLowerCase().contains(_busquedaController.text.toLowerCase())));
                                      _mostrarTeclado = false;
                                    });
                                  },
                                ),
                              ],
                          ),
                      ),
                    Expanded(
                      child: GridView.builder(
                        controller: _scrollController,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width < 600 ? 4 : 10,
                        ),
                        itemCount: _canalesMostrar.length,
                        itemBuilder: (context, i) {
                          final canal = _canalesMostrar[i];
                          return InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  listaCanales: _canalesCompletos,
                                  indiceInicial: i,
                                  titulo: canal.nombre,
                                  isTV: true,
                                ),
                              ),
                            ),
                            child: Card(
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  if (canal.logoUrl.isNotEmpty)
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.3,
                                        child: CachedNetworkImage(
                                          imageUrl: canal.logoUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: Text(
                                      canal.nombre,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
              ),
              if (_mostrarLogs)
                Positioned(
                  bottom: 20,
                  right: 20,
                  width: 250,
                  height: 200,
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: ListView.builder(
                      itemCount: LogManager.logs.length,
                      itemBuilder: (_, i) => Text(
                        LogManager.logs[i],
                        style: const TextStyle(color: Colors.green, fontSize: 9),
                      ),
                    ),
                  ),
                ),
              if (_mostrarTeclado)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: TecladoTV(
                    accentColor: accentColor,
                    onCerrar: () => setState(() => _mostrarTeclado = false),
                    onTecla: (t) => setState(() {
                      var ctrl = _buscando ? _busquedaController : _urlController;
                      if (t == "Borrar") {
                        if (ctrl.text.isNotEmpty) ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
                      } else if (t == "Espacio") {
                        ctrl.text += " ";
                      } else if (t != "Cerrar") {
                        ctrl.text += t;
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

  const TecladoTV(
      {super.key, required this.onTecla, required this.onCerrar, required this.accentColor});

  final List<List<String>> filas = const [
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
        policy: OrderedTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: filas.map((fila) =>
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: fila.map((tecla) =>
                    Focus(
                      canRequestFocus: true,
                      onKey: (node, event) {
                        if (event is RawKeyDownEvent &&
                            (event.logicalKey.keyLabel == "Select" ||
                                event.logicalKey.keyLabel == "Enter")) {
                          tecla == 'Cerrar' ? onCerrar() : onTecla(tecla);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Builder(builder: (ctx) {
                        bool focused = Focus
                            .of(ctx)
                            .hasFocus;
                        return InkWell(
                          onTap: () =>
                          tecla == 'Cerrar' ? onCerrar() : onTecla(tecla),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: focused ? accentColor : Colors.grey[900],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: focused ? Colors.white : Colors
                                      .transparent, width: 2),
                            ),
                            child: Text(tecla, style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                          ),
                        );
                      }),
                    )).toList(),
              )).toList(),
        ),
      ),
    );
  }
}
