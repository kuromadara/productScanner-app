import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:convert';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  bool isBusy = false;
  bool isCameraInitialized = false;
  final textRecognizer = TextRecognizer();
  List<String> scannedTextLines = [];
  bool showValidationMessage = false;
  bool showTextArea = false;
  bool isValidating = false;
  String validationMessage = '';
  Color validationMessageColor = Colors.red;
  IconData validationIcon = Icons.error;
  File? croppedImageFile;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _cameraController = CameraController(cameras![0], ResolutionPreset.high);
      await _cameraController?.initialize();
      setState(() {
        isCameraInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    textRecognizer.close();
    super.dispose();
  }

  void scanText() async {
    if (isBusy ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) return;
    isBusy = true;

    try {
      final picture = await _cameraController?.takePicture();
      if (picture != null) {
        final croppedFile = await cropImage(picture.path);
        if (croppedFile != null) {
          final inputImage = InputImage.fromFilePath(croppedFile.path);

          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          setState(() {
            scannedTextLines = recognizedText.text.split('\n');
            validationMessage = '';
            showValidationMessage = false;
            showTextArea = true;
            croppedImageFile = croppedFile;
          });
        }
      }
    } catch (e) {
      print(e);
    }

    isBusy = false;
  }

  Future<File?> cropImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final originalImage = img.decodeImage(Uint8List.fromList(bytes))!;

      // Convert the image to grayscale
      final grayscaleImage = img.grayscale(originalImage);

      // Convert the image to black and white
      final bwImage = _convertToBlackAndWhite(grayscaleImage, 128);

      // Detect the bounding box of the text
      int left = bwImage.width, top = bwImage.height, right = 0, bottom = 0;
      for (int y = 0; y < bwImage.height; y++) {
        for (int x = 0; x < bwImage.width; x++) {
          final pixel = bwImage.getPixel(x, y);
          if (pixel == img.getColor(0, 0, 0)) {
            // Black pixel
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
      }

      print('left: $left, top: $top, right: $right, bottom: $bottom');
      if (left < right && top < bottom) {
        final croppedImage = img.copyCrop(
            bwImage, left, top, right - left + 1, bottom - top + 1);
        final croppedFile = File(imagePath)
          ..writeAsBytesSync(img.encodeJpg(croppedImage));
        print("Cropped image saved successfully.");
        return croppedFile;
      } else {
        print("Failed to detect valid bounding box.");
        return null;
      }
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  img.Image _convertToBlackAndWhite(img.Image grayscaleImage, int threshold) {
    final bwImage = img.Image(grayscaleImage.width, grayscaleImage.height);
    for (int y = 0; y < grayscaleImage.height; y++) {
      for (int x = 0; x < grayscaleImage.width; x++) {
        final pixel = grayscaleImage.getPixel(x, y);
        final l = img.getLuminance(pixel);
        if (l > threshold) {
          bwImage.setPixel(x, y, img.getColor(255, 255, 255)); // White
        } else {
          bwImage.setPixel(x, y, img.getColor(0, 0, 0)); // Black
        }
      }
    }
    return bwImage;
  }

  Future<void> validateBatchNumber() async {
    if (scannedTextLines.isEmpty) return;

    setState(() {
      isValidating = true;
    });

    final batchNo = scannedTextLines[0];
    final url = Uri.parse('http://192.168.0.118/productScan/public/api/scan');
    final response = await http.post(url, body: {'batchNo': batchNo});

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      setState(() {
        showValidationMessage = true;
        if (responseBody['status']) {
          validationMessage = responseBody['message'];
          validationMessageColor = Colors.green;
          validationIcon = Icons.check_circle;
        } else {
          validationMessage = responseBody['message'];
          validationMessageColor = Colors.red;
          validationIcon = Icons.error;
        }
      });
    } else {
      setState(() {
        showValidationMessage = true;
        validationMessage = 'Error: ${response.statusCode}';
        validationMessageColor = Colors.red;
        validationIcon = Icons.error;
      });
    }

    setState(() {
      isValidating = false;
    });
  }

  void clearScannedText() {
    setState(() {
      scannedTextLines = [];
      showTextArea = false;
      showValidationMessage = false;
      validationMessage = '';
      croppedImageFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product Scanner',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          SizedBox(height: 10),
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            child: isCameraInitialized && croppedImageFile == null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                : croppedImageFile != null
                    ? Image.file(croppedImageFile!)
                    : Center(child: CircularProgressIndicator()),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: scanText,
                icon: Icon(Icons.camera_alt, color: Colors.black),
                label: Text('Scan',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: Colors.black),
                  ),
                ),
              ),
              SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: clearScannedText,
                icon: Icon(Icons.refresh, color: Colors.black),
                label: Text('Reset',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (showTextArea)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.white.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: scannedTextLines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          line,
                          style: TextStyle(fontSize: 18),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          if (showTextArea)
            isValidating
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: validateBatchNumber,
                    child: Text('Validate', style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
          SizedBox(height: 10),
          if (showValidationMessage)
            Container(
              padding: const EdgeInsets.all(18.0),
              color: validationMessageColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(validationIcon, color: Colors.black),
                  SizedBox(width: 10),
                  Text(
                    validationMessage,
                    style: TextStyle(fontSize: 18, color: Colors.black),
                  ),
                ],
              ),
            ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
