import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Player? _player;
  VideoController? _controller;
  
  late int _indiceActual = widget.indiceInicial;
  bool _isLoading = false;
  bool _isReconnecting = false;
  int _reintentos = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _cargarCanal();
  }

  Future<void> _cargarCanal() async {
    if (_player != null) await _player!.dispose();

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    int bufferMb = prefs.getInt('buffer_size') ?? 128; 
    int bufferBytes = bufferMb * 1024 * 1024;

    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferBytes,
        vo: 'mediacodec',
      ),
    );

    _controller = VideoController(_player!);
    final platform = _player!.platform as dynamic;
    
    // Sincronización y Audio
    platform.setProperty('video-sync', 'display-resample'); 
    platform.setProperty('audio-channels', 'stereo');
    platform.setProperty('ad-lavc-ac3drc', '0');
    platform.setProperty('framedrop', 'vo');
    platform.setProperty('vd-lavc-threads', '4');
    
    // Buffer y Estabilidad
    platform.setProperty('hwdec', 'no');
    platform.setProperty('cache', 'yes');
    platform.setProperty('cache-secs', '180');
    platform.setProperty('demuxer-max-bytes', '${bufferMb}MiB');
    platform.setProperty('live-cache', '60');
    platform.setProperty('hr-seek', 'yes');
    platform.setProperty('reconnect-stream', 'yes');
    platform.setProperty('reconnect-delay-max', '5');
    platform.setProperty('reconnect-on-http-error', 'yes');

    await _player!.open(
      Media(
        widget.listaCanales[_indiceActual].url,
        extras: {'force_stream': 'true'},
      ),
      play: false, 
    );

    await Future.delayed(const Duration(seconds: 10));

    if (mounted) {
      _player!.play();
      setState(() => _isLoading = false);
    }

    _player!.stream.buffering.listen((buffering) {
      if (mounted && buffering) setState(() => _isLoading = true);
    });

    _player!.stream.error.listen((error) {
      debugPrint("Error detectado: $error");
      _manejarReconexion();
    });
  }

  Future<void> _manejarReconexion() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    _reintentos++;
    
    int espera = (_reintentos * 3).clamp(3, 30);
    await Future.delayed(Duration(seconds: espera));
    
    if (mounted) {
      _isReconnecting = false;
      _cargarCanal();
    }
  }

  void _cambiarCanal(int direccion) {
    int nuevoIndice = _indiceActual + direccion;
    if (nuevoIndice >= 0 && nuevoIndice < widget.listaCanales.length) {
      _reintentos = 0;
      setState(() => _indiceActual = nuevoIndice);
      _cargarCanal();
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    if (widget.isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Lottie.asset(
                  'assets/animations/Loading Cat.json',
                  repeat: true,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Cargando: ${widget.listaCanales[_indiceActual].nombre}", 
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Text("Optimizando Transmisión🪄...", 
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _player?.playOrPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _cambiarCanal(1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _cambiarCanal(-1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Video(
            controller: _controller!,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}