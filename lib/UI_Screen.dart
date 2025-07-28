import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'configure.dart';
import 'About.dart';
import 'background_wrapper.dart';

class FingerprintUnlockApp extends StatefulWidget {
  @override
  State<FingerprintUnlockApp> createState() => _FingerprintUnlockAppState();
}

class _FingerprintUnlockAppState extends State<FingerprintUnlockApp> {
  static const platform = MethodChannel('com.example.fingerprint_channel');
  String _status = 'Idle';
  String? _username;

  bool _isConnected = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _initCallbacks();
    _fetchUsernameFromNative();
  }

  void _handleMenuSelection(BuildContext context, String value) {
    if (value == 'configure') {
      final result = Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConfigurePage()),
      );

      if (result == true) {
        _fetchUsernameFromNative(); // Refresh username
      }
    } else if (value == 'about') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
    }
  }

  void _initCallbacks() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case "onConnectAck":
          String token = call.arguments;
          setState(() {
            _status = 'Connected. Token: $token';
            _isConnected = true;
          });
          break;
        case "onUnlockAck":
          setState(() {
            _status = 'Unlocked successfully!';
            _isVerifying = false;
            _isConnected = false;
          });
          break;
        case "onTimeout":
          setState(() {
            _status = 'Timeout! Please reconnect.';
            _isConnected = false;
            _isVerifying = false;
          });
          break;
        case "onAuthFailed":
          setState(() {
            _status = 'Fingerprint auth failed';
          });
          break;
        case 'onInvalidUser':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid username. Access denied')),
          );
          break;
        case "onError":
          setState(() {
            _status = 'Error: ${call.arguments}';
          });
          break;
      }
    });
  }

  Future<void> _fetchUsernameFromNative() async {
    try {
      final result = await platform.invokeMethod<String>('getUsername');
      setState(() {
        _username = result;
        _status = 'Username loaded: $_username';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Failed to load username: ${e.message}';
      });
    }
  }

  Future<void> _sendConnect() async {
    if (_username == null || _username!.isEmpty) return;
    setState(() {
      _status = 'Sending connect...';
    });
    try {
      await platform.invokeMethod('connect', {"username": _username});
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Connect failed: ${e.message}';
      });
    }
  }

  Future<void> _verifyAndUnlock() async {
    setState(() {
      _status = 'Authenticating...';
      _isVerifying = true;
    });
    try {
      await platform.invokeMethod('verify');
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Verify failed: ${e.message}';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FingerPrint UDP Sensor',style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold,color: Colors.white)),
        backgroundColor: Color(0xFF226214),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white), // <-- This makes it white
            onSelected: (value) => _handleMenuSelection(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'configure', child: Text('Configure')),
              const PopupMenuItem(value: 'about', child: Text('About')),
            ],
          ),
        ],
      ),
      body: BackgroundWrapper(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_username != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Username: $_username',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // Connect Button
              ElevatedButton(
                onPressed: _isConnected ? null : _sendConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent[700],
                  foregroundColor: Colors.white,
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Connect',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // Verify Button
              ElevatedButton(
                onPressed: _isConnected && !_isVerifying ? _verifyAndUnlock : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen[600],
                  foregroundColor: Colors.white,
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Verify',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 30),

              // Status Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30),
                ),
                child: Text(
                  'Status: $_status',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
