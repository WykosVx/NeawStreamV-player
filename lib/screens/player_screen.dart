import 'dart:async';
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
  final FocusNode _focusNode = FocusNode();
  StreamSubscription? _bufferSubscription;

  late int _indiceActual = widget.indiceInicial;
  bool _isLoading = false;
  bool _isDisposed = false;
  bool _isReconnecting = false;
  double _progresoBuffer = 0.0;
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
    if (_player != null) {
      await _player!.stop();
      await _player!.dispose();
      _player = null;
    }
    _bufferSubscription?.cancel();

    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
      _progresoBuffer = 0.0;
    });

    final prefs = await SharedPreferences.getInstance();
    int bufferMb = prefs.getInt('buffer_size') ?? 128;
    int bufferBytes = bufferMb * 1024 * 1024;

    _player = Player(configuration: PlayerConfiguration(bufferSize: bufferBytes, vo: 'mediacodec'));
    _controller = VideoController(_player!);

    final platform = _player!.platform as dynamic;
    platform.setProperty('hwdec', 'mediacodec');
    platform.setProperty('hwdec-codecs', 'h264,hevc,vp9');
    platform.setProperty('video-sync', 'display-adrop');
    platform.setProperty('opengl-pbo', 'no');
    platform.setProperty('vd-lavc-threads', '0');
    platform.setProperty('video-sync', 'display-resample');
    platform.setProperty('vsync', 'yes');
    platform.setProperty('swapinterval', '1');
    platform.setProperty('interpolation', 'yes');
    platform.setProperty('tscale', 'oversample');
    platform.setProperty('framedrop', 'decoder');
    platform.setProperty('vd-lavc-dr', 'yes');
    platform.setProperty('cache', 'yes');
    platform.setProperty('cache-initial', '5000');
    platform.setProperty('cache-secs', '30');
    platform.setProperty('demuxer-max-bytes', '128MiB');
    platform.setProperty('demuxer-max-back-bytes', '32MiB');
    platform.setProperty('reconnect-stream', 'yes');
    platform.setProperty('network-timeout', '10');
    platform.setProperty('hr-seek', 'yes');

    _player!.setVolume(0.0);

    _bufferSubscription = _player!.stream.buffer.listen((buffer) {
      if (_isDisposed || !_isLoading) return;

      double duracionMs = buffer.inMilliseconds.toDouble();
      double metaMs = 10000.0;

      setState(() {
        _progresoBuffer = (duracionMs / metaMs).clamp(0.0, 1.0);
      });

      if (duracionMs >= metaMs) {
        _bufferSubscription?.cancel();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _player!.setVolume(100.0);
            _player!.seek(Duration.zero);
            _player!.play();
          });
        }
      }
    });

    await _player!.open(Media(widget.listaCanales[_indiceActual].url));
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
    _isDisposed = true;
    _bufferSubscription?.cancel();
    _player?.dispose();
    _focusNode.dispose();
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
              CircularProgressIndicator(value: _progresoBuffer),
              const SizedBox(height: 20),
              SizedBox(width: 150, height: 80, child: Lottie.asset('assets/animations/wykos_animation.json')),
              const SizedBox(height: 10),
              Text("Cargando: ${widget.listaCanales[_indiceActual].nombre}", style: const TextStyle(color: Colors.white)),
              Text("${(_progresoBuffer * 100).toInt()}%", style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
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
        body: Video(
          controller: _controller!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
