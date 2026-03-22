import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TicketScannerScreen extends StatefulWidget {
  final int busId;
  const TicketScannerScreen({super.key, required this.busId});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  Future<void> _validateTicket(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      Map<String, dynamic> ticketData = jsonDecode(qrData);
      int? ticketId = ticketData['ticketId'];

      if (ticketId == null || ticketId == 0) {
        _showResultDialog(
          'Invalid Ticket!',
          'Fake or corrupted QR code.',
          Colors.red,
          Icons.error,
        );
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/routes/bookings/$ticketId/use'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showResultDialog(
          'Valid Ticket ✅',
          'Ticket scanned successfully.',
          Colors.green,
          Icons.check_circle,
        );
      } else if (response.statusCode == 400 ||
          response.body.contains("already used")) {
        _showResultDialog(
          'Already Used ❌',
          'This ticket has already been used!',
          Colors.orange,
          Icons.warning,
        );
      } else {
        _showResultDialog(
          'Invalid Ticket ❌',
          'This ticket is not valid.',
          Colors.red,
          Icons.cancel,
        );
      }
    } catch (e) {
      _showResultDialog(
        'Fake QR!',
        'Not a valid Lankatransit Ticket.',
        Colors.red,
        Icons.error,
      );
    }
  }

  void _showResultDialog(
    String title,
    String message,
    Color color,
    IconData icon,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Column(
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _isProcessing = false);
                });
              },
              child: const Text('Scan Next Ticket'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Ticket'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !_isProcessing) {
                  _validateTicket(barcode.rawValue!);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Align QR code inside the frame',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
