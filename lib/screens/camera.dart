import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
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

  final GlobalKey _cameraPreviewKey = GlobalKey();

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
        // Get the rectangle coordinates
        final RenderBox renderBox =
            _cameraPreviewKey.currentContext!.findRenderObject() as RenderBox;
        final overlayBox =
            renderBox.localToGlobal(Offset.zero) & renderBox.size;

        // Process the captured image to get only the part inside the green square
        final croppedFile =
            await processCapturedImage(picture.path, overlayBox);
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

  Future<File?> processCapturedImage(String imagePath, Rect overlayBox) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final originalImage = img.decodeImage(Uint8List.fromList(bytes))!;

      // Get the size of the Camera Preview
      final previewSize = _cameraController!.value.previewSize!;
      final previewWidth = previewSize.width;
      final previewHeight = previewSize.height;

      // Calculate the scaling factor for the coordinates
      final double scaleX = originalImage.width / previewWidth;
      final double scaleY = originalImage.height / previewHeight;

      // Define the green rectangle on the screen
      final double greenRectLeft = 30.0;
      final double greenRectTop = 50.0;
      final double greenRectWidth = MediaQuery.of(context).size.width - 60.0;
      final double greenRectHeight = MediaQuery.of(context).size.height -
          MediaQuery.of(context).size.height * 0.3 -
          100.0;

      // Apply the scaling factors to the green rectangle's coordinates to get the crop area
      final int cropLeft = (greenRectLeft * scaleX).toInt();
      final int cropTop = (greenRectTop * scaleY).toInt();
      final int cropWidth = (greenRectWidth * scaleX).toInt();
      final int cropHeight = (greenRectHeight * scaleY).toInt();

      // Crop the image to the specified region
      final croppedImage =
          img.copyCrop(originalImage, cropLeft, cropTop, cropWidth, cropHeight);
      final croppedFile = File('${Directory.systemTemp.path}/cropped_image.jpg')
        ..writeAsBytesSync(img.encodeJpg(croppedImage));
      print("Cropped image saved successfully.");
      return croppedFile;
    } catch (e) {
      print("Error: $e");
      return null;
    }
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
          Expanded(
            child: Stack(
              key: _cameraPreviewKey,
              children: [
                if (isCameraInitialized && croppedImageFile == null)
                  CameraPreview(_cameraController!)
                else if (croppedImageFile != null)
                  Image.file(croppedImageFile!)
                else
                  Center(child: CircularProgressIndicator()),
                if (isCameraInitialized)
                  Positioned(
                    left: 30,
                    right: 30,
                    top: 50,
                    bottom: MediaQuery.of(context).size.height * 0.3,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.green, // Change border color to green
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Place product information inside the rectangle',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
