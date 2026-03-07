import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'route_details_screen.dart';
import 'my_tickets_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRoutes();
  }

  Future<void> fetchRoutes() async {
    final url = Uri.parse('http://10.0.2.2:8081/api/routes');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _routes = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        showError('Failed to load routes');
      }
    } catch (e) {
      showError('Server error. Backend eka run wenawada balanna!');
    }
  }

  void showError(String message) {
    setState(() {
      _isLoading = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Available Routes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_num),
            tooltip: 'My Tickets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyTicketsScreen()),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
          ? const Center(child: Text('No routes available.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.directions_bus, color: Colors.white),
              ),
              title: Text(
                'Route ${route['routeNumber']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${route['startLocation']} ➔ ${route['endLocation']}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RouteDetailsScreen(routeData: route),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}