import 'package:flutter/material.dart';
import 'package:NeawStreamVplayer/app_settings.dart';
import 'package:NeawStreamVplayer/main.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _hexColorController = TextEditingController();
  bool _mostrarLogs = false;
  bool _isTV = false;
  Color _themeColor = Colors.blue;

  final List<Color> _paletaColores = [
    const Color(0xFF448AFF), const Color(0xFFFF0000), const Color(0xFF00FF00), const Color(0xFFFF9100),
    const Color(0xFF33023B), const Color(0xFFFFFF00), const Color(0xFFEAFF00),
    const Color(0xFFFF4081), const Color(0xFF18FFFF), const Color(0xFFFFC400),
    const Color(0xFFFF0077), const Color(0xFF937CFA), const Color(0xFFFF6E40),
    const Color(0xFF00FFD5), const Color(0xFFFFFFFF), const Color(0xFF9E9E9E),
    const Color(0xFFFFB7B2), const Color(0xFFB5EAD7), const Color(0xFFC7CEEA),
    const Color(0xFFE8AEFF), const Color(0xFFFFF4BD), const Color(0xFF6C5CE7),
    const Color(0xFF0984E3), const Color(0xFF00CEC9), const Color(0xFFED4C67),
    const Color(0xFF2ECC71), const Color(0xFF1E272E), const Color(0xFF111424),
    const Color(0xFF2C3E50),
  ];

  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(_paletaColores.length, (index) => FocusNode());
    _loadData();
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() => _isTV = MediaQuery.of(context).size.width > 800);
  }

  void _loadData() async {
    final data = await AppSettings.getSettings();
    setState(() {
      _mostrarLogs = data['showLogs'] ?? false;
      _themeColor = Color(data['themeColor'] as int);
      _hexColorController.text = _themeColor.value.toRadixString(16).substring(2).toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajustes Avanzados")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Mostrar Logs al iniciar"),
              value: _mostrarLogs,
              onChanged: (bool value) => setState(() => _mostrarLogs = value),
            ),
            const SizedBox(height: 30),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text("  Color de interfaz:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 15),
            
            _isTV ? _buildPaletaColores() : _buildCampoHexadecimal(),

            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () {
                AppSettings.saveSettings(128, _mostrarLogs, _themeColor.value);
                globalAccentColor.value = _themeColor;
                Navigator.pop(context);
              },
              child: const Text("Guardar cambios"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPaletaColores() {
  return FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: SizedBox(
      height: 300,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: _paletaColores.length,
        itemBuilder: (context, index) {
          return _buildBotonColor(index, _paletaColores[index]);
        },
      ),
    ),
  );
}

Widget _buildBotonColor(int index, Color color) {
  final int colorVal = color.value & 0xFFFFFFFF;
  final int selectedVal = _themeColor.value & 0xFFFFFFFF;
  final FocusNode node = _focusNodes[index];

  return Focus(
    focusNode: node,
    onKey: (node, event) {
      if (event is RawKeyDownEvent && 
         (event.logicalKey.keyLabel == "Select" || event.logicalKey.keyLabel == "Enter")) {
        setState(() {
          _themeColor = color;
          _hexColorController.text = color.value.toRadixString(16).substring(2).toUpperCase();
        });
        AppSettings.saveSettings(128, _mostrarLogs, color.value);
        globalAccentColor.value = color;
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    onFocusChange: (focused) => setState(() {}),
    child: InkWell(
      onTap: () {
        setState(() {
          _themeColor = color;
          _hexColorController.text = color.value.toRadixString(16).substring(2).toUpperCase();
        });
        AppSettings.saveSettings(128, _mostrarLogs, color.value);
        globalAccentColor.value = color;
      },
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: node.hasFocus ? Colors.white.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: node.hasFocus ? Colors.white : Colors.transparent,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: CircleAvatar(
          backgroundColor: color,
          child: colorVal == selectedVal ? const Icon(Icons.check, color: Colors.white) : null,
        ),
      ),
    ),
  );
}
  Widget _buildCampoHexadecimal() {
    return TextFormField(
      controller: _hexColorController,
      decoration: const InputDecoration(
        labelText: "Código HEX (6 dígitos)",
        prefixText: "#",
        border: OutlineInputBorder(),
      ),
      onChanged: (val) {
        try {
          if (val.length >= 6) {
            setState(() => _themeColor = Color(int.parse("FF${val.replaceAll('#', '')}", radix: 16)));
          }
        } catch (_) {}
      },
    );
  }
}
