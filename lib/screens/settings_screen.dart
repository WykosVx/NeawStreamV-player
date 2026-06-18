import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:NeawStreamVplayer/app_settings.dart'; 

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _bufferController = TextEditingController();
  final TextEditingController _uaController = TextEditingController();
  bool _mostrarLogsDefault = false; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final data = await AppSettings.getSettings();
    setState(() {
      _bufferController.text = data['buffer'].toString();
      _uaController.text = data['ua'];
      _mostrarLogsDefault = data['showLogs'] ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ajustes Avanzados")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextFormField(
              controller: _bufferController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Tamaño del Buffer (MB)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed),
              ),
            ),
            SizedBox(height: 20),
            
            TextFormField(
              controller: _uaController,
              decoration: InputDecoration(
                labelText: "User-Agent",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
            ),
            SizedBox(height: 20),

            SwitchListTile(
              title: Text("Mostrar Logs al iniciar"),
              subtitle: Text("Activa el panel de depuración automáticamente"),
              value: _mostrarLogsDefault,
              onChanged: (bool value) {
                setState(() {
                  _mostrarLogsDefault = value;
                });
              },
            ),

            SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: () {
                int bufferValue = int.tryParse(_bufferController.text) ?? 128;
                
                AppSettings.saveSettings(
                  bufferValue, 
                  _uaController.text, 
                  _mostrarLogsDefault
                );
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Configuración guardada")),
                );
                Navigator.pop(context);
              },
              child: Text("Guardar cambios"),
            )
          ],
        ),
      ),
    );
  }
}