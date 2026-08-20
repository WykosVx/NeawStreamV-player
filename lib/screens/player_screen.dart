import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lottie/lottie.dart';
import 'models/canal_model.dart';

class PlayerScreen extends StatefulWidget {
  final List<Canal> listaCanales;
  final int indiceInicial;
  final String titulo;
  final bool isTV;

  const PlayerScreen({
    super.key,
    required this.listaCanales,
    required this.indiceInicial,
    required this.titulo,
    required this.isTV,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  late int _indiceActual;
  bool _isLoading = true;
  
  // Nodo de enfoque obligatorio para que la TV detecte las teclas del control remoto
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _indiceActual = widget.indiceInicial;

    if (widget.isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    _inicializarCanal(widget.listaCanales[_indiceActual].url);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Forzamos el foco en la pantalla para las teclas de la TV
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _inicializarCanal(String url) async {
    setState(() {
      _isLoading = true;
    });

    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      },
    );

    try {
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blueAccent,
          handleColor: Colors.blue,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white54,
        ),
        placeholder: Container(color: Colors.black),
        errorBuilder: (context, errorMessage) {
          return const Center(
            child: Text(
              "Error al cargar el canal",
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Aseguramos mantener el foco después de cargar para la TV
        FocusScope.of(context).requestFocus(_focusNode);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _cambiarCanal(int direccion) {
    int nuevoIndice = _indiceActual + direccion;
    if (nuevoIndice >= 0 && nuevoIndice < widget.listaCanales.length) {
      _chewieController?.dispose();
      _videoPlayerController?.dispose();

      setState(() {
        _indiceActual = nuevoIndice;
        _isLoading = true;
      });

      _inicializarCanal(widget.listaCanales[_indiceActual].url);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    if (widget.isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // Usamos RawKeyboardListener o Focus para capturar los botones del control remoto de la TV
        body: Focus(
          focusNode: _focusNode,
          onKey: (node, event) {
            // Detectamos cuando se presiona una tecla en el control remoto de la TV
            if (event is KeyDownEvent) {
              // Flecha Arriba o Botón de Canal+ en la TV cambia al canal anterior
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.channelUp) {
                _cambiarCanal(-1);
                return KeyEventResult.handled;
              }
              // Flecha Abajo o Botón de Canal- en la TV cambia al canal siguiente
              else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.channelDown) {
                _cambiarCanal(1);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: SafeArea(
            child: Stack(
              children: [
                // Reproductor con Chewie optimizado para TV
                Center(
                  child: (!_isLoading && _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                      ? Chewie(controller: _chewieController!)
                      : const SizedBox.shrink(),
                ),

                // Pantalla de carga con animación Lottie
                if (_isLoading)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.blueAccent),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 150,
                            height: 80,
                            child: Lottie.asset('assets/animations/wykos_animation.json'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Cargando: ${widget.listaCanales[_indiceActual].nombre}",
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Botón de retroceso (visible por si se usa en dispositivos táctiles o tv box con mouse)
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
