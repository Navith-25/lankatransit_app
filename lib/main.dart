import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(LankaTransitApp(isLoggedIn: isLoggedIn));
}

class LankaTransitApp extends StatelessWidget {
  final bool isLoggedIn;

  const LankaTransitApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LankaTransit',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),

      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}