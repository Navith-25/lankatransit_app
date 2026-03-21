import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/owner_home_screen.dart';

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
    Widget homeWidget = const LoginScreen();

    if (isLoggedIn) {
      if (role == 'ADMIN') {
        homeWidget = const AdminHomeScreen();
      } else if (role == 'DRIVER' || role == 'CONDUCTOR') {
        homeWidget = const DriverHomeScreen();
      } else if (role == 'OWNER') {
        homeWidget = const OwnerHomeScreen();
      } else {
        homeWidget = const HomeScreen();
      }
    }

    return MaterialApp(home: homeWidget, debugShowCheckedModeBanner: false);
  }
}
