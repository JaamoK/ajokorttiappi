import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

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

  bool _showFrontButton = true;
  bool _showBackButton = true;

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
        _showFrontButton = false;
      });
    }

    // Load back image
    final backImagePath = prefs.getString('backImagePath');
    if (backImagePath != null && File(backImagePath).existsSync()) {
      setState(() {
        _backImage = File(backImagePath);
        _showBackButton = false;
      });
    }
  }

  Future<void> _takePhoto(bool isFront) async {
    // Open the camera screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          cameras: widget.cameras,
          isFront: isFront,
        ),
      ),
    );

    // Save the captured photo
    if (result != null && result is File) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (isFront) {
          _frontImage = result;
          prefs.setString('frontImagePath', _frontImage!.path);
          _showFrontButton = false;
        } else {
          _backImage = result;
          prefs.setString('backImagePath', _backImage!.path);
          _showBackButton = false;
        }
      });
    }
  }

  Future<void> _resetAllPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _frontImage = null;
      _backImage = null;
      _showFrontButton = true;
      _showBackButton = true;
    });
    prefs.remove('frontImagePath');
    prefs.remove('backImagePath');
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
          const SizedBox(height: 20),
          if (!_showFrontButton || !_showBackButton)
            ElevatedButton(
              onPressed: _resetAllPhotos,
              child: const Text('Reset All Photos'),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_showFrontButton)
            FloatingActionButton(
              onPressed: () => _takePhoto(true), // Front photo
              tooltip: 'Add Front Photo',
              child: const Icon(Icons.camera_alt),
            ),
          const SizedBox(height: 10),
          if (_showBackButton)
            FloatingActionButton(
              onPressed: () => _takePhoto(false), // Back photo
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
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.high,
      );
      _initializeControllerFuture = _controller.initialize();
    } catch (e) {
      print('Error initializing camera: $e');
    }
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

      // Crop the image based on the fixed card-sized frame
      final croppedImage = await _cropImage(File(image.path));
      Navigator.pop(context, croppedImage);
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
                // Mask the area outside the card view
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double screenWidth = constraints.maxWidth;
                    final double cardWidth = screenWidth * 0.9; // 90% of the screen width
                    final double cardHeight = cardWidth / aspectRatio;

                    return Stack(
                      children: [
                        // Top mask
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: null,
                          height: (constraints.maxHeight - cardHeight) / 2,
                          child: Container(color: Colors.black.withOpacity(0.7)),
                        ),
                        // Bottom mask
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          top: null,
                          height: (constraints.maxHeight - cardHeight) / 2,
                          child: Container(color: Colors.black.withOpacity(0.7)),
                        ),
                        // Left mask
                        Positioned(
                          top: (constraints.maxHeight - cardHeight) / 2,
                          bottom: (constraints.maxHeight - cardHeight) / 2,
                          left: 0,
                          right: null,
                          width: (constraints.maxWidth - cardWidth) / 2,
                          child: Container(color: Colors.black.withOpacity(0.7)),
                        ),
                        // Right mask
                        Positioned(
                          top: (constraints.maxHeight - cardHeight) / 2,
                          bottom: (constraints.maxHeight - cardHeight) / 2,
                          right: 0,
                          left: null,
                          width: (constraints.maxWidth - cardWidth) / 2,
                          child: Container(color: Colors.black.withOpacity(0.7)),
                        ),
                        // Card-sized frame
                        Center(
                          child: AspectRatio(
                            aspectRatio: aspectRatio,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color.fromARGB(255, 211, 146, 211), width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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

Future<File> _cropImage(File imageFile) async {
  final img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Define the cropping area based on the card-sized frame
  final int cropWidth = (image.width * 0.9).toInt(); // 90% of the width
  final int cropHeight = (cropWidth / (3 / 2)).toInt(); // Maintain 3:2 aspect ratio
  final int cropLeft = ((image.width - cropWidth) / 2).toInt(); // Center horizontally
  final int cropTop = ((image.height - cropHeight) / 2).toInt(); // Center vertically

  // Crop the image
  final cropped = img.copyCrop(
    image,
    cropLeft,
    cropTop,
    cropWidth,
    cropHeight,
  );

  // Save the cropped image to a new file
  final croppedFile = File('${imageFile.path}_cropped');
  croppedFile.writeAsBytesSync(img.encodeJpg(cropped));
  return croppedFile;
}