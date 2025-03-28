import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras(); // Get available cameras
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ajokortti Appi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MyHomePage(cameras: cameras),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyHomePage({super.key, required this.cameras});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _frontImage;
  File? _backImage;

  @override
  void initState() {
    super.initState();
    _loadSavedImages();
  }

  Future<void> _loadSavedImages() async {
    final prefs = await SharedPreferences.getInstance();

    // Load front image
    final frontImagePath = prefs.getString('frontImagePath');
    if (frontImagePath != null && File(frontImagePath).existsSync()) {
      setState(() {
        _frontImage = File(frontImagePath);
      });
    }

    // Load back image
    final backImagePath = prefs.getString('backImagePath');
    if (backImagePath != null && File(backImagePath).existsSync()) {
      setState(() {
        _backImage = File(backImagePath);
      });
    }
  }

  Future<void> _takePhoto(bool isFront) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          cameras: widget.cameras,
          isFront: isFront,
        ),
      ),
    );

    if (result != null && result is File) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (isFront) {
          _frontImage = result;
          prefs.setString('frontImagePath', _frontImage!.path);
        } else {
          _backImage = result;
          prefs.setString('backImagePath', _backImage!.path);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajokortti Appi'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCard(_frontImage, 'Front Side'),
          const SizedBox(height: 20),
          _buildCard(_backImage, 'Back Side'),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _takePhoto(true),
            tooltip: 'Add Front Photo',
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => _takePhoto(false),
            tooltip: 'Add Back Photo',
            child: const Icon(Icons.camera_alt_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(File? image, String placeholderText) {
    // Define the aspect ratio for a driving license (3:2)
    final double aspectRatio = 3 / 2;

    // Calculate the width and height based on the screen size and aspect ratio
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth * 0.98; // 98% of the screen width
    final double cardHeight = cardWidth / aspectRatio; // Maintain 3:2 aspect ratio

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0.01), // 1% padding on left and right
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        color: Colors.white,
      ),
      child: image != null
          ? Image.file(
              image,
              fit: BoxFit.cover,
            )
          : Center(
              child: Text(
                'No image available\n($placeholderText)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool isFront;

  const CameraScreen({super.key, required this.cameras, required this.isFront});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      Navigator.pop(context, File(image.path));
    } catch (e) {
      print('Error capturing photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = 3 / 2; // Aspect ratio for the card
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFront ? 'Capture Front Side' : 'Capture Back Side'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _capturePhoto,
        child: const Icon(Icons.camera),
      ),
    );
  }
}