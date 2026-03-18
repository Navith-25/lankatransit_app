import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final String baseUrl = "http://10.0.2.2:8081";
  bool isScanning = true;

  Future<void> _verifyTicket(String qrHash) async {
    setState(() => isScanning = false);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/tickets/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'qrCodeHash': qrHash}),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        _showResultDialog(
          "Success!",
          result['message'],
          Colors.green,
          Icons.check_circle,
        );
      } else {
        _showResultDialog(
          "Failed!",
          result['message'] ?? "Invalid Ticket",
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      _showResultDialog(
        "Error",
        "Could not connect to server",
        Colors.orange,
        Icons.warning,
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
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: color)),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => isScanning = true);
            },
            child: const Text("Scan Next"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Passenger Ticket"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (isScanning) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _verifyTicket(barcode.rawValue!);
                    break;
                  }
                }
              }
            },
          ),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
