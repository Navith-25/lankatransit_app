import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'route_details_screen.dart';
import 'my_tickets_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _routes = [];
  List<dynamic> _filteredRoutes = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

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
          _filteredRoutes = _routes;
          _isLoading = false;
        });
      } else {
        showError('Failed to load routes');
      }
    } catch (e) {
      showError('Server error.');
    }
  }

  void _filterRoutes(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredRoutes = _routes;
      });
    } else {
      setState(() {
        _filteredRoutes = _routes.where((route) {
          final routeNum = route['routeNumber']?.toString().toLowerCase() ?? '';
          final startLoc =
              route['startLocation']?.toString().toLowerCase() ?? '';
          final endLoc = route['endLocation']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return routeNum.contains(searchLower) ||
              startLoc.contains(searchLower) ||
              endLoc.contains(searchLower);
        }).toList();
      });
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
        title: const Text(
          'Find Buses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_num),
            tooltip: 'My Tickets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyTicketsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
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
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterRoutes,
                      decoration: const InputDecoration(
                        hintText: 'Search Route No, Start or End...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.blueAccent,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _filteredRoutes.isEmpty
                      ? const Center(
                          child: Text(
                            'No routes found matching your search.',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filteredRoutes.length,
                          itemBuilder: (context, index) {
                            final route = _filteredRoutes[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: const CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.blueAccent,
                                  child: Icon(
                                    Icons.directions_bus,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  'Route ${route['routeNumber']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    '${route['startLocation'] ?? 'Unknown'} ➔ ${route['endLocation'] ?? 'Unknown'}',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.blueAccent,
                                ),

                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RouteDetailsScreen(routeData: route),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
