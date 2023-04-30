import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  File? _image;
  List<Face> _faces = [];
  String? _rgbValues;
  ui.Image? image;
  List<Rect> rects = [];
  bool isLoading = false;
  List<int> rgbValues = [];
  List<int> red = [], green = [], blue = [];

  void _getFromGallery() async {
    setState(() {
      isLoading = true;
    });
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    setState(() {
      _image = null;
      image = null;
      _rgbValues = null;
      _image = File(pickedFile!.path);
    });
    detectFaces();
  }

  void detectFaces() async {
    final InputImage inputImage = InputImage.fromFilePath(_image!.path);
    final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
    final List<Face> faces = await faceDetector.processImage(inputImage);
    setState(() {
      _faces = faces;
    });
    rects.clear();
    for (int i = 0; i < faces.length; i++) {
      rects.add(faces[i].boundingBox);
      red.add(0);
      green.add(0);
      blue.add(0);
    }
    var bytesFromImageFile = await _image!.readAsBytes();
    decodeImageFromList(bytesFromImageFile).then((img) async {
      setState(() {
        image = img;
        isLoading = false;
      });
      final bytes = await image!.toByteData();
      setState(() {
        rgbValues = bytes!.buffer.asUint8List();
        calcRGB();
      });
    });
  }

  void calcRGB() async {
    Rect faceRect = _faces[0].boundingBox;
    for (int j = 0; j < _faces.length; j++) {
      final x0 = faceRect.left.toInt();
      final y0 = faceRect.top.toInt();
      final stride = image!.width * 4;
      final offset0 = y0 * stride + x0 * 4;
      final pixels = faceRect.width.toInt() * faceRect.height.toInt();
      final List<List<int>> pixelValues = [];
      for (var i = 0; i < pixels; i++) {
        final x = i % faceRect.width.toInt();
        final y = (i / faceRect.width.toInt()).floor();
        final offset = offset0 + y * stride + x * 4;
        final r = rgbValues[offset];
        final g = rgbValues[offset + 1];
        final b = rgbValues[offset + 2];
        pixelValues.add([r, g, b]);
        red[j] += r;
        green[j] += g;
        blue[j] += b;
      }
      red[j] = red[j] ~/ pixels;
      green[j] = green[j] ~/ pixels;
      blue[j] = blue[j] ~/ pixels;
      _rgbValues = 'Values of RGB: ${red[j]}, ${green[j]}, ${blue[j]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Face Detection'),
        ),
        body: Center(
          child: _image == null
              ? const Text('No image selected')
              : Column(
                  // mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // Image.file(_image!, width: 300, height: 300),
                    (image == null)
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 150),
                            child: CircularProgressIndicator())
                        : FittedBox(
                            child: SizedBox(
                              height: image!.height.toDouble(),
                              width: image!.width.toDouble(),
                              child: CustomPaint(
                                painter: Painter(rects: rects, image: image!),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                    (_rgbValues != null)
                        ? Expanded(
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Red:  ${red[index].toString()}",
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(
                                    width: 20,
                                  ),
                                  Text(
                                    "Green: ${green[index].toString()}",
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                  const SizedBox(
                                    width: 20,
                                  ),
                                  Text(
                                    "Blue: ${blue[index].toString()}",
                                    style: const TextStyle(color: Colors.blue),
                                  )
                                ],
                              ),
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemCount: _faces.length,
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _getFromGallery(),
          tooltip: 'Pick Image',
          child: const Icon(Icons.camera),
        ),
      ),
    );
  }
}

class Painter extends CustomPainter {
  final List<Rect> rects;
  final ui.Image image;

  Painter({required this.rects, required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawImage(image, Offset.zero, paint);
    for (var i = 0; i <= rects.length - 1; i++) {
      canvas.drawRect(rects[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
