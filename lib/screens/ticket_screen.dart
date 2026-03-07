import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TicketScreen extends StatelessWidget {
  final dynamic routeData;
  final dynamic startHalt;
  final dynamic endHalt;
  final double ticketPrice;

  const TicketScreen({
    super.key,
    required this.routeData,
    required this.startHalt,
    required this.endHalt,
    required this.ticketPrice,
  });

  @override
  Widget build(BuildContext context) {
    String qrData = "LankaTransit | Route: ${routeData['routeNumber']} | From: ${startHalt['haltName']} | To: ${endHalt['haltName']} | Price: Rs.$ticketPrice";

    return Scaffold(
      backgroundColor: Colors.blueAccent,
      appBar: AppBar(
        title: const Text('Your Digital Ticket'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LANKA TRANSIT',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Route: ${routeData['routeNumber']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Bus: Normal', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
                const Divider(thickness: 2, height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('FROM', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(startHalt['haltName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.blueAccent),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('TO', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(endHalt['haltName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.right),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Total Fare: Rs. ${ticketPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 30),

                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 10),
                const Text('Scan this code to verify your ticket', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}