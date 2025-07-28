import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'UI_Screen.dart';
import 'background_wrapper.dart';

class ConfigurePage extends StatefulWidget {
  const ConfigurePage({super.key});

  @override
  State<ConfigurePage> createState() => _ConfigurePageState();
}

class _ConfigurePageState extends State<ConfigurePage> {
  static const platform = MethodChannel('com.example.fingerprint_channel');

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    final prefs = await SharedPreferences.getInstance();

    _usernameController.text = prefs.getString('username') ?? '';
    _ipController.text = prefs.getString('esp32_ip') ?? '';
    _portController.text = prefs.getInt('esp32_port')?.toString() ?? '';
  }

  Future<void> _applyConfiguration() async {
    final username = _usernameController.text.trim();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('esp32_ip', ip);
    await prefs.setInt('esp32_port', port);

    final config = {
      'username': username,
      'esp32_ip': ip,
      'esp32_port': port,
    };

    try {
      await platform.invokeMethod('updateConfig', config);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Configuration applied')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => FingerprintUnlockApp()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Settings',style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold,color: Colors.white)),
        backgroundColor: const Color(0xFF226214),
      ),
      body: BackgroundWrapper(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Enter Configuration",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(_usernameController, 'Username'),
                  const SizedBox(height: 12),
                  _buildTextField(_ipController, 'ESP32 IP'),
                  const SizedBox(height: 12),
                  _buildTextField(_portController, 'ESP32 Port', isNumber: true),
                  const SizedBox(height: 25),

                  ElevatedButton(
                    onPressed: _applyConfiguration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 6,
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.tealAccent),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
