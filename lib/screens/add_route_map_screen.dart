import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
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
  bool _isSearching = false;

  final TextEditingController _routeNoCtrl = TextEditingController();
  final TextEditingController _fareCtrl = TextEditingController();

  final TextEditingController _startSearchCtrl = TextEditingController();
  final TextEditingController _endSearchCtrl = TextEditingController();

  List<dynamic> _startSuggestions = [];
  List<dynamic> _endSuggestions = [];

  List<Map<String, dynamic>> _newHalts = [];

  final Map<String, String> _apiHeaders = {
    "User-Agent": "LankaTransitApp_Admin/1.0",
  };

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _onMapLongPress(LatLng tappedPoint) async {
    if (_startLocation == null) {
      _showMessage("Mulinma Start Location eka select karanna!", Colors.orange);
      return;
    }

    double distance = _calculateDistance(_startLocation!, tappedPoint);

    String haltName = "New Halt";
    setState(() => _isSearching = true);
    try {
      var res = await http.get(
          Uri.parse(
              "https://photon.komoot.io/reverse?lon=${tappedPoint.longitude}&lat=${tappedPoint.latitude}"),
          headers: _apiHeaders);
      if (res.statusCode == 200) {
        var data = jsonDecode(res.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          var props = data['features'][0]['properties'];
          haltName = props['name'] ??
              props['street'] ??
              props['city'] ??
              "Unknown Halt";
        }
      }
    } catch (e) {
      print("Reverse geocode error: $e");
    } finally {
      setState(() => _isSearching = false);
    }

    TextEditingController haltNameCtrl = TextEditingController(text: haltName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bus Halt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Distance from Start: ${distance.toStringAsFixed(2)} km",
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: haltNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Halt Name', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _newHalts.add({
                  'name': haltNameCtrl.text,
                  'distance': double.parse(distance.toStringAsFixed(2)),
                  'latLng': tappedPoint
                });
                _markers.add(Marker(
                    markerId: MarkerId('halt_${_newHalts.length}'),
                    position: tappedPoint,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueCyan),
                    infoWindow: InfoWindow(
                        title: haltNameCtrl.text,
                        snippet: '${distance.toStringAsFixed(2)} km')));
              });
              Navigator.pop(ctx);
              _showMessage("Halt Added!", Colors.green);
            },
            child: const Text('Add Halt'),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double R = 6371;
    double dLat = _deg2rad(end.latitude - start.latitude);
    double dLon = _deg2rad(end.longitude - start.longitude);
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(start.latitude)) *
            math.cos(_deg2rad(end.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) {
    return deg * (math.pi / 180);
  }

  Future<void> _searchPlaces(String input, bool isStart) async {
    if (input.trim().isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      if (isStart)
        _startSuggestions = [];
      else
        _endSuggestions = [];
    });

    String encodedInput = Uri.encodeComponent(input);
    String url =
        "https://nominatim.openstreetmap.org/search?q=$encodedInput&format=json&countrycodes=lk&limit=8";

    try {
      var response = await http
          .get(Uri.parse(url), headers: _apiHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        List features = jsonDecode(response.body);
        if (features.isEmpty) {
          _showMessage("'$input' kiyala thanak hambune naha.", Colors.orange);
        }
        setState(() {
          if (isStart)
            _startSuggestions = features;
          else
            _endSuggestions = features;
        });
      } else {
        _showMessage("API Error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showMessage("Internet awulak: $e", Colors.red);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPlace(dynamic feature, bool isStart) async {
    String description = feature['display_name'] ?? "Selected Location";
    double lat = double.parse(feature['lat'].toString());
    double lng = double.parse(feature['lon'].toString());
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
      _fetchRouteFromOSRM();
    }
  }

  Future<void> _fetchRouteFromOSRM() async {
    if (_startLocation == null || _endLocation == null) return;
    setState(() => _isLoadingRoute = true);

    String url = "https://router.project-osrm.org/route/v1/driving/"
        "${_startLocation!.longitude},${_startLocation!.latitude};"
        "${_endLocation!.longitude},${_endLocation!.latitude}?overview=full&geometries=geojson";

    try {
      var response = await http.get(Uri.parse(url), headers: _apiHeaders);
      var data = jsonDecode(response.body);

      if (data['code'] == 'Ok') {
        var route = data['routes'][0];
        double distValue = route['distance'] / 1000.0;
        String distanceStr = "${distValue.toStringAsFixed(2)} km";

        var coordinates = route['geometry']['coordinates'];
        List<LatLng> decodedPoints = [];
        for (var coord in coordinates) {
          decodedPoints.add(LatLng(coord[1], coord[0]));
        }

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
        _showMessage("Failed to get route from Server.", Colors.red);
      }
    } catch (e) {
      _showMessage("Error drawing route on map.", Colors.red);
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _saveRouteToBackend() async {
    if (_routeNoCtrl.text.isEmpty ||
        _fareCtrl.text.isEmpty ||
        _startSearchCtrl.text.isEmpty ||
        _endSearchCtrl.text.isEmpty) {
      _showMessage("Please fill all details", Colors.red);
      return;
    }

    setState(() => _isLoadingRoute = true);

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
          'startLatitude': _startLocation!.latitude,
          'startLongitude': _startLocation!.longitude,
          'endLatitude': _endLocation!.latitude,
          'endLongitude': _endLocation!.longitude,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var savedRoute = jsonDecode(response.body);
        int routeId = savedRoute['id'];
        _newHalts.sort((a, b) =>
            (a['distance'] as double).compareTo(b['distance'] as double));

        for (int i = 0; i < _newHalts.length; i++) {
          LatLng point = _newHalts[i]['latLng'];
          await http.post(
            Uri.parse('$baseUrl/api/routes/$routeId/halts'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'haltName': _newHalts[i]['name'],
              'distanceFromStart': _newHalts[i]['distance'],
              'sequenceOrder': i + 1,
              'latitude': point.latitude,
              'longitude': point.longitude
            }),
          );
        }

        _showMessage('Route and ${_newHalts.length} Halts Saved Successfully!',
            Colors.green);
        Navigator.pop(context, true);
      } else {
        _showMessage('Failed to save route.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error saving route.', Colors.red);
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  void _showSaveRouteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Route & Halts'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Distance: $_distanceText',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
              Text('Halts Detected: ${_newHalts.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
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
      resizeToAvoidBottomInset: false,
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
            onLongPress: _onMapLongPress,
          ),
          if (_isLoadingRoute || _isSearching)
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
                          decoration: InputDecoration(
                            hintText: 'Type Start Location...',
                            prefixIcon: const Icon(Icons.location_on,
                                color: Colors.green),
                            suffixIcon: IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.blue),
                              onPressed: () =>
                                  _searchPlaces(_startSearchCtrl.text, true),
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) => _searchPlaces(val, true),
                        ),
                        if (_startSuggestions.isNotEmpty)
                          Container(
                            height: 150,
                            color: Colors.white,
                            child: ListView.builder(
                              itemCount: _startSuggestions.length,
                              itemBuilder: (context, index) {
                                var place = _startSuggestions[index];
                                String dispName =
                                    place['display_name'] ?? 'Unknown';
                                return ListTile(
                                  leading: const Icon(Icons.place,
                                      color: Colors.grey),
                                  title: Text(dispName.split(',')[0]),
                                  onTap: () => _selectPlace(place, true),
                                );
                              },
                            ),
                          ),
                        const Divider(),
                        TextField(
                          controller: _endSearchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Type End Location...',
                            prefixIcon: const Icon(Icons.location_on,
                                color: Colors.red),
                            suffixIcon: IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.blue),
                              onPressed: () =>
                                  _searchPlaces(_endSearchCtrl.text, false),
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) => _searchPlaces(val, false),
                        ),
                        if (_endSuggestions.isNotEmpty)
                          Container(
                            height: 150,
                            color: Colors.white,
                            child: ListView.builder(
                              itemCount: _endSuggestions.length,
                              itemBuilder: (context, index) {
                                var place = _endSuggestions[index];
                                String dispName =
                                    place['display_name'] ?? 'Unknown';
                                return ListTile(
                                  leading: const Icon(Icons.place,
                                      color: Colors.grey),
                                  title: Text(dispName.split(',')[0]),
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
          if (_newHalts.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 20,
              child: Chip(
                backgroundColor: Colors.cyan,
                label: Text('${_newHalts.length} Halts Added',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _distanceText.isNotEmpty
            ? _showSaveRouteDialog
            : () {
                _showMessage(
                    "Mulinma Search karala paara hadaganna.", Colors.orange);
              },
        icon: const Icon(Icons.save),
        label: Text(_distanceText.isNotEmpty
            ? 'Save Route & Halts'
            : 'Calculate Route First'),
        backgroundColor: _distanceText.isNotEmpty ? Colors.green : Colors.grey,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
