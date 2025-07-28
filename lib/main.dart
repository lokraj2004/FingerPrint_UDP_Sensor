import 'package:flutter/material.dart';
import 'UI_Screen.dart';
import 'package:flutter/services.dart';
import 'configure.dart';
import 'package:lottie/lottie.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FingerPrint_UDP_Sensor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const platform = MethodChannel('com.example.fingerprint_channel');

  @override
  void initState() {
    super.initState();
    _checkUsername();
  }

  Future<void> _checkUsername() async {
    try {
      final String? username = await platform.invokeMethod('getUsername');

      if (username != null && username.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => FingerprintUnlockApp()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ConfigurePage()),
        );
      }
    } catch (e) {
      print("Error fetching username: $e");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ConfigurePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // or match your app's theme
      body: Center(
        child: Lottie.asset(
          'assets/animations/FingerPrint_loader.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          repeat: true,
        ),
      ),
    );
  }
}
