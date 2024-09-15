import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  MyApp({required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Capture App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false, // Remove the debug banner
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  CameraScreen({required this.camera});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextEditingController _metadataController = TextEditingController();
  String _uploadResult = ''; // To store the upload result (flower count)

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final XFile imageFile = await _controller.takePicture();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/${DateTime.now().toIso8601String()}.jpg';
      await imageFile.saveTo(filePath);
      await _uploadImage(filePath, _metadataController.text);
    } catch (e) {
      print(e);
    }
  }

  Future<void> _uploadImage(String filePath, String metadata) async {
    final url = 'http://127.0.0.1:8000/batch_predict/';
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..files.add(await http.MultipartFile.fromPath('image', filePath))
      ..fields['metadata'] = metadata;

    final response = await request.send();
    final responseBody = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      // Parse the response (assuming the response is JSON with 'count' field)
      final responseData = jsonDecode(responseBody.body);
      final flowerCount = responseData['count'];

      // Update the state with the result (flower count)
      setState(() {
        _uploadResult = 'Flower Count: $flowerCount';
      });
    } else {
      // Handle error
      setState(() {
        _uploadResult = 'Upload failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flower Count Capture'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return CameraPreview(_controller);
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            child: TextField(
              controller: _metadataController,
              decoration: InputDecoration(
                labelText: 'Enter Metadata',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.text_fields),
              ),
              maxLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton(
              onPressed: _takePicture,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text('Capture and Upload'),
            ),
          ),
          // Display the result (flower count) below the button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _uploadResult,
              style: TextStyle(
                fontSize: 18,
                color: _uploadResult.contains('failed')
                    ? Colors.red
                    : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
