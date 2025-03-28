import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ajokortti Appi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  File? _frontImage;
  File? _backImage;
  bool _isFront = true;

  final ImagePicker _picker = ImagePicker();
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  Future<void> _takePhoto(bool isFront) async {
    // Lock orientation to landscape
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        if (isFront) {
          _frontImage = File(photo.path);
        } else {
          _backImage = File(photo.path);
        }
      });
    }

    // Restore orientation to allow both portrait and landscape
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  void _flipCard() {
    setState(() {
      _isFront = !_isFront;
      if (_isFront) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajokortti Appi'),
      ),
      body: Center(
        child: GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final angle = _animation.value * 3.14159; // Rotate 180 degrees
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateY(angle),
                child: angle <= 1.57
                    ? _buildCard(_frontImage, 'Etupuoli')
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.14159),
                        child: _buildCard(_backImage, 'Takapuoli'),
                      ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _takePhoto(true),
            tooltip: 'Ota kuva etupuolesta',
            child: const Icon(Icons.camera_front),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () => _takePhoto(false),
            tooltip: 'Ota kuva takapuolesta',
            child: const Icon(Icons.camera_rear),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(File? image, String placeholderText) {
    return Container(
      width: 300,
      height: 200,
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
                'Korttia ei ole skannattu sovellukseen\n($placeholderText)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
    );
  }
}
