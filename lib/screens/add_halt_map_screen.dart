import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class AddHaltMapScreen extends StatefulWidget {
  final dynamic routeData;
  const AddHaltMapScreen({super.key, required this.routeData});

  @override
  State<AddHaltMapScreen> createState() => _AddHaltMapScreenState();
}

class _AddHaltMapScreenState extends State<AddHaltMapScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";
  late GoogleMapController mapController;

  LatLng? _startLocation;
  LatLng? _endLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, String> _apiHeaders = {
    "User-Agent": "LankaTransitApp_Admin/1.0",
  };

  @override
  void initState() {
    super.initState();
    _loadExistingRoute();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _loadExistingRoute() async {
    String startName = widget.routeData['startLocation'];
    String endName = widget.routeData['endLocation'];

    if (widget.routeData['startLatitude'] != null &&
        widget.routeData['startLongitude'] != null) {
      _startLocation = LatLng(widget.routeData['startLatitude'],
          widget.routeData['startLongitude']);
    }

    if (widget.routeData['endLatitude'] != null &&
        widget.routeData['endLongitude'] != null) {
      _endLocation = LatLng(
          widget.routeData['endLatitude'], widget.routeData['endLongitude']);
    }

    if (_startLocation != null) {
      _markers.add(Marker(
          markerId: const MarkerId('start'),
          position: _startLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: "Start: $startName")));
    }
    if (_endLocation != null) {
      _markers.add(Marker(
          markerId: const MarkerId('end'),
          position: _endLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: "End: $endName")));
    }

    if (_startLocation != null && _endLocation != null) {
      await _fetchRouteFromOSRM(_startLocation!, _endLocation!);
    } else {
      setState(() => _isLoading = false);
      _showMessage(
          "Start/End coordinates not found in Database. Please recreate route.",
          Colors.orange);
    }
  }

  Future<void> _fetchRouteFromOSRM(LatLng start, LatLng end) async {
    String url =
        "https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson";
    try {
      var response = await http.get(Uri.parse(url), headers: _apiHeaders);
      var data = jsonDecode(response.body);
      if (data['code'] == 'Ok') {
        var coordinates = data['routes'][0]['geometry']['coordinates'];
        List<LatLng> decodedPoints = [];
        for (var coord in coordinates) {
          decodedPoints.add(LatLng(coord[1], coord[0]));
        }

        setState(() {
          _polylines.add(Polyline(
              polylineId: const PolylineId('existing_route'),
              color: Colors.blueAccent,
              width: 5,
              points: decodedPoints));
          _isLoading = false;
        });

        await _fetchExistingHaltsAndPlot(decodedPoints);

        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(math.min(start.latitude, end.latitude),
              math.min(start.longitude, end.longitude)),
          northeast: LatLng(math.max(start.latitude, end.latitude),
              math.max(start.longitude, end.longitude)),
        );
        mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchExistingHaltsAndPlot(List<LatLng> routePoints) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/routes/${widget.routeData['id']}/halts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> halts = jsonDecode(response.body);

        setState(() {
          for (var halt in halts) {
            LatLng? haltPos;

            if (halt['latitude'] != null && halt['longitude'] != null) {
              haltPos = LatLng(halt['latitude'], halt['longitude']);
            } else {
              double targetDist = (halt['distanceFromStart'] as num).toDouble();
              double cumulativeDist = 0.0;
              if (targetDist == 0.0 && routePoints.isNotEmpty) {
                haltPos = routePoints.first;
              } else {
                for (int i = 0; i < routePoints.length - 1; i++) {
                  double segDist =
                      _calculateDistance(routePoints[i], routePoints[i + 1]);
                  if (cumulativeDist + segDist >= targetDist) {
                    double fraction = segDist == 0
                        ? 0
                        : (targetDist - cumulativeDist) / segDist;
                    double lat = routePoints[i].latitude +
                        (routePoints[i + 1].latitude -
                                routePoints[i].latitude) *
                            fraction;
                    double lng = routePoints[i].longitude +
                        (routePoints[i + 1].longitude -
                                routePoints[i].longitude) *
                            fraction;
                    haltPos = LatLng(lat, lng);
                    break;
                  }
                  cumulativeDist += segDist;
                }
              }
              haltPos ??= routePoints.last;
            }

            _markers.add(Marker(
              markerId: MarkerId('existing_halt_${halt['id']}'),
              position: haltPos,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                  title: halt['haltName'],
                  snippet: 'Existing Halt | ${halt['distanceFromStart']} km'),
            ));
          }
        });
      }
    } catch (e) {
      print("Error loading existing halts: $e");
    }
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

  Future<void> _onMapLongPress(LatLng tappedPoint) async {
    if (_startLocation == null) {
      _showMessage(
          "Start location not found. Cannot calculate distance.", Colors.red);
      return;
    }

    double distance = _calculateDistance(_startLocation!, tappedPoint);
    setState(() => _isSaving = true);

    String haltName = "New Halt";
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
    } catch (e) {}
    setState(() => _isSaving = false);

    TextEditingController haltNameCtrl = TextEditingController(text: haltName);
    TextEditingController seqCtrl = TextEditingController();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Halt to Route ${widget.routeData['routeNumber']}'),
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
                    labelText: 'Halt Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(
              controller: seqCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Sequence Order (e.g., 1, 2, 3)',
                  border: OutlineInputBorder()),
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
            onPressed: () async {
              if (haltNameCtrl.text.isEmpty || seqCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              await _saveHaltToBackend(
                  haltNameCtrl.text,
                  double.parse(distance.toStringAsFixed(2)),
                  int.parse(seqCtrl.text),
                  tappedPoint);
            },
            child: const Text('Save Halt'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveHaltToBackend(
      String name, double distance, int sequence, LatLng point) async {
    setState(() => _isSaving = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/routes/${widget.routeData['id']}/halts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'haltName': name,
          'distanceFromStart': distance,
          'sequenceOrder': sequence,
          'latitude': point.latitude,
          'longitude': point.longitude
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _markers.add(Marker(
              markerId: MarkerId('new_halt_$sequence'),
              position: point,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueCyan),
              infoWindow: InfoWindow(
                  title: name, snippet: 'Seq: $sequence | $distance km')));
        });
        _showMessage('Halt Added Successfully!', Colors.green);
      } else {
        _showMessage('Failed to save halt.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error saving halt.', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Halts - Route ${widget.routeData['routeNumber']}'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
                const CameraPosition(target: LatLng(7.8731, 80.7718), zoom: 7),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            onLongPress: _onMapLongPress,
          ),
          if (_isLoading || _isSaving)
            const Center(
                child: Card(
                    child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator()))),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  "Orange = Existing Halts\nLong Press to add new Halts (Cyan)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
