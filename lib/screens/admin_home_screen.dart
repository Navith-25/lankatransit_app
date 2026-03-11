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

  final String baseUrl = "http://10.0.2.2:8081";

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

      print("--- FETCHING PENDING DATA START ---");

      final userResponse = await http.get(
        Uri.parse('$baseUrl/api/users/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("User API Status Code: ${userResponse.statusCode}");
      print("User API Response Body: ${userResponse.body}");

      if (userResponse.statusCode == 200) {
        setState(() {
          _pendingUsers = jsonDecode(userResponse.body);
        });
      } else {
        _showMessage('Failed to load Users (Code: ${userResponse.statusCode})', Colors.orange);
      }

      final busResponse = await http.get(
        Uri.parse('$baseUrl/api/buses/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      print("Bus API Status Code: ${busResponse.statusCode}");
      print("Bus API Response Body: ${busResponse.body}");

      if (busResponse.statusCode == 200) {
        setState(() {
          _pendingBuses = jsonDecode(busResponse.body);
        });
      } else {
        print("Failed to load Buses (Code: ${busResponse.statusCode})");
      }

    } catch (e) {
      print("--- ERROR CAUGHT --- : $e");
      _showMessage('Error fetching data! Is backend running?', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDocumentDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Documents: ${user['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDocImage('Profile Photo', user['profilePhotoUrl']),
                _buildDocImage('NIC Front', user['nicFrontUrl']),
                _buildDocImage('NIC Back', user['nicBackUrl']),
                _buildDocImage('License', user['licensePhotoUrl']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _approveUser(user['id']);
            },
            child: const Text('Approve Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocImage(String title, String? url) {
    if (url != null && url.isNotEmpty) {
      print("Trying to load image for $title: $baseUrl$url");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        url != null && url.isNotEmpty
            ? Image.network(
          '$baseUrl$url',
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print("IMAGE ERROR FOR $title: $error");
            return Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(
                child: Text('Failed to load image from server', style: TextStyle(color: Colors.red)),
              ),
            );
          },
        )
            : const Text('No document uploaded', style: TextStyle(color: Colors.grey)),
        const Divider(),
      ],
    );
  }

  Future<void> _approveUser(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/approve/$id'),
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
        Uri.parse('$baseUrl/api/buses/approve/$id'),
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
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.directions_bus), text: 'Buses'),
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
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${user['role']} | ${user['email']}'),
                  trailing: ElevatedButton(
                    onPressed: () => _showDocumentDialog(user),
                    child: const Text('View Docs'),
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
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(bus['busNumber'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Capacity: ${bus['capacity']}'),
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