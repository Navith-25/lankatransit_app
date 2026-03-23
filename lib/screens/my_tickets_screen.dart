import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ticket_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<dynamic> _validTickets = [];
  List<dynamic> _usedTickets = [];
  bool _isLoading = true;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _fetchMyTickets();
  }

  Future<void> _fetchMyTickets() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('userEmail') ?? '';

    setState(() {
      _userEmail = email;
    });

    if (email.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final url = Uri.parse(
      'https://navith-25-lankatransit-backend.hf.space/api/routes/bookings/$email',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> allTickets = jsonDecode(response.body);

        setState(() {
          _validTickets = allTickets
              .where((t) => t['status'] == 'VALID' || t['status'] == null)
              .toList();
          _usedTickets = allTickets
              .where((t) => t['status'] == 'USED')
              .toList();
          _isLoading = false;
        });
      } else {
        _showError('Failed to load tickets');
      }
    } catch (e) {
      _showError('Server error.');
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDate(String dateTimeStr) {
    try {
      final parts = dateTimeStr.split('T');
      final date = parts[0];
      final time = parts[1].substring(0, 5);
      return '$date at $time';
    } catch (e) {
      return dateTimeStr;
    }
  }

  int _getTicketId(dynamic ticket) {
    var id = ticket['id'] ?? ticket['bookingId'] ?? ticket['ticketId'];
    if (id == null) return 0;
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  Widget _buildTicketList(List<dynamic> tickets, bool isUsed) {
    if (tickets.isEmpty) {
      return Center(
        child: Text(
          isUsed
              ? 'No used tickets found. 🎟️'
              : 'You have no valid tickets. 🎟️',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        final ticketId = _getTicketId(ticket);

        return Card(
          elevation: isUsed ? 1 : 3,
          color: isUsed ? Colors.grey[200] : Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: isUsed
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TicketScreen(
                          ticketId: ticketId,
                          routeData: {
                            'routeNumber': ticket['routeId'].toString(),
                          },
                          startHalt: {'haltName': ticket['startHalt']},
                          endHalt: {'haltName': ticket['endHalt']},
                          ticketPrice: double.parse(ticket['fare'].toString()),
                        ),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isUsed
                              ? Colors.grey[400]
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'TICKET ID: ${ticketId != 0 ? ticketId : 'NULL'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isUsed ? Colors.white : Colors.blueAccent,
                          ),
                        ),
                      ),
                      Text(
                        'Rs. ${ticket['fare']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isUsed ? Colors.grey : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 25, thickness: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'From',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            ticket['startHalt'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isUsed ? Colors.grey : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: isUsed ? Colors.grey : Colors.blueAccent,
                        size: 20,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'To',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            ticket['endHalt'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isUsed ? Colors.grey : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatDate(ticket['bookingTime']),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (isUsed)
                        const Text(
                          'ALREADY USED',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      else
                        const Text(
                          'Tap to view QR ➔',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('My Tickets'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Valid Tickets ✅'),
              Tab(text: 'Used Tickets ❌'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _userEmail.isEmpty
            ? const Center(child: Text('User email not found. Please relogin.'))
            : TabBarView(
                children: [
                  _buildTicketList(_validTickets, false),
                  _buildTicketList(_usedTickets, true),
                ],
              ),
      ),
    );
  }
}
