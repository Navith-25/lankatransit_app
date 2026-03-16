import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ticket_screen.dart';

class RouteDetailsScreen extends StatefulWidget {
  final dynamic routeData;

  const RouteDetailsScreen({super.key, required this.routeData});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  List<dynamic> _halts = [];
  bool _isLoading = true;
  bool _isBooking = false;

  dynamic _selectedStartHalt;
  dynamic _selectedEndHalt;
  double _ticketPrice = 0.0;

  @override
  void initState() {
    super.initState();
    fetchHalts();
  }

  Future<void> fetchHalts() async {
    final routeId = widget.routeData['id'];
    final url = Uri.parse('http://10.0.2.2:8081/api/routes/$routeId/halts');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _halts = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        showError('Failed to load halts');
      }
    } catch (e) {
      showError('Server error.');
    }
  }

  void showError(String message) {
    setState(() {
      _isLoading = false;
      _isBooking = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _calculateFare() {
    if (_selectedStartHalt != null && _selectedEndHalt != null) {
      double startDist = (_selectedStartHalt['distanceFromStart'] as num).toDouble();
      double endDist = (_selectedEndHalt['distanceFromStart'] as num).toDouble();
      double baseFare = (widget.routeData['baseFarePerKm'] as num).toDouble();

      double distance = (endDist - startDist).abs();

      setState(() {
        _ticketPrice = distance * baseFare;
      });
    }
  }

  Future<void> _bookTicket() async {
    setState(() {
      _isBooking = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String realEmail = prefs.getString('userEmail') ?? 'guest@lankatransit.com';

    final url = Uri.parse('http://10.0.2.2:8081/api/routes/book');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'routeId': widget.routeData['id'],
          'startHalt': _selectedStartHalt['haltName'],
          'endHalt': _selectedEndHalt['haltName'],
          'fare': _ticketPrice,
          'userEmail': realEmail
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketScreen(
              routeData: widget.routeData,
              startHalt: _selectedStartHalt,
              endHalt: _selectedEndHalt,
              ticketPrice: _ticketPrice,
            ),
          ),
        );
      } else {
        showError('Failed to save booking. Please try again!');
      }
    } catch (e) {
      showError('Server error while booking!');
    } finally {
      setState(() {
        _isBooking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Route ${widget.routeData['routeNumber']} Details'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: _halts.isEmpty
                ? const Center(child: Text('Me parata thama halts add karala naha. 🚏'))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _halts.length,
              itemBuilder: (context, index) {
                final halt = _halts[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        halt['sequenceOrder'].toString(),
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(halt['haltName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Distance: ${halt['distanceFromStart']} km'),
                  ),
                );
              },
            ),
          ),

          if (_halts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -5)),
                ],
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Book Your Ticket', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<dynamic>(
                    decoration: InputDecoration(
                      labelText: 'From (Start Halt)',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    value: _selectedStartHalt,
                    items: _halts.map((halt) {
                      return DropdownMenuItem<dynamic>(
                        value: halt,
                        child: Text(halt['haltName']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStartHalt = value;
                        _calculateFare();
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<dynamic>(
                    decoration: InputDecoration(
                      labelText: 'To (End Halt)',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    value: _selectedEndHalt,
                    items: _halts.map((halt) {
                      return DropdownMenuItem<dynamic>(
                        value: halt,
                        child: Text(halt['haltName']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEndHalt = value;
                        _calculateFare();
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Fare', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          Text(
                            'Rs. ${_ticketPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ],
                      ),

                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_ticketPrice > 0 && !_isBooking) ? _bookTicket : null,
                        child: _isBooking
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Buy Ticket', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}