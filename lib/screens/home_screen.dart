import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import 'login_screen.dart';
import 'my_tickets_screen.dart';
import 'profile_screen.dart';
import 'live_map_screen.dart';
import 'ticket_screen.dart';

enum SearchState { selectingStart, selectingEnd, loading, results }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";
  late GoogleMapController mapController;

  SearchState _currentState = SearchState.selectingStart;

  LatLng _currentMapCenter = const LatLng(6.9271, 79.8612);

  LatLng? _startLocation;
  LatLng? _endLocation;

  Map<String, dynamic>? _searchResult;

  Set<Marker> _userMarkers = {};
  Set<Marker> _haltMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadAllHalts();
  }

  Future<void> _loadAllHalts() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final routeRes = await http.get(Uri.parse('$baseUrl/api/routes'),
          headers: {'Authorization': 'Bearer $token'});

      if (routeRes.statusCode == 200) {
        List<dynamic> routes = jsonDecode(routeRes.body);
        Set<Marker> tempMarkers = {};

        for (var route in routes) {
          final haltRes = await http.get(
              Uri.parse('$baseUrl/api/routes/${route['id']}/halts'),
              headers: {'Authorization': 'Bearer $token'});

          if (haltRes.statusCode == 200) {
            List<dynamic> halts = jsonDecode(haltRes.body);
            for (var halt in halts) {
              if (halt['latitude'] != null && halt['longitude'] != null) {
                double lat = (halt['latitude'] as num).toDouble();
                double lng = (halt['longitude'] as num).toDouble();

                tempMarkers.add(Marker(
                  markerId: MarkerId('halt_${halt['id']}'),
                  position: LatLng(lat, lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                  infoWindow: InfoWindow(
                      title: halt['haltName'],
                      snippet: 'Route ${route['routeNumber']}'),
                ));
              }
            }
          }
        }

        setState(() {
          _haltMarkers = tempMarkers;
        });
      }
    } catch (e) {
      print("Error loading halts: $e");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _confirmStartLocation() {
    setState(() {
      _startLocation = _currentMapCenter;
      _userMarkers.add(Marker(
        markerId: const MarkerId('start_pin'),
        position: _startLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
      _currentState = SearchState.selectingEnd;
    });
  }

  void _confirmEndLocation() {
    setState(() {
      _endLocation = _currentMapCenter;
      _userMarkers.add(Marker(
        markerId: const MarkerId('end_pin'),
        position: _endLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
      _currentState = SearchState.loading;
    });

    _fitMapToPins();
    _searchSmartRoutes();
  }

  Future<void> _searchSmartRoutes() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final url = Uri.parse('$baseUrl/api/routes/smart-search?'
          'startLat=${_startLocation!.latitude}&startLng=${_startLocation!.longitude}&'
          'endLat=${_endLocation!.latitude}&endLng=${_endLocation!.longitude}');

      final response =
          await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        setState(() {
          _searchResult = jsonDecode(response.body);
          _currentState = SearchState.results;
        });
      } else {
        _showError('No buses found for this route!');
        _resetSearch();
      }
    } catch (e) {
      _showError('Server error. Please try again.');
      _resetSearch();
    }
  }

  Future<void> _bookTicket(dynamic routeInfo) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      String? email = prefs.getString('email') ?? "user@example.com";

      final response = await http.post(
        Uri.parse('$baseUrl/api/routes/book'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'userEmail': email,
          'routeId': routeInfo['routeId'],
          'startLocation': _searchResult!['startHaltName'],
          'endLocation': _searchResult!['endHaltName'],
          'fare': routeInfo['calculatedFare'],
          'status': 'ACTIVE'
        }),
      );

      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        var bookingData = jsonDecode(response.body);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketScreen(
              ticketId: bookingData['id'] ?? 1001,
              routeData: {'routeNumber': routeInfo['routeNumber']},
              startHalt: {'haltName': _searchResult!['startHaltName']},
              endHalt: {'haltName': _searchResult!['endHaltName']},
              ticketPrice: routeInfo['calculatedFare'],
            ),
          ),
        );
      } else {
        _showError('Booking failed!');
      }
    } catch (e) {
      Navigator.pop(context);
      _showError('Error booking ticket.');
    }
  }

  void _resetSearch() {
    setState(() {
      _startLocation = null;
      _endLocation = null;
      _searchResult = null;
      _userMarkers.clear();
      _currentState = SearchState.selectingStart;
    });
  }

  void _fitMapToPins() {
    if (_startLocation != null && _endLocation != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          math.min(_startLocation!.latitude, _endLocation!.latitude),
          math.min(_startLocation!.longitude, _endLocation!.longitude),
        ),
        northeast: LatLng(
          math.max(_startLocation!.latitude, _endLocation!.latitude),
          math.max(_startLocation!.longitude, _endLocation!.longitude),
        ),
      );
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Lanka Transit',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: IconButton(
              icon:
                  const Icon(Icons.confirmation_num, color: Colors.blueAccent),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyTicketsScreen())),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.person, color: Colors.blueAccent),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen())),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        // Left menu eka
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
              child: Text('Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!mounted) return;
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()));
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
                CameraPosition(target: _currentMapCenter, zoom: 14),
            myLocationEnabled: true,
            markers: _userMarkers.union(_haltMarkers),
            onCameraMove: (position) {
              if (_currentState == SearchState.selectingStart ||
                  _currentState == SearchState.selectingEnd) {
                _currentMapCenter = position.target;
              }
            },
          ),
          if (_currentState == SearchState.selectingStart ||
              _currentState == SearchState.selectingEnd)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Icon(
                  Icons.location_on,
                  size: 50,
                  color: _currentState == SearchState.selectingStart
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          Positioned(
            top: 100,
            left: 15,
            child: FloatingActionButton.extended(
              heroTag: 'radar',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LiveMapScreen())),
              icon: const Icon(Icons.radar),
              label: const Text('Live Radar'),
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_currentState == SearchState.selectingStart) ...[
            const Text("Where are you?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("Drag the map to set your Pick-up location",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: _confirmStartLocation,
              child: const Text("Confirm Pick-Up",
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ] else if (_currentState == SearchState.selectingEnd) ...[
            const Text("Where to?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("Drag the map to set your Drop-off location",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _resetSearch,
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: _confirmEndLocation,
                    child: const Text("Confirm Drop-Off",
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ] else if (_currentState == SearchState.loading) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text("Searching nearest bus halts...",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ] else if (_currentState == SearchState.results &&
              _searchResult != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Available Buses",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _resetSearch,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Change"),
                )
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Colors.grey, size: 16),
                const SizedBox(width: 5),
                Expanded(
                    child: Text("Walk to: ${_searchResult!['startHaltName']}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, color: Colors.green))),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                const SizedBox(width: 5),
                Expanded(
                    child: Text("Get off at: ${_searchResult!['endHaltName']}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, color: Colors.red))),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 180,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: (_searchResult!['availableRoutes'] as List).length,
                itemBuilder: (context, index) {
                  var route = _searchResult!['availableRoutes'][index];
                  return Card(
                    color: Colors.blue.shade50,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child:
                              Icon(Icons.directions_bus, color: Colors.white)),
                      title: Text(
                          'Route ${route['routeNumber']} - Rs.${route['calculatedFare']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(route['fullRouteName']),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white),
                        onPressed: () => _bookTicket(route),
                        child: const Text("Book"),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]
        ],
      ),
    );
  }
}
