import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OwnerDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> owner;

  const OwnerDetailsScreen({super.key, required this.owner});

  @override
  State<OwnerDetailsScreen> createState() => _OwnerDetailsScreenState();
}

class _OwnerDetailsScreenState extends State<OwnerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _staffList = [];
  List<dynamic> _busList = [];
  bool _isLoading = true;

  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOwnerDetails();
  }

  Future<void> _fetchOwnerDetails() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int ownerId = widget.owner['id'];

      final staffResponse = await http.get(
        Uri.parse('$baseUrl/api/users/owner/$ownerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (staffResponse.statusCode == 200) {
        setState(() {
          _staffList = jsonDecode(staffResponse.body);
        });
      }

      final busResponse = await http.get(
        Uri.parse('$baseUrl/api/buses/owner/$ownerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (busResponse.statusCode == 200) {
        setState(() {
          _busList = jsonDecode(busResponse.body);
        });
      }
    } catch (e) {
      _showMessage('Error fetching details!', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _suspendStaff(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/suspend/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _showMessage('Staff Suspended successfully!', Colors.orange);
        _fetchOwnerDetails();
      } else {
        _showMessage('Failed to suspend staff!', Colors.red);
      }
    } catch (e) {
      _showMessage('Error suspending staff!', Colors.red);
    }
  }

  Future<void> _activateStaff(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      final response = await http.put(
        Uri.parse(
          '$baseUrl/api/users/approve/$id',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _showMessage('Staff Activated successfully!', Colors.green);
        _fetchOwnerDetails();
      } else {
        _showMessage('Failed to activate staff!', Colors.red);
      }
    } catch (e) {
      _showMessage('Error activating staff!', Colors.red);
    }
  }

  Future<void> _suspendBus(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      final response = await http.put(
        Uri.parse('$baseUrl/api/buses/suspend/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _showMessage('Bus Suspended successfully!', Colors.orange);
        _fetchOwnerDetails();
      } else {
        _showMessage('Failed to suspend bus!', Colors.red);
      }
    } catch (e) {
      _showMessage('Error suspending bus!', Colors.red);
    }
  }

  Future<void> _activateBus(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      final response = await http.put(
        Uri.parse(
          '$baseUrl/api/buses/approve/$id',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _showMessage('Bus Activated successfully!', Colors.green);
        _fetchOwnerDetails();
      } else {
        _showMessage('Failed to activate bus!', Colors.red);
      }
    } catch (e) {
      _showMessage('Error activating bus!', Colors.red);
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
        title: Text(
          '${widget.owner['name']}\'s Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Staff'),
            Tab(icon: Icon(Icons.directions_bus), text: 'Buses'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _staffList.isEmpty
                    ? const Center(
                        child: Text('No staff found for this owner.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _staffList.length,
                        itemBuilder: (context, index) {
                          var staff = _staffList[index];
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: staff['status'] == 'SUSPENDED'
                                    ? Colors.red
                                    : Colors.blueAccent,
                                child: Icon(
                                  staff['role'] == 'DRIVER'
                                      ? Icons.drive_eta
                                      : Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                staff['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${staff['role']} | ${staff['email']}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: staff['status'] == 'APPROVED'
                                          ? Colors.green[100]
                                          : (staff['status'] == 'SUSPENDED'
                                              ? Colors.red[100]
                                              : Colors.orange[100]),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      staff['status'],
                                      style: TextStyle(
                                        color: staff['status'] == 'APPROVED'
                                            ? Colors.green[800]
                                            : (staff['status'] == 'SUSPENDED'
                                                ? Colors.red[800]
                                                : Colors.orange[800]),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (staff['status'] != 'SUSPENDED')
                                    IconButton(
                                      icon: const Icon(
                                        Icons.block,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Suspend Staff',
                                      onPressed: () =>
                                          _suspendStaff(staff['id']),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Activate Staff',
                                      onPressed: () =>
                                          _activateStaff(staff['id']),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                _busList.isEmpty
                    ? const Center(
                        child: Text('No buses found for this owner.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _busList.length,
                        itemBuilder: (context, index) {
                          var bus = _busList[index];
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: bus['status'] == 'SUSPENDED'
                                    ? Colors.red
                                    : Colors.green,
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                bus['busNumber'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Route ID: ${bus['routeId']} | Capacity: ${bus['capacity']}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bus['status'] == 'APPROVED'
                                          ? Colors.green[100]
                                          : (bus['status'] == 'SUSPENDED'
                                              ? Colors.red[100]
                                              : Colors.orange[100]),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      bus['status'] ?? 'N/A',
                                      style: TextStyle(
                                        color: bus['status'] == 'APPROVED'
                                            ? Colors.green[800]
                                            : (bus['status'] == 'SUSPENDED'
                                                ? Colors.red[800]
                                                : Colors.orange[800]),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (bus['status'] != 'SUSPENDED')
                                    IconButton(
                                      icon: const Icon(
                                        Icons.block,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Suspend Bus',
                                      onPressed: () => _suspendBus(bus['id']),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Activate Bus',
                                      onPressed: () => _activateBus(bus['id']),
                                    ),
                                ],
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
