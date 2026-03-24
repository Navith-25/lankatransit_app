import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin_home_screen.dart';
import 'driver_home_screen.dart';
import 'owner_home_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String role;

  const SplashScreen({super.key, required this.isLoggedIn, required this.role});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..forward();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    Timer(const Duration(seconds: 3), () {
      Widget nextScreen = const LoginScreen();

      if (widget.isLoggedIn) {
        if (widget.role == 'ADMIN') {
          nextScreen = const AdminHomeScreen();
        } else if (widget.role == 'DRIVER' || widget.role == 'CONDUCTOR') {
          nextScreen = const DriverHomeScreen();
        } else if (widget.role == 'OWNER') {
          nextScreen = const OwnerHomeScreen();
        } else {
          nextScreen = const HomeScreen();
        }
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => nextScreen));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.redAccent, Colors.deepOrange],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _animation,
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_bus,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'LankaTransit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
