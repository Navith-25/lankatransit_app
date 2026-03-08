import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            const Text('Welcome, Driver!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Going Online... GPS Started!')));
              },
              child: const Text('GO ONLINE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}