import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../app_settings.dart';
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

  late int _indiceActual = widget.indiceInicial;
  bool _isLoading = false;
  bool _isReconnecting = false;
  int _reintentos = 0;
  double _porcentaje = 0.0;
  String _datoCurioso = "";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isTV) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _inicializarCarga();
    _cargarCanal();
  }

  Future<void> _inicializarCarga() async {
    List<dynamic> lista = [];
    try {
      String jsonString = await rootBundle.loadString('assets/datos_curiosos.json');
      lista = jsonDecode(jsonString);
      lista.shuffle();
    } catch (e) {
      debugPrint("Error cargando datos locales: $e");
      lista = ["Bienvenido a Neaw Stream", "Disfruta de la mejor calidad"];
    }

    int ticks = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        ticks++;
        if (_porcentaje < 0.99) _porcentaje += 0.01;
        if (lista.isNotEmpty) {
          if (ticks < 50) _datoCurioso = lista[0 % lista.length];
          else if (ticks < 100) _datoCurioso = lista[1 % lista.length];
          else _datoCurioso = "";
        }
        if (_porcentaje >= 0.99) timer.cancel();
      });
    });
  }

  Future<void> _cargarCanal() async {
    if (_player != null) {
      await _player!.stop();
      await _player!.dispose();
      _player = null;
    }

    setState(() {
      _isLoading = true;
      _porcentaje = 0.0;
    });

    final prefs = await SharedPreferences.getInstance();
    int bufferMb = prefs.getInt('buffer_size') ?? 128;
    int bufferBytes = bufferMb * 1024 * 1024;

    _player = Player(configuration: PlayerConfiguration(bufferSize: bufferBytes, vo: 'mediacodec'));
    _controller = VideoController(_player!);

    final platform = _player!.platform as dynamic;
    platform.setProperty('interpolation', 'no');
    platform.setProperty('video-sync', 'audio-adrop');
    platform.setProperty('framedrop', 'decoder');
    platform.setProperty('cache', 'yes');
    platform.setProperty('cache-secs', '60');
    platform.setProperty('cache-initial', '5000');
    platform.setProperty('live-cache', '10');
    platform.setProperty('cache-pause', 'no');
    platform.setProperty('cache-pause-initial', 'yes');
    platform.setProperty('cache-backbuffer', '50');
    platform.setProperty('demuxer-readahead-secs', '10');
    platform.setProperty('tscale', 'oversample');
    platform.setProperty('vd-lavc-dr', 'yes');
    platform.setProperty('vd-lavc-fast', 'yes');
    platform.setProperty('vd-lavc-threads', '8');
    platform.setProperty('hwdec', 'mediacodec');
    platform.setProperty('demuxer-max-bytes', '256MiB');
    platform.setProperty('demuxer-max-back-bytes', '64MiB');
    platform.setProperty('audio-channels', 'stereo');
    platform.setProperty('ad-lavc-ac3drc', '0');
    platform.setProperty('hr-seek', 'yes');
    platform.setProperty('reconnect-stream', 'yes');
    platform.setProperty('reconnect-on-network-error', 'yes');
    platform.setProperty('reconnect-on-http-error', 'yes');
    platform.setProperty('force-window', 'immediate');
    platform.setProperty('network-timeout', '10');
    platform.setProperty('vd-lavc-threads', '0');
    platform.setProperty('reconnect-delay-max', '2');

    _player!.setVolume(0.0);

    await _player!.open(
      Media(widget.listaCanales[_indiceActual].url, extras: {'force_stream': 'true'}),
    );
    _player!.play();
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _isLoading = false);
        _player!.seek(Duration.zero);
        _player!.setVolume(100.0);
        _player!.play();
      }
    });

    _player!.stream.buffering.listen((buffering) {
      if (mounted && !_isLoading) {
        _player!.setVolume(buffering ? 0.0 : 100.0);
      }
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
    if (_player != null) {
      await _player!.stop();
      await _player!.dispose();
      _player = null;
    }
    int espera = (_reintentos * 3).clamp(3, 15);
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
    _timer?.cancel();
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Lottie.asset('assets/animations/Loading Cat.json', repeat: true),
                  ),
                  Text(
                    "${(_porcentaje * 100).toInt()}%",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 150,
                height: 80,
                child: Lottie.asset('assets/animations/wykos_animation.json', repeat: true),
              ),

              const SizedBox(height: 20),
              Text(
                "Cargando: ${widget.listaCanales[_indiceActual].nombre}",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    _datoCurioso,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
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
        body: Center(
          child: Video(controller: _controller!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
