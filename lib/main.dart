import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String role = prefs.getString('user_role') ?? 'PASSENGER';

  runApp(LankaTransitApp(isLoggedIn: isLoggedIn, role: role));
}

class LankaTransitApp extends StatelessWidget {
  final bool isLoggedIn;
  final String role;

  const LankaTransitApp({
    super.key,
    required this.isLoggedIn,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LankaTransit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: SplashScreen(isLoggedIn: isLoggedIn, role: role),
    );
  }
}
