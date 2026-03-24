import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddRouteMapScreen extends StatefulWidget {
  const AddRouteMapScreen({super.key});

  @override
  State<AddRouteMapScreen> createState() => _AddRouteMapScreenState();
}

class _AddRouteMapScreenState extends State<AddRouteMapScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

  final String googleApiKey = "AIzaSyCpLBpnNYInfufg7GC_dFxqLHjKYxzKX_s";

  late GoogleMapController mapController;

  LatLng? _startLocation;
  LatLng? _endLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  String _distanceText = "";
  double _distanceInKm = 0.0;
  bool _isLoadingRoute = false;

  final TextEditingController _routeNoCtrl = TextEditingController();
  final TextEditingController _fareCtrl = TextEditingController();

  final TextEditingController _startSearchCtrl = TextEditingController();
  final TextEditingController _endSearchCtrl = TextEditingController();

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _searchPlaces(String input, bool isStart) async {
    if (input.isEmpty) {
      setState(() {
        if (isStart)
          _startSuggestions = [];
        else
          _endSuggestions = [];
      });
      return;
    }

    String url =
        "https://nominatim.openstreetmap.org/search?q=$input&format=json&countrycodes=lk&limit=5";

    try {
      var response = await http.get(Uri.parse(url));
      var data = jsonDecode(response.body);

      setState(() {
        if (isStart)
          _startSuggestions = data;
        else
          _endSuggestions = data;
      });
    } catch (e) {
      print("Search error: $e");
    }
  }

  Future<void> _selectPlace(dynamic place, bool isStart) async {
    String description = place['display_name'];
    double lat = double.parse(place['lat'].toString());
    double lng = double.parse(place['lon'].toString());
    LatLng pos = LatLng(lat, lng);

    setState(() {
      if (isStart) {
        _startSearchCtrl.text = description.split(',')[0];
        _startSuggestions = [];
        _startLocation = pos;
        _markers.removeWhere((m) => m.markerId == const MarkerId('start'));
        _markers.add(Marker(
            markerId: const MarkerId('start'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen)));
      } else {
        _endSearchCtrl.text = description.split(',')[0];
        _endSuggestions = [];
        _endLocation = pos;
        _markers.removeWhere((m) => m.markerId == const MarkerId('end'));
        _markers.add(Marker(
            markerId: const MarkerId('end'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed)));
      }
    });

    mapController.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));

    if (_startLocation != null && _endLocation != null) {
      _fetchRouteFromGoogle();
    }
  }

  Future<void> _fetchRouteFromGoogle() async {
    if (_startLocation == null || _endLocation == null) return;
    setState(() => _isLoadingRoute = true);

    String url = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${_startLocation!.latitude},${_startLocation!.longitude}"
        "&destination=${_endLocation!.latitude},${_endLocation!.longitude}"
        "&key=$googleApiKey";

    try {
      var response = await http.get(Uri.parse(url));
      var data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        String polylineEncoded =
            data['routes'][0]['overview_polyline']['points'];
        String distanceStr = data['routes'][0]['legs'][0]['distance']['text'];
        double distValue =
            data['routes'][0]['legs'][0]['distance']['value'] / 1000.0;

        List<LatLng> decodedPoints = _decodePolyline(polylineEncoded);

        setState(() {
          _distanceText = distanceStr;
          _distanceInKm = distValue;
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blueAccent,
              width: 5,
              points: decodedPoints,
            ),
          );
        });

        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(
            _startLocation!.latitude < _endLocation!.latitude
                ? _startLocation!.latitude
                : _endLocation!.latitude,
            _startLocation!.longitude < _endLocation!.longitude
                ? _startLocation!.longitude
                : _endLocation!.longitude,
          ),
          northeast: LatLng(
            _startLocation!.latitude > _endLocation!.latitude
                ? _startLocation!.latitude
                : _endLocation!.latitude,
            _startLocation!.longitude > _endLocation!.longitude
                ? _startLocation!.longitude
                : _endLocation!.longitude,
          ),
        );
        mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      } else {
        _showMessage(
            "Error from Google Maps: ${data['status']} - Verify Directions API",
            Colors.red);
      }
    } catch (e) {
      _showMessage("Failed to get route from Google Maps", Colors.red);
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  Future<void> _saveRouteToBackend() async {
    if (_routeNoCtrl.text.isEmpty ||
        _fareCtrl.text.isEmpty ||
        _startSearchCtrl.text.isEmpty ||
        _endSearchCtrl.text.isEmpty) {
      _showMessage("Please fill all details", Colors.red);
      return;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      String sLoc = _startSearchCtrl.text.split(',')[0];
      String eLoc = _endSearchCtrl.text.split(',')[0];

      final response = await http.post(
        Uri.parse('$baseUrl/api/routes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'routeNumber': _routeNoCtrl.text,
          'startLocation': sLoc,
          'endLocation': eLoc,
          'baseFarePerKm': double.parse(_fareCtrl.text),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Route Saved Successfully!', Colors.green);
        Navigator.pop(context, true);
      } else {
        _showMessage('Failed to save route.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error saving route.', Colors.red);
    }
  }

  void _showSaveRouteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save New Route'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Distance: $_distanceText',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              TextField(
                controller: _routeNoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Route Number (e.g. 400)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fareCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Base Fare per KM (Rs.)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _saveRouteToBackend();
            },
            child: const Text('Save Route'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Create Route'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.9271, 79.8612),
              zoom: 10,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
          ),
          if (_isLoadingRoute)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _startSearchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search Start Location (e.g. Panadura)',
                            prefixIcon: Icon(Icons.search, color: Colors.green),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) => _searchPlaces(val, true),
                        ),
                        if (_startSuggestions.isNotEmpty)
                          Container(
                            height: 150,
                            color: Colors.white,
                            child: ListView.builder(
                              itemCount: _startSuggestions.length,
                              itemBuilder: (context, index) {
                                var place = _startSuggestions[index];
                                return ListTile(
                                  title: Text(place['display_name']),
                                  onTap: () => _selectPlace(place, true),
                                );
                              },
                            ),
                          ),
                        const Divider(),
                        TextField(
                          controller: _endSearchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Search End Location (e.g. Colombo)',
                            prefixIcon: Icon(Icons.search, color: Colors.red),
                            border: InputBorder.none,
                          ),
                          onChanged: (val) => _searchPlaces(val, false),
                        ),
                        if (_endSuggestions.isNotEmpty)
                          Container(
                            height: 150,
                            color: Colors.white,
                            child: ListView.builder(
                              itemCount: _endSuggestions.length,
                              itemBuilder: (context, index) {
                                var place = _endSuggestions[index];
                                return ListTile(
                                  title: Text(place['display_name']),
                                  onTap: () => _selectPlace(place, false),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _distanceText.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showSaveRouteDialog,
              icon: const Icon(Icons.save),
              label: Text('Save Route ($_distanceText)'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
