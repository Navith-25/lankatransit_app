import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'route_management_screen.dart';
import 'owner_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingUsers = [];
  List<dynamic> _pendingBuses = [];
  bool _isLoading = true;

  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

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
        Uri.parse('$baseUrl/api/users/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode == 200) {
        setState(() {
          _pendingUsers = jsonDecode(userResponse.body);
        });
      }

      final busResponse = await http.get(
        Uri.parse('$baseUrl/api/buses/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (busResponse.statusCode == 200) {
        setState(() {
          _pendingBuses = jsonDecode(busResponse.body);
        });
      }
    } catch (e) {
      _showMessage('Error fetching data!', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showUserDocumentDialog(Map<String, dynamic> user) {
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
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _approveUser(user['id']);
                  },
                  child: const Text('Approve'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _resubmitUser(user['id']);
                  },
                  child: const Text('Resubmit Docs'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectUser(user['id']);
                  },
                  child: const Text('Reject'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBusDocumentDialog(Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bus Docs: ${bus['busNumber']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDocImage(
                  'Registration Potha (CR)',
                  bus['registrationPothaUrl'],
                ),
                _buildDocImage('Insurance Card', bus['insuranceCardUrl']),
                _buildDocImage('Revenue License', bus['revenueLicenseUrl']),
                _buildDocImage('Route Permit', bus['routePermitUrl']),
              ],
            ),
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _approveBus(bus['id']);
                  },
                  child: const Text('Approve Bus'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _resubmitBus(bus['id']);
                  },
                  child: const Text('Resubmit Docs'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectBus(bus['id']);
                  },
                  child: const Text('Reject Bus'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocImage(String title, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        url != null && url.isNotEmpty
            ? Image.network(
                '$baseUrl$url',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Text(
                      'Image not found',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              )
            : const Text(
                'No document uploaded',
                style: TextStyle(color: Colors.grey),
              ),
        const Divider(),
      ],
    );
  }

  Future<void> _approveUser(int id) async =>
      _updateStatus('users/approve', id, 'User Approved! ✅', Colors.green);
  Future<void> _rejectUser(int id) async =>
      _updateStatus('users/reject', id, 'User Rejected! ❌', Colors.red);
  Future<void> _resubmitUser(int id) async => _updateStatus(
    'users/resubmit',
    id,
    'Requested to Resubmit Docs! 🔄',
    Colors.orange,
  );

  Future<void> _approveBus(int id) async =>
      _updateStatus('buses/approve', id, 'Bus Approved! 🚌✅', Colors.green);
  Future<void> _rejectBus(int id) async =>
      _updateStatus('buses/reject', id, 'Bus Rejected! 🚌❌', Colors.red);
  Future<void> _resubmitBus(int id) async => _updateStatus(
    'buses/resubmit',
    id,
    'Requested to Resubmit Bus Docs! 🔄',
    Colors.orange,
  );

  Future<void> _updateStatus(
    String endpoint,
    int id,
    String successMsg,
    Color color,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/$endpoint/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage(successMsg, color);
        _fetchPendingData();
      }
    } catch (e) {
      _showMessage('Action Failed!', Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            icon: const Icon(Icons.business_center),
            tooltip: 'Manage Owners',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OwnerManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: 'Manage Routes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RouteManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
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
              if (!context.mounted) return;
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
                              title: Text(
                                user['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${user['role']} | ${user['email']}',
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _showUserDocumentDialog(user),
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
                              title: Text(
                                bus['busNumber'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Capacity: ${bus['capacity']} | Route ID: ${bus['routeId']}',
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _showBusDocumentDialog(bus),
                                child: const Text('View Docs'),
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
