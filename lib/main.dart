import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// main function eka dan async wenawa memory eka read karanna oni nisa
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter ready da kiyala make sure karanawa

  // Phone eke memory eka check karanawa
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false; // Mukuth nathnam false kiyala gannawa

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
      // isLoggedIn true nam HomeScreen ekata, natham LoginScreen ekata yanawa
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}