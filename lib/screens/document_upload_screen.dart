import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'login_screen.dart';

class DocumentUploadScreen extends StatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  File? _profilePhoto;
  File? _nicFront;
  File? _nicBack;
  File? _licensePhoto;
  bool _isLoading = false;

  String _userRole = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? '';
    });
  }

  Future<void> _pickImage(String docType) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (docType == 'profile') _profilePhoto = File(image.path);
        if (docType == 'nic_front') _nicFront = File(image.path);
        if (docType == 'nic_back') _nicBack = File(image.path);
        if (docType == 'license') _licensePhoto = File(image.path);
      });
    }
  }

  Future<void> _uploadSingleFile(File file, String endpoint) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    int? userId = prefs.getInt('user_id');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.0.2.2:8081/api/users/$userId/$endpoint'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload $endpoint');
    }
  }

  Future<void> _submitDocuments() async {
    if (_profilePhoto == null || _nicFront == null || _nicBack == null) {
      _showMessage('Profile Photo and NIC (Front & Back) are compulsory!', Colors.red);
      return;
    }

    if (_userRole == 'DRIVER' && _licensePhoto == null) {
      _showMessage('Driving License is COMPULSORY for Drivers!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _uploadSingleFile(_profilePhoto!, 'upload-profile-photo');
      await _uploadSingleFile(_nicFront!, 'upload-nic-front');
      await _uploadSingleFile(_nicBack!, 'upload-nic-back');

      if (_licensePhoto != null) {
        await _uploadSingleFile(_licensePhoto!, 'upload-license');
      }

      _showMessage('Documents Uploaded Successfully! Wait for Admin Approval.', Colors.green);

      if (!mounted) return;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));

    } catch (e) {
      _showMessage('Upload Failed. Please try again.', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Widget _buildUploadButton(String title, String docType, File? file) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(file == null ? Icons.upload_file : Icons.check_circle,
            color: file == null ? Colors.blue : Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(file == null ? 'Not selected' : 'Image ready to upload'),
        trailing: ElevatedButton(
          onPressed: () => _pickImage(docType),
          child: const Text('Pick Image'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Documents'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your account role is $_userRole. Please upload the required documents.',
              style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                children: [
                  _buildUploadButton('Profile Photo', 'profile', _profilePhoto),
                  _buildUploadButton('NIC Front', 'nic_front', _nicFront),
                  _buildUploadButton('NIC Back', 'nic_back', _nicBack),

                  if (_userRole == 'DRIVER')
                    _buildUploadButton('Driving License (Compulsory)', 'license', _licensePhoto),
                ],
              ),
            ),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _submitDocuments,
              child: const Text('Submit All Documents', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}