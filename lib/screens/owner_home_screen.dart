import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final String baseUrl = "http://10.0.2.2:8081";

  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  final TextEditingController _staffNameController = TextEditingController();
  final TextEditingController _staffEmailController = TextEditingController();
  final TextEditingController _staffPhoneController = TextEditingController();
  final TextEditingController _staffPasswordController = TextEditingController();

  String _selectedRole = 'DRIVER';
  bool _isLoading = false;

  Future<bool> _addBus() async {
    if (_busNumberController.text.isEmpty || _capacityController.text.isEmpty) {
      _showMessage('Please fill all fields', Colors.red);
      return false;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/buses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'busNumber': _busNumberController.text,
          'capacity': int.tryParse(_capacityController.text) ?? 54,
          'status': 'PENDING',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Bus Added Successfully! Waiting for Admin Approval.', Colors.green);
        _busNumberController.clear();
        _capacityController.clear();
        return true;
      } else {
        _showMessage('Failed to add Bus! (Code: ${response.statusCode})', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error adding bus: $e', Colors.red);
      return false;
    }
  }

  Future<bool> _addStaff() async {
    if (_staffNameController.text.isEmpty || _staffEmailController.text.isEmpty || _staffPasswordController.text.isEmpty) {
      _showMessage('Please fill name, email and password', Colors.red);
      return false;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/add-staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _staffNameController.text,
          'email': _staffEmailController.text,
          'phone': _staffPhoneController.text,
          'passwordHash': _staffPasswordController.text,
          'role': _selectedRole,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Staff Account Created Successfully!', Colors.green);
        _staffNameController.clear();
        _staffEmailController.clear();
        _staffPhoneController.clear();
        _staffPasswordController.clear();
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _showMessage(data['message'] ?? 'Invalid request', Colors.red);
        return false;
      } else {
        _showMessage('Failed to add staff! (Code: ${response.statusCode})', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error adding staff: $e', Colors.red);
      return false;
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 4)));
  }

  void _showAddBusSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Register New Bus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: _busNumberController, decoration: const InputDecoration(labelText: 'Bus Number (e.g. WP ND-1234)', border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _capacityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity (Seats)', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: _isLoading ? null : () async {
                    setSheetState(() => _isLoading = true);
                    bool success = await _addBus();
                    if (success) {
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } else {
                      setSheetState(() => _isLoading = false);
                    }
                  },
                  child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Submit Bus', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddStaffSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add Driver / Conductor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: _staffNameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _staffEmailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: _staffPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder())),
                const SizedBox(height: 15),

                TextField(
                  controller: _staffPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Create Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                    DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: _isLoading ? null : () async {
                    setSheetState(() => _isLoading = true);
                    bool success = await _addStaff();
                    if (success) {
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } else {
                      setSheetState(() => _isLoading = false);
                    }
                  },
                  child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Add Staff Member', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Owner Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Welcome, Owner! 🚌',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Manage your fleet and staff from here.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: InkWell(
                onTap: _showAddBusSheet,
                borderRadius: BorderRadius.circular(15),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                  child: Column(
                    children: [
                      Icon(Icons.directions_bus, size: 60, color: Colors.blueAccent),
                      SizedBox(height: 15),
                      Text('Register New Bus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text('Add a new bus to the LankaTransit system', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: InkWell(
                onTap: _showAddStaffSheet,
                borderRadius: BorderRadius.circular(15),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                  child: Column(
                    children: [
                      Icon(Icons.person_add, size: 60, color: Colors.green),
                      SizedBox(height: 15),
                      Text('Add Driver / Conductor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text('Create accounts for your staff members', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}