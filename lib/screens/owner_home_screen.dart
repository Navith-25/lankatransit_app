import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "http://10.0.2.2:8081";

  late TabController _tabController;

  List<dynamic> _myBuses = [];
  bool _isLoadingBuses = false;

  List<dynamic> _myStaff = [];
  bool _isLoadingStaff = false;

  List<dynamic> _availableRoutes = [];
  String? _selectedRouteId;

  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  File? _registrationPotha;
  File? _insuranceCard;
  File? _revenueLicense;
  File? _routePermit;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _staffNameController = TextEditingController();
  final TextEditingController _staffEmailController = TextEditingController();
  final TextEditingController _staffPhoneController = TextEditingController();
  final TextEditingController _staffPasswordController =
      TextEditingController();

  String _selectedRole = 'DRIVER';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    _fetchMyBuses();
    _fetchMyStaff();
    _fetchAvailableRoutes();
  }

  Future<void> _fetchAvailableRoutes() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/routes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _availableRoutes = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching routes: $e");
    }
  }

  Future<void> _fetchMyBuses() async {
    setState(() => _isLoadingBuses = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

      if (ownerId == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/buses/owner/$ownerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _myBuses = jsonDecode(response.body);
        });
      }
    } catch (e) {
      _showMessage('Failed to load buses!', Colors.red);
    } finally {
      setState(() => _isLoadingBuses = false);
    }
  }

  Future<void> _fetchMyStaff() async {
    setState(() => _isLoadingStaff = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

      if (ownerId == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/owner/$ownerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _myStaff = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Staff Load Error: $e");
    } finally {
      setState(() => _isLoadingStaff = false);
    }
  }

  Future<bool> _assignCrew(int busId, int? driverId, int? conductorId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/buses/$busId/assign-crew'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'driverId': driverId, 'conductorId': conductorId}),
      );

      if (response.statusCode == 200) {
        _showMessage('Crew Assigned Successfully!', Colors.green);
        _fetchMyBuses();
        return true;
      } else {
        _showMessage('Failed to assign crew.', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error assigning crew.', Colors.red);
      return false;
    }
  }

  Future<void> _deleteStaff(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('Staff member removed!', Colors.green);
        _fetchMyStaff();
      } else {
        _showMessage('Failed to remove staff!', Colors.red);
      }
    } catch (e) {
      _showMessage('Error removing staff!', Colors.red);
    }
  }

  Future<bool> _updateStaff(
    int staffId,
    String name,
    String email,
    String phone,
    String role,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$staffId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Staff Details Updated!', Colors.green);
        _fetchMyStaff();
        return true;
      } else {
        _showMessage('Failed to update staff!', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error updating staff!', Colors.red);
      return false;
    }
  }

  Future<void> _pickImage(String docType, StateSetter setSheetState) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setSheetState(() {
        if (docType == 'registration') _registrationPotha = File(image.path);
        if (docType == 'insurance') _insuranceCard = File(image.path);
        if (docType == 'revenue') _revenueLicense = File(image.path);
        if (docType == 'permit') _routePermit = File(image.path);
      });
    }
  }

  Future<void> _uploadBusDocument(File file, int busId, String endpoint) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/buses/$busId/$endpoint'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload $endpoint');
    }
  }

  Future<bool> _addBus() async {
    if (_busNumberController.text.isEmpty || _capacityController.text.isEmpty) {
      _showMessage('Please enter Bus Number and Capacity', Colors.red);
      return false;
    }

    if (_selectedRouteId == null) {
      _showMessage('Please select a Route for this Bus!', Colors.red);
      return false;
    }

    if (_registrationPotha == null ||
        _insuranceCard == null ||
        _revenueLicense == null ||
        _routePermit == null) {
      _showMessage(
        'Please select all 4 Bus Documents (including Route Permit)!',
        Colors.red,
      );
      return false;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

      final response = await http.post(
        Uri.parse('$baseUrl/api/buses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'busNumber': _busNumberController.text,
          'capacity': int.tryParse(_capacityController.text) ?? 54,
          'ownerId': ownerId,
          'routeId': int.parse(_selectedRouteId!),
          'status': 'PENDING',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        int newBusId = responseData['id'];

        await _uploadBusDocument(
          _registrationPotha!,
          newBusId,
          'upload-registration',
        );
        await _uploadBusDocument(_insuranceCard!, newBusId, 'upload-insurance');
        await _uploadBusDocument(
          _revenueLicense!,
          newBusId,
          'upload-revenue-license',
        );
        await _uploadBusDocument(
          _routePermit!,
          newBusId,
          'upload-route-permit',
        );

        _showMessage('Bus & Documents Added Successfully!', Colors.green);

        _busNumberController.clear();
        _capacityController.clear();
        _selectedRouteId = null;
        _registrationPotha = null;
        _insuranceCard = null;
        _revenueLicense = null;
        _routePermit = null;

        _fetchMyBuses();
        return true;
      } else {
        _showMessage('Failed to add Bus!', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error adding bus: $e', Colors.red);
      return false;
    }
  }

  Future<bool> _resubmitBusDocs(int busId) async {
    if (_registrationPotha == null &&
        _insuranceCard == null &&
        _revenueLicense == null &&
        _routePermit == null) {
      _showMessage(
        'Please select at least one document to update!',
        Colors.red,
      );
      return false;
    }

    try {
      if (_registrationPotha != null)
        await _uploadBusDocument(
          _registrationPotha!,
          busId,
          'upload-registration',
        );
      if (_insuranceCard != null)
        await _uploadBusDocument(_insuranceCard!, busId, 'upload-insurance');
      if (_revenueLicense != null)
        await _uploadBusDocument(
          _revenueLicense!,
          busId,
          'upload-revenue-license',
        );
      if (_routePermit != null)
        await _uploadBusDocument(_routePermit!, busId, 'upload-route-permit');

      _showMessage('Documents Resubmitted Successfully!', Colors.green);

      _registrationPotha = null;
      _insuranceCard = null;
      _revenueLicense = null;
      _routePermit = null;

      _fetchMyBuses();
      return true;
    } catch (e) {
      _showMessage('Error updating documents: $e', Colors.red);
      return false;
    }
  }

  Future<bool> _addStaff() async {
    if (_staffNameController.text.isEmpty ||
        _staffEmailController.text.isEmpty ||
        _staffPasswordController.text.isEmpty) {
      _showMessage('Please fill name, email and password', Colors.red);
      return false;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

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
          'ownerId': ownerId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Staff Account Created Successfully!', Colors.green);
        _staffNameController.clear();
        _staffEmailController.clear();
        _staffPhoneController.clear();
        _staffPasswordController.clear();

        _fetchMyStaff();
        return true;
      } else {
        _showMessage('Failed to add staff!', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error adding staff: $e', Colors.red);
      return false;
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildDocUploadButton(
    String title,
    String docType,
    File? file,
    StateSetter setSheetState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        icon: Icon(
          file == null ? Icons.upload_file : Icons.check_circle,
          color: file == null ? Colors.blue : Colors.green,
        ),
        label: Text(file == null ? 'Upload $title' : '$title Selected'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: file == null ? Colors.blue : Colors.green),
        ),
        onPressed: () => _pickImage(docType, setSheetState),
      ),
    );
  }

  void _showAddBusSheet() {
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
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Register New Bus',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _selectedRouteId,
                  decoration: const InputDecoration(
                    labelText: 'Assign Route',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alt_route, color: Colors.blueAccent),
                  ),
                  items: _availableRoutes.map((route) {
                    return DropdownMenuItem<String>(
                      value: route['id'].toString(),
                      child: Text(
                        'Route ${route['routeNumber']} (${route['startLocation']} - ${route['endLocation']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setSheetState(() => _selectedRouteId = val);
                  },
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: _busNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Bus Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                _buildDocUploadButton(
                  'Registration Potha (CR)',
                  'registration',
                  _registrationPotha,
                  setSheetState,
                ),
                _buildDocUploadButton(
                  'Insurance Card',
                  'insurance',
                  _insuranceCard,
                  setSheetState,
                ),
                _buildDocUploadButton(
                  'Revenue License',
                  'revenue',
                  _revenueLicense,
                  setSheetState,
                ),
                _buildDocUploadButton(
                  'Route Permit',
                  'permit',
                  _routePermit,
                  setSheetState,
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setSheetState(() => _isLoading = true);
                          bool success = await _addBus();
                          if (success) {
                            if (sheetContext.mounted)
                              Navigator.pop(sheetContext);
                          }
                          setSheetState(() => _isLoading = false);
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Bus Data',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResubmitBusSheet(Map<String, dynamic> bus) {
    bool isUpdating = false;

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
                'Resubmit Docs: ${bus['busNumber']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Only upload the documents that are unclear or rejected.',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              _buildDocUploadButton(
                'Registration Potha (CR)',
                'registration',
                _registrationPotha,
                setSheetState,
              ),
              _buildDocUploadButton(
                'Insurance Card',
                'insurance',
                _insuranceCard,
                setSheetState,
              ),
              _buildDocUploadButton(
                'Revenue License',
                'revenue',
                _revenueLicense,
                setSheetState,
              ),
              _buildDocUploadButton(
                'Route Permit',
                'permit',
                _routePermit,
                setSheetState,
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: isUpdating
                    ? null
                    : () async {
                        setSheetState(() => isUpdating = true);
                        bool success = await _resubmitBusDocs(bus['id']);
                        if (success && sheetContext.mounted)
                          Navigator.pop(sheetContext);
                        setSheetState(() => isUpdating = false);
                      },
                child: isUpdating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Resubmit Documents',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignCrewSheet(Map<String, dynamic> bus) {
    List<dynamic> drivers = _myStaff
        .where((s) => s['role'] == 'DRIVER' && s['status'] == 'APPROVED')
        .toList();
    List<dynamic> conductors = _myStaff
        .where((s) => s['role'] == 'CONDUCTOR' && s['status'] == 'APPROVED')
        .toList();

    String? selectedDriverId = bus['driverId']?.toString();
    String? selectedConductorId = bus['conductorId']?.toString();

    if (selectedDriverId != null &&
        !drivers.any((d) => d['id'].toString() == selectedDriverId)) {
      selectedDriverId = null;
    }
    if (selectedConductorId != null &&
        !conductors.any((c) => c['id'].toString() == selectedConductorId)) {
      selectedConductorId = null;
    }

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
                'Assign Crew for ${bus['busNumber']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: selectedDriverId,
                decoration: const InputDecoration(
                  labelText: 'Select Driver (Approved Only)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sports_motorsports),
                ),
                items: drivers.map((driver) {
                  return DropdownMenuItem<String>(
                    value: driver['id'].toString(),
                    child: Text(
                      '${driver['name']} (${driver['phone'] ?? 'No phone'})',
                    ),
                  );
                }).toList(),
                onChanged: (val) => setSheetState(() => selectedDriverId = val),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: selectedConductorId,
                decoration: const InputDecoration(
                  labelText: 'Select Conductor (Approved Only)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                items: conductors.map((cond) {
                  return DropdownMenuItem<String>(
                    value: cond['id'].toString(),
                    child: Text(
                      '${cond['name']} (${cond['phone'] ?? 'No phone'})',
                    ),
                  );
                }).toList(),
                onChanged: (val) =>
                    setSheetState(() => selectedConductorId = val),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setSheetState(() => isSubmitting = true);
                        int? dId = selectedDriverId != null
                            ? int.parse(selectedDriverId!)
                            : null;
                        int? cId = selectedConductorId != null
                            ? int.parse(selectedConductorId!)
                            : null;

                        bool success = await _assignCrew(bus['id'], dId, cId);
                        if (success && sheetContext.mounted)
                          Navigator.pop(sheetContext);
                        setSheetState(() => isSubmitting = false);
                      },
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Assignments',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStaffSheet() {
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Driver / Conductor',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _staffNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _staffEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _staffPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _staffPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Create Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                    DropdownMenuItem(
                      value: 'CONDUCTOR',
                      child: Text('Conductor'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setSheetState(() => _isLoading = true);
                          bool success = await _addStaff();
                          if (success && sheetContext.mounted)
                            Navigator.pop(sheetContext);
                          setSheetState(() => _isLoading = false);
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Add Staff Member',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditStaffSheet(Map<String, dynamic> staff) {
    final TextEditingController editNameCtrl = TextEditingController(
      text: staff['name'],
    );
    final TextEditingController editEmailCtrl = TextEditingController(
      text: staff['email'],
    );
    final TextEditingController editPhoneCtrl = TextEditingController(
      text: staff['phone'] ?? '',
    );
    String editRole = staff['role'] ?? 'DRIVER';
    bool isUpdating = false;

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
                'Edit Staff Details',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: editNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: editEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: editPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: editRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                  DropdownMenuItem(
                    value: 'CONDUCTOR',
                    child: Text('Conductor'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setSheetState(() => editRole = val);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: isUpdating
                    ? null
                    : () async {
                        setSheetState(() => isUpdating = true);
                        bool success = await _updateStaff(
                          staff['id'],
                          editNameCtrl.text,
                          editEmailCtrl.text,
                          editPhoneCtrl.text,
                          editRole,
                        );
                        if (success && sheetContext.mounted)
                          Navigator.pop(sheetContext);
                        setSheetState(() => isUpdating = false);
                      },
                child: isUpdating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Update Staff'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Welcome, Owner! 🚌',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              onTap: _showAddBusSheet,
              borderRadius: BorderRadius.circular(15),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      size: 60,
                      color: Colors.blueAccent,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Register New Bus',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              onTap: _showAddStaffSheet,
              borderRadius: BorderRadius.circular(15),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 60, color: Colors.green),
                    SizedBox(height: 15),
                    Text(
                      'Add Driver / Conductor',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyFleetTab() {
    if (_isLoadingBuses)
      return const Center(child: CircularProgressIndicator());
    if (_myBuses.isEmpty)
      return const Center(
        child: Text('No buses found!', style: TextStyle(fontSize: 16)),
      );

    return RefreshIndicator(
      onRefresh: _fetchMyBuses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myBuses.length,
        itemBuilder: (context, index) {
          var bus = _myBuses[index];
          String status = bus['status'] ?? 'PENDING';

          Color statusColor = Colors.orange;
          IconData statusIcon = Icons.pending;

          if (status == 'APPROVED') {
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
          } else if (status == 'REJECTED') {
            statusColor = Colors.red;
            statusIcon = Icons.cancel;
          } else if (status == 'RESUBMIT') {
            statusColor = Colors.blueAccent;
            statusIcon = Icons.upload_file;
          }

          Widget? trailingWidget;
          if (status == 'RESUBMIT' || status == 'REJECTED') {
            trailingWidget = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _showResubmitBusSheet(bus),
              child: const Text('Edit'),
            );
          } else if (status == 'APPROVED') {
            trailingWidget = ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _showAssignCrewSheet(bus),
              icon: const Icon(Icons.people, size: 18),
              label: const Text('Assign Crew'),
            );
          }

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(15),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: statusColor.withOpacity(0.2),
                child: Icon(statusIcon, color: statusColor, size: 30),
              ),
              title: Text(
                bus['busNumber'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Route ID: ${bus['routeId'] ?? 'N/A'}\nDriver ID: ${bus['driverId'] ?? 'Unassigned'} | Cond: ${bus['conductorId'] ?? 'Unassigned'}\nStatus: $status',
                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                ),
              ),
              isThreeLine: true,
              trailing: trailingWidget,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyStaffTab() {
    if (_isLoadingStaff)
      return const Center(child: CircularProgressIndicator());
    if (_myStaff.isEmpty)
      return const Center(
        child: Text(
          'No staff members added yet!',
          style: TextStyle(fontSize: 16),
        ),
      );

    return RefreshIndicator(
      onRefresh: _fetchMyStaff,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myStaff.length,
        itemBuilder: (context, index) {
          var staff = _myStaff[index];
          String role = staff['role'] ?? 'USER';
          String status = staff['status'] ?? 'PENDING';
          Color statusColor = status == 'APPROVED'
              ? Colors.green
              : (status == 'REJECTED'
                    ? Colors.red
                    : (status == 'RESUBMIT'
                          ? Colors.blueAccent
                          : Colors.orange));

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.2),
                child: Icon(
                  role == 'DRIVER'
                      ? Icons.sports_motorsports
                      : Icons.confirmation_number,
                  color: statusColor,
                ),
              ),
              title: Text(
                staff['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Text(
                '$role | ${staff['phone'] ?? staff['email']}\nStatus: $status',
                style: const TextStyle(height: 1.4),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _showEditStaffSheet(staff),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove Staff?'),
                          content: Text(
                            'Are you sure you want to remove ${staff['name']}?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _deleteStaff(staff['id']);
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Owner Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Home'),
            Tab(icon: Icon(Icons.directions_bus), text: 'My Fleet'),
            Tab(icon: Icon(Icons.people), text: 'My Staff'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildMyFleetTab(),
          _buildMyStaffTab(),
        ],
      ),
    );
  }
}
