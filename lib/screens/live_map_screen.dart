import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";
  GoogleMapController? _mapController;
  Set<Marker> _busMarkers = {};
  Timer? _timer;
  bool _hasLocationPermission = false;

  BitmapDescriptor? _customBusIcon;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(6.7115, 79.9074),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadCustomMarker();
    _fetchLiveBuses();

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchLiveBuses();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  Future<void> _loadCustomMarker() async {
    try {
      final Uint8List markerIcon = await getBytesFromAsset(
        'assets/bus_icon.png',
        100,
      );

      if (mounted) {
        setState(() {
          _customBusIcon = BitmapDescriptor.fromBytes(markerIcon);
        });
      }
    } catch (e) {
      print("Error loading custom marker: $e");
    }
  }

  Future<void> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      setState(() {
        _hasLocationPermission = true;
      });
    }
  }

  Future<void> _fetchLiveBuses() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/trips/active'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        List<dynamic> activeTrips = jsonDecode(response.body);
        Set<Marker> newMarkers = {};

        for (var trip in activeTrips) {
          if (trip['currentLatitude'] != null &&
              trip['currentLongitude'] != null) {
            double lat = (trip['currentLatitude'] as num).toDouble();
            double lng = (trip['currentLongitude'] as num).toDouble();

            newMarkers.add(
              Marker(
                markerId: MarkerId('bus_${trip['busId']}'),
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(
                  title: 'Bus ID: ${trip['busId']}',
                  snippet: 'Route: ${trip['routeId']} (Live)',
                ),
                icon:
                    _customBusIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueBlue,
                    ),
              ),
            );

            if (newMarkers.length == 1 && _mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLng(LatLng(lat, lng)),
              );
            }
          }
        }

        if (mounted) {
          setState(() {
            _busMarkers = newMarkers;
          });
        }
      }
    } catch (e) {
      print("Error fetching live buses: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Bus Radar 🚌',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        markers: _busMarkers,
        myLocationEnabled: _hasLocationPermission,
        myLocationButtonEnabled: _hasLocationPermission,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}
