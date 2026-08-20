import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lottie/lottie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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

  // Control para evitar doble pulsación rápida en la TV que sature la memoria
  bool _cambiandoCanal = false;

  // Animación Lottie pre-cacheada para evitar tirones de rendimiento
  late final Future<LottieComposition> _lottieComposition;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _indiceActual = widget.indiceInicial;

    // Precargamos la composición de Lottie en memoria una sola vez
    _lottieComposition = AssetLottie('assets/animations/wykos_animation.json').load();

    WakelockPlus.enable();

    if (widget.isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    _inicializarCanal(widget.listaCanales[_indiceActual].url);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    FocusScope.of(context).requestFocus(_focusNode);
  }

  Future<void> _inicializarCanal(String url) async {
    await _liberarRecursosAnteriores();

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final localController = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      },
    );

    _videoPlayerController = localController;

    try {
      await localController.initialize();

      if (!mounted || _videoPlayerController != localController) {
        localController.dispose();
        return;
      }

      _chewieController = ChewieController(
        videoPlayerController: localController,
        autoPlay: true,
        looping: false,
        aspectRatio: localController.value.aspectRatio,
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

      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        setState(() {
          _isLoading = false;
          _cambiandoCanal = false; // Liberamos el bloqueo de cambio
        });
        FocusScope.of(context).requestFocus(_focusNode);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _cambiandoCanal = false;
        });
      }
    }
  }

  Future<void> _liberarRecursosAnteriores() async {
    try {
      _chewieController?.dispose();
      _chewieController = null;

      await _videoPlayerController?.dispose();
      _videoPlayerController = null;
    } catch (_) {}
  }

  void _cambiarCanal(int direccion) {
    // Si ya está cambiando de canal, ignoramos para evitar colapsar la TV
    if (_cambiandoCanal) return;

    int nuevoIndice = _indiceActual + direccion;
    if (nuevoIndice >= 0 && nuevoIndice < widget.listaCanales.length) {
      setState(() {
        _cambiandoCanal = true;
        _indiceActual = nuevoIndice;
        _isLoading = true;
      });

      _inicializarCanal(widget.listaCanales[_indiceActual].url);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _focusNode.dispose();
    _liberarRecursosAnteriores();

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
        body: Focus(
          focusNode: _focusNode,
          onKey: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.channelUp) {
                _cambiarCanal(-1);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
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
                Center(
                  child: (!_isLoading && _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized)
                      ? Chewie(controller: _chewieController!)
                      : const SizedBox.shrink(),
                ),

                if (_isLoading)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.blueAccent),
                          const SizedBox(height: 20),
                          // Usamos el Lottie precargado para que la TV vuele sin tirones gráficos
                          SizedBox(
                            width: widget.isTV ? 100 : 150,
                            height: widget.isTV ? 60 : 80,
                            child: FutureBuilder<LottieComposition>(
                              future: _lottieComposition,
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Lottie(composition: snapshot.data!);
                                }
                                return const SizedBox.shrink();
                              },
                            ),
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
