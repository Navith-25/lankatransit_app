import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingUsers = [];
  List<dynamic> _pendingBuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPendingData();
  }

  Future<void> _fetchPendingData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final userResponse = await http.get(
        Uri.parse('http://10.0.2.2:8081/api/users/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final busResponse = await http.get(
        Uri.parse('http://10.0.2.2:8081/api/buses/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode == 200 && busResponse.statusCode == 200) {
        setState(() {
          _pendingUsers = jsonDecode(userResponse.body);
          _pendingBuses = jsonDecode(busResponse.body);
        });
      }
    } catch (e) {
      _showMessage('Error fetching data!', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveUser(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('http://10.0.2.2:8081/api/users/approve/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('User Approved Successfully! ✅', Colors.green);
        _fetchPendingData();
      }
    } catch (e) {
      _showMessage('Approval Failed!', Colors.red);
    }
  }

  Future<void> _approveBus(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('http://10.0.2.2:8081/api/buses/approve/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('Bus Approved Successfully! 🚌✅', Colors.green);
        _fetchPendingData();
      }
    } catch (e) {
      _showMessage('Approval Failed!', Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Pending Users'),
            Tab(icon: Icon(Icons.directions_bus), text: 'Pending Buses'),
          ],
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _pendingUsers.isEmpty
              ? const Center(child: Text('No pending users! 🎉'))
              : ListView.builder(
            itemCount: _pendingUsers.length,
            itemBuilder: (context, index) {
              var user = _pendingUsers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Text(user['role'][0]),
                  ),
                  title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${user['role']} | ${user['email']}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => _approveUser(user['id']),
                    child: const Text('Approve'),
                  ),
                ),
              );
            },
          ),

          _pendingBuses.isEmpty
              ? const Center(child: Text('No pending buses! 🎉'))
              : ListView.builder(
            itemCount: _pendingBuses.length,
            itemBuilder: (context, index) {
              var bus = _pendingBuses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.directions_bus, color: Colors.white),
                  ),
                  title: Text(bus['busNumber'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Capacity: ${bus['capacity']} | Route ID: ${bus['routeId']}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),

                    onPressed: () => _approveBus(bus['id']),
                    child: const Text('Approve'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}