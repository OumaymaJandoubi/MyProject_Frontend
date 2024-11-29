import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart'; // For accessing the current location
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart'; // For launching Google Maps
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pothole Detection',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto', // Modern font
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _image; // To store the captured image
  Uint8List? _processedImage; // To store the processed image
  bool _isProcessing = false; // Flag to indicate image processing
  final ImagePicker _picker = ImagePicker(); // ImagePicker instance
  Position? _currentPosition; // To store the current location

  // Method to open the camera
  Future<void> _openCamera() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path); // Store the captured image
        _processedImage = null; // Reset processed image
        _isProcessing = true; // Set processing flag
      });

      // Send image to backend
      await _sendImageToBackend();
    }
  }

  // Method to send the image to the Flask backend
  Future<void> _sendImageToBackend() async {
    if (_image == null) return;

    await _getCurrentLocation(); // Ensure the location is fetched

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not available.')),
      );
      return;
    }

    final uri = Uri.parse('http://192.168.1.15:5000/detect'); // Replace with the backend URL
    final request = http.MultipartRequest('POST', uri);

    // Attach the image
    request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

    // Attach location data
    request.fields['latitude'] = _currentPosition!.latitude.toString();
    request.fields['longitude'] = _currentPosition!.longitude.toString();

    final response = await request.send();

    if (response.statusCode == 200) {
      final bytes = await response.stream.toBytes();
      setState(() {
        _processedImage = bytes; // Store the processed image
        _isProcessing = false; // Reset processing flag
      });
    } else {
      setState(() {
        _isProcessing = false; // Reset processing flag
      });
      print('Error: ${response.statusCode}');
    }
  }


  // Method to get the current location with permissions
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Location permissions are permanently denied. Please enable them in settings.')),
      );
      return;
    }

    // Get current location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location.')),
      );
    }
  }

  // Method to open Google Maps at the current location
  void _openMaps() {
    if (_currentPosition != null) {
      final url =
          'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pothole Detection'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the processed image or loading indicator
            _isProcessing
                ? Center(child: CircularProgressIndicator())
                : _processedImage == null
                ? Text(
              'Capture an image to detect potholes',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            )
                : Column(
              children: [
                Card(
                  elevation: 8,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.memory(
                      _processedImage!, // Display the processed image
                      width: 300,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextButton.icon(
                  onPressed: _openMaps,
                  icon: Icon(Icons.location_on, color: Colors.white),
                  label: Text(
                    'Go to Location',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              child: Text(
                'Open Camera',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationMapScreen extends StatefulWidget {
  final Position currentPosition;

  const LocationMapScreen({required this.currentPosition, Key? key})
      : super(key: key);

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  late GoogleMapController _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detected Pothole Location'),
        backgroundColor: Colors.teal,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.currentPosition.latitude,
              widget.currentPosition.longitude),
          zoom: 16,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        markers: {
          Marker(
            markerId: const MarkerId('pothole_location'),
            position: LatLng(widget.currentPosition.latitude,
                widget.currentPosition.longitude),
            infoWindow: const InfoWindow(
              title: 'Pothole Detected Here',
              snippet: 'Current Location',
            ),
          ),
        },
      ),
    );
  }
}
