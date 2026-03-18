import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'ticket_scanner_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final String baseUrl = "http://10.0.2.2:8081";

  File? _profilePhoto;
  File? _nicFront;
  File? _nicBack;
  File? _license;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _userName = "User";
  String _userRole = "DRIVER";
  String _userStatus = "PENDING";
  int? _userId;

  bool _hasSubmittedDocs = false;

  Map<String, dynamic>? _assignedBus;
  Map<String, dynamic>? _assignedRoute;
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _partnerInfo;
  bool _isLoadingData = false;

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('user_id');
      _userName = prefs.getString('user_name') ?? "User";
      _userRole = prefs.getString('user_role') ?? "DRIVER";
      _userStatus = prefs.getString('user_status') ?? "CREATED";
      _hasSubmittedDocs = prefs.getBool('has_submitted_docs') ?? false;

      if (_userStatus == 'REJECTED' || _userStatus == 'RESUBMIT') {
        _hasSubmittedDocs = false;
      }
    });

    if (_userStatus == 'APPROVED') {
      _fetchAssignmentAndTripData();
    }
  }

  Future<void> _fetchAssignmentAndTripData() async {
    setState(() => _isLoadingData = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      if (_userId == null) return;

      final busRes = await http.get(
        Uri.parse('$baseUrl/api/buses'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (busRes.statusCode == 200) {
        List<dynamic> buses = jsonDecode(busRes.body);
        try {
          _assignedBus = buses.firstWhere(
            (b) => _userRole == 'DRIVER'
                ? b['driverId'] == _userId
                : b['conductorId'] == _userId,
          );
        } catch (e) {
          _assignedBus = null;
        }
      }

      if (_assignedBus != null) {
        if (_assignedBus!['routeId'] != null) {
          final routeRes = await http.get(
            Uri.parse('$baseUrl/api/routes'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (routeRes.statusCode == 200) {
            List<dynamic> routes = jsonDecode(routeRes.body);
            try {
              _assignedRoute = routes.firstWhere(
                (r) => r['id'] == _assignedBus!['routeId'],
              );
            } catch (e) {
              _assignedRoute = null;
            }
          }
        }

        if (_assignedBus!['ownerId'] != null) {
          final staffRes = await http.get(
            Uri.parse('$baseUrl/api/users/owner/${_assignedBus!['ownerId']}'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (staffRes.statusCode == 200) {
            List<dynamic> staffList = jsonDecode(staffRes.body);
            int? partnerId = _userRole == 'DRIVER'
                ? _assignedBus!['conductorId']
                : _assignedBus!['driverId'];
            if (partnerId != null) {
              try {
                _partnerInfo = staffList.firstWhere(
                  (s) => s['id'] == partnerId,
                );
              } catch (e) {
                _partnerInfo = null;
              }
            }
          }
        }
      }

      if (_userRole == 'DRIVER') {
        final tripRes = await http.get(
          Uri.parse('$baseUrl/api/trips/active/driver/$_userId'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (tripRes.statusCode == 200 && tripRes.body.isNotEmpty) {
          _activeTrip = jsonDecode(tripRes.body);
          _startLocationTracking();
        } else {
          _activeTrip = null;
        }
      }
    } catch (e) {
      print("Data fetch error: $e");
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage(
        'Location services are disabled. Please enable GPS.',
        Colors.red,
      );
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage('Location permissions are denied', Colors.red);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage('Location permissions are permanently denied.', Colors.red);
      return false;
    }
    return true;
  }

  void _startLocationTracking() {
    if (_locationTimer != null && _locationTimer!.isActive) return;
    print("Started Live GPS Tracking...");
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (Timer t) => _sendLocationToBackend(),
    );
  }

  Future<void> _sendLocationToBackend() async {
    if (_activeTrip == null) return;
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      await http.put(
        Uri.parse('$baseUrl/api/trips/${_activeTrip!['id']}/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );
    } catch (e) {
      print("Error sending location: $e");
    }
  }

  Future<void> _startTrip() async {
    if (_assignedBus == null || _assignedRoute == null) return;
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() => _isLoadingData = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/trips/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'busId': _assignedBus!['id'],
          'routeId': _assignedRoute!['id'],
          'driverId': _userId,
          'conductorId': _assignedBus!['conductorId'],
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Trip Started Successfully! GPS ON.', Colors.green);
        await _fetchAssignmentAndTripData();
      } else {
        _showMessage('Failed to start trip.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error starting trip.', Colors.red);
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _endTrip() async {
    if (_activeTrip == null) return;
    setState(() => _isLoadingData = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/trips/${_activeTrip!['id']}/end'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('Trip Ended Successfully!', Colors.blue);
        _locationTimer?.cancel();
        _fetchAssignmentAndTripData();
      } else {
        _showMessage('Failed to end trip.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error ending trip.', Colors.red);
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickImage(String docType) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (docType == 'profile') _profilePhoto = File(image.path);
        if (docType == 'nic_front') _nicFront = File(image.path);
        if (docType == 'nic_back') _nicBack = File(image.path);
        if (docType == 'license') _license = File(image.path);
      });
    }
  }

  Future<void> _uploadSingleDocument(
    File file,
    int userId,
    String endpoint,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/users/$userId/$endpoint'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    if (response.statusCode != 200)
      throw Exception('Failed to upload $endpoint');
  }

  Future<void> _submitAllDocuments() async {
    if (_profilePhoto == null || _nicFront == null || _nicBack == null) {
      _showMessage('Please select Profile Photo and NIC!', Colors.red);
      return;
    }
    if (_userRole == 'DRIVER' && _license == null) {
      _showMessage('Drivers must upload License!', Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      String? token = prefs.getString('jwt_token');

      await _uploadSingleDocument(
        _profilePhoto!,
        userId!,
        'upload-profile-photo',
      );
      await _uploadSingleDocument(_nicFront!, userId, 'upload-nic-front');
      await _uploadSingleDocument(_nicBack!, userId, 'upload-nic-back');
      if (_license != null)
        await _uploadSingleDocument(_license!, userId, 'upload-license');

      final statusResponse = await http.put(
        Uri.parse('$baseUrl/api/users/submit-docs/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (statusResponse.statusCode == 200) {
        _showMessage('Documents Uploaded Successfully!', Colors.green);
        await prefs.setBool('has_submitted_docs', true);
        setState(() {
          _hasSubmittedDocs = true;
          _userStatus = 'PENDING';
        });
      }
    } catch (e) {
      _showMessage('Upload Failed!', Colors.red);
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

  Widget _buildDocUploadCard(
    String title,
    String docType,
    File? file,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(
          file == null ? icon : Icons.check_circle,
          color: file == null ? Colors.blue : Colors.green,
          size: 40,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: ElevatedButton(
          onPressed: () => _pickImage(docType),
          child: Text(file == null ? 'Upload' : 'Change'),
        ),
      ),
    );
  }

  Widget _buildUploadForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDocUploadCard(
          'Profile Photo',
          'profile',
          _profilePhoto,
          Icons.person,
        ),
        _buildDocUploadCard('NIC (Front)', 'nic_front', _nicFront, Icons.badge),
        _buildDocUploadCard(
          'NIC (Back)',
          'nic_back',
          _nicBack,
          Icons.picture_in_picture,
        ),
        if (_userRole == 'DRIVER')
          _buildDocUploadCard(
            'Driving License',
            'license',
            _license,
            Icons.drive_eta,
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitAllDocuments,
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Submit Documents'),
        ),
      ],
    );
  }

  Widget _buildApprovedDashboard() {
    if (_isLoadingData) return const Center(child: CircularProgressIndicator());

    if (_assignedBus == null) {
      return const Center(
        child: Text("No Bus Assigned. Please contact owner."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Icon(
                  Icons.directions_bus,
                  size: 50,
                  color: Colors.blueAccent,
                ),
                Text(
                  'Bus: ${_assignedBus!['busNumber']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _assignedRoute != null
                      ? 'Route: ${_assignedRoute!['routeNumber']}'
                      : 'Route Unavailable',
                ),
                const Divider(),
                Text(
                  _userRole == 'DRIVER'
                      ? 'Conductor: ${_partnerInfo?['name'] ?? 'N/A'}'
                      : 'Driver: ${_partnerInfo?['name'] ?? 'N/A'}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        if (_userRole == 'DRIVER') ...[
          if (_activeTrip == null)
            ElevatedButton(
              onPressed: _startTrip,
              child: const Text('START TRIP'),
            )
          else
            ElevatedButton(
              onPressed: _endTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('END TRIP'),
            ),
        ] else ...[
          // CONDUCUTOR SCANNER BUTTON
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TicketScannerScreen(),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner, size: 60, color: Colors.green),
                    SizedBox(height: 15),
                    Text(
                      'Scan Tickets',
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_userRole Dashboard'),
        backgroundColor: Colors.blueAccent,
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Welcome, $_userName!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_userStatus == 'APPROVED')
              _buildApprovedDashboard()
            else if (_hasSubmittedDocs)
              const Text("Waiting for Approval...")
            else
              _buildUploadForm(),
          ],
        ),
      ),
    );
  }
}
