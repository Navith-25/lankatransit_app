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
                                backgroundColor: Colors.blueAccent,
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
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: staff['status'] == 'APPROVED'
                                      ? Colors.green[100]
                                      : Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  staff['status'],
                                  style: TextStyle(
                                    color: staff['status'] == 'APPROVED'
                                        ? Colors.green[800]
                                        : Colors.orange[800],
                                    fontSize: 12,
                                  ),
                                ),
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
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(
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
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}
