import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

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

  bool _hasSubmittedDocs = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "User";
      _userRole = prefs.getString('user_role') ?? "DRIVER";
      _userStatus = prefs.getString('user_status') ?? "CREATED";
      _hasSubmittedDocs = prefs.getBool('has_submitted_docs') ?? false;

      if (_userStatus == 'REJECTED' || _userStatus == 'RESUBMIT') {
        _hasSubmittedDocs = false;
      }
    });
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
    if (response.statusCode != 200) {
      throw Exception('Failed to upload $endpoint');
    }
  }

  Future<void> _submitAllDocuments() async {
    if (_profilePhoto == null || _nicFront == null || _nicBack == null) {
      _showMessage(
        'Please select at least Profile Photo and NIC (Front & Back)!',
        Colors.red,
      );
      return;
    }

    if (_userRole == 'DRIVER' && _license == null) {
      _showMessage('Drivers must upload their Driving License!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      String? token = prefs.getString('jwt_token');

      if (userId == null) throw Exception("User ID not found!");

      await _uploadSingleDocument(
        _profilePhoto!,
        userId,
        'upload-profile-photo',
      );
      await _uploadSingleDocument(_nicFront!, userId, 'upload-nic-front');
      await _uploadSingleDocument(_nicBack!, userId, 'upload-nic-back');

      if (_license != null) {
        await _uploadSingleDocument(_license!, userId, 'upload-license');
      }

      final statusResponse = await http.put(
        Uri.parse('$baseUrl/api/users/submit-docs/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (statusResponse.statusCode == 200) {
        _showMessage('Documents Uploaded Successfully!', Colors.green);

        await prefs.setBool('has_submitted_docs', true);
        await prefs.setString('user_status', 'PENDING');

        setState(() {
          _hasSubmittedDocs = true;
          _userStatus = 'PENDING';
          _profilePhoto = null;
          _nicFront = null;
          _nicBack = null;
          _license = null;
        });
      } else {
        _showMessage('Failed to notify admin! Please try again.', Colors.red);
      }
    } catch (e) {
      _showMessage('Upload Failed! Please try again.', Colors.red);
    } finally {
      setState(() => _isLoading = false);
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

  Widget _buildUploadForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _userStatus == 'RESUBMIT' || _userStatus == 'REJECTED'
                ? 'Your documents were $_userStatus.\nPlease upload clear documents again.'
                : 'Account Status: $_userStatus\nPlease upload your documents below for Admin approval.',
            style: TextStyle(
              color: Colors.orange[800],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'Upload Documents',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),

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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onPressed: _isLoading ? null : _submitAllDocuments,
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'Submit Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildWaitingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 50),
        const Icon(Icons.hourglass_top, size: 80, color: Colors.orange),
        const SizedBox(height: 20),
        const Text(
          'Documents Submitted!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your documents have been sent to the Admin.\nPlease wait until your account is approved.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Check Status (Re-Login)'),
        ),
      ],
    );
  }

  Widget _buildApprovedDashboard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.check_circle, size: 80, color: Colors.green),
        const SizedBox(height: 20),
        Text(
          'Account Approved!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        if (_userRole == 'DRIVER') ...[
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              onTap: () {
                _showMessage('GPS Live Tracking coming next!', Colors.blue);
              },
              borderRadius: BorderRadius.circular(15),
              child: const Padding(
                padding: EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    Icon(Icons.location_on, size: 60, color: Colors.redAccent),
                    SizedBox(height: 15),
                    Text(
                      'Start Trip (Live Location)',
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
        ] else if (_userRole == 'CONDUCTOR') ...[
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              onTap: () {
                _showMessage('Ticket Scanner coming next!', Colors.blue);
              },
              borderRadius: BorderRadius.circular(15),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Icon(
          file == null ? icon : Icons.check_circle,
          color: file == null ? Colors.blue : Colors.green,
          size: 40,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          file == null ? 'Tap to select image' : 'Image Selected',
          style: TextStyle(color: file == null ? Colors.grey : Colors.green),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: file == null ? Colors.blueAccent : Colors.green,
          ),
          onPressed: () => _pickImage(docType),
          child: Text(
            file == null ? 'Upload' : 'Change',
            style: const TextStyle(color: Colors.white),
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
        title: Text(
          '$_userRole Dashboard',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome, $_userName!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (_userStatus == 'APPROVED')
              _buildApprovedDashboard()
            else if (_hasSubmittedDocs || _userStatus == 'PENDING')
              _buildWaitingScreen()
            else
              _buildUploadForm(),
          ],
        ),
      ),
    );
  }
}
