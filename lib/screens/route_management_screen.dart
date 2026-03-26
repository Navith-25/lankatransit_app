import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_route_map_screen.dart';
import 'add_halt_map_screen.dart';

class RouteManagementScreen extends StatefulWidget {
  const RouteManagementScreen({super.key});
  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

  List<dynamic> _routes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/routes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _routes = jsonDecode(response.body);
        });
      }
    } catch (e) {
      _showMessage('Failed to load routes!', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openMapRouteCreator() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddRouteMapScreen()),
    );

    if (result == true) {
      _fetchRoutes();
    }
  }

  Future<bool> _updateRoute(int routeId, String routeNo, String startLoc,
      String endLoc, double fare) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/routes/$routeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'routeNumber': routeNo,
          'startLocation': startLoc,
          'endLocation': endLoc,
          'baseFarePerKm': fare,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Route Updated Successfully!', Colors.green);
        _fetchRoutes();
        return true;
      } else {
        _showMessage('Failed to update route.', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error updating route.', Colors.red);
      return false;
    }
  }

  Future<void> _deleteRoute(int routeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/routes/$routeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('Route Deleted Successfully!', Colors.green);
        _fetchRoutes();
      } else {
        _showMessage('Failed to delete route.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error deleting route.', Colors.red);
    }
  }

  Future<bool> _addHalt(
    int routeId,
    String haltName,
    double distance,
    int sequence,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/routes/$routeId/halts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'haltName': haltName,
          'distanceFromStart': distance,
          'sequenceOrder': sequence,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Halt Added Successfully!', Colors.green);
        return true;
      } else {
        _showMessage('Failed to add halt.', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error adding halt.', Colors.red);
      return false;
    }
  }

  Future<List<dynamic>> _getHaltsForRoute(int routeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/routes/$routeId/halts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showEditRouteSheet(dynamic route) {
    final TextEditingController routeNoCtrl =
        TextEditingController(text: route['routeNumber']);
    final TextEditingController startLocCtrl =
        TextEditingController(text: route['startLocation']);
    final TextEditingController endLocCtrl =
        TextEditingController(text: route['endLocation']);
    final TextEditingController fareCtrl =
        TextEditingController(text: route['baseFarePerKm'].toString());
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Route Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: routeNoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Route Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: startLocCtrl,
                decoration: const InputDecoration(
                    labelText: 'Start Location', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: endLocCtrl,
                decoration: const InputDecoration(
                    labelText: 'End Location', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: fareCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Base Fare Per KM (Rs.)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (routeNoCtrl.text.isEmpty || fareCtrl.text.isEmpty)
                          return;
                        setSheetState(() => isSubmitting = true);
                        bool success = await _updateRoute(
                          route['id'],
                          routeNoCtrl.text,
                          startLocCtrl.text,
                          endLocCtrl.text,
                          double.parse(fareCtrl.text),
                        );
                        if (success && sheetContext.mounted)
                          Navigator.pop(sheetContext);
                        setSheetState(() => isSubmitting = false);
                      },
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Update Route'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddHaltSheet(dynamic route) {
    final TextEditingController haltNameCtrl = TextEditingController();
    final TextEditingController distanceCtrl = TextEditingController();
    final TextEditingController sequenceCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Halt to ${route['routeNumber']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: haltNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Halt Name (e.g. Panadura)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: distanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Distance from Start (KM)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: sequenceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sequence Order (1, 2, 3...)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (haltNameCtrl.text.isEmpty ||
                            distanceCtrl.text.isEmpty ||
                            sequenceCtrl.text.isEmpty) return;
                        setSheetState(() => isSubmitting = true);
                        bool success = await _addHalt(
                          route['id'],
                          haltNameCtrl.text,
                          double.parse(distanceCtrl.text),
                          int.parse(sequenceCtrl.text),
                        );
                        if (success && sheetContext.mounted)
                          Navigator.pop(sheetContext);
                        setSheetState(() => isSubmitting = false);
                      },
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Halt'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showHaltsDialog(dynamic route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Halts: Route ${route['routeNumber']}'),
        content: FutureBuilder<List<dynamic>>(
          future: _getHaltsForRoute(route['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Failed to load halts.');
            }

            List<dynamic> halts = snapshot.data!;
            if (halts.isEmpty) return const Text('No halts added yet.');

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: halts.length,
                itemBuilder: (context, index) {
                  var halt = halts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${halt['sequenceOrder']}'),
                    ),
                    title: Text(
                      halt['haltName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${halt['distanceFromStart']} KM from start',
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Route Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openMapRouteCreator,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.map),
        label: const Text('Add Route via Map'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
              ? const Center(
                  child: Text('No routes available. Add a new route!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    var route = _routes[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Route: ${route['routeNumber']}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.orange),
                                      onPressed: () =>
                                          _showEditRouteSheet(route),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Route?'),
                                            content: Text(
                                                'Are you sure you want to delete Route ${route['routeNumber']}? This will remove all its halts.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor:
                                                        Colors.white),
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  _deleteRoute(route['id']);
                                                },
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              'Fare/KM: Rs.${route['baseFarePerKm']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${route['startLocation']} ➔ ${route['endLocation']}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Divider(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showHaltsDialog(route),
                                  icon: const Icon(Icons.list),
                                  label: const Text('View Halts'),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddHaltMapScreen(routeData: route),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add_location_alt),
                                  label: const Text('Add Halt (Map)'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
