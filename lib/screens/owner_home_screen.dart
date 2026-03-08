import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _routeIdController = TextEditingController();

  final TextEditingController _staffNameController = TextEditingController();
  final TextEditingController _staffEmailController = TextEditingController();
  String _selectedRole = 'DRIVER';

  Future<void> _addBus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    final url = Uri.parse('http://10.0.2.2:8081/api/buses/add');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'busNumber': _busNumberController.text,
          'capacity': int.tryParse(_capacityController.text) ?? 50,
          'routeId': int.tryParse(_routeIdController.text) ?? 1,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Bus Added Successfully! Waiting for Admin Approval.', Colors.green);
        Navigator.pop(context);
      } else {
        _showMessage('Failed to add bus', Colors.red);
      }
    } catch (e) {
      _showMessage('Server Error', Colors.red);
    }
  }

  Future<void> _addStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    final url = Uri.parse('http://10.0.2.2:8081/api/users/add-staff');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _staffNameController.text,
          'email': _staffEmailController.text,
          'role': _selectedRole,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showMessage('${data['message']}\nTemp Password: ${data['temporaryPassword']}', Colors.green);
        Navigator.pop(context);
      } else {
        _showMessage('Failed to add staff', Colors.red);
      }
    } catch (e) {
      _showMessage('Server Error', Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _showAddBusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Bus 🚌'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _busNumberController, decoration: const InputDecoration(labelText: 'Bus Number (ex: ND-1234)')),
            TextField(controller: _capacityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seating Capacity')),
            TextField(controller: _routeIdController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Route ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _addBus, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), child: const Text('Submit')),
        ],
      ),
    );
  }

  void _showAddStaffDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Staff 👥'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _staffNameController, decoration: const InputDecoration(labelText: 'Full Name')),
              TextField(controller: _staffEmailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address')),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Select Role'),
                items: const [
                  DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                  DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                ],
                onChanged: (val) {
                  setState(() => _selectedRole = val!);
                },
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: _addStaff, style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white), child: const Text('Submit')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_center, size: 80, color: Colors.purple),
            const SizedBox(height: 20),
            const Text('Manage Your Fleet', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            ElevatedButton.icon(
              icon: const Icon(Icons.directions_bus),
              label: const Text('Register New Bus', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: _showAddBusDialog,
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Add Driver / Conductor', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              onPressed: _showAddStaffDialog,
            ),
          ],
        ),
      ),
    );
  }
}