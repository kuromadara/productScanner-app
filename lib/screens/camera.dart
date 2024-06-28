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
        final inputImage = InputImage.fromFilePath(picture.path);
        final RecognizedText recognizedText =
            await textRecognizer.processImage(inputImage);

        // Split scanned text into lines
        List<String> lines = recognizedText.text.split('\n');

        // Check if the first line has exactly 12 characters after trimming spaces
        if (lines.isNotEmpty) {
          String firstLine =
              lines[0].trim().replaceAll(' ', ''); // Remove spaces
          if (firstLine.length == 12) {
            // Capture up to four lines
            setState(() {
              scannedTextLines =
                  lines.sublist(0, lines.length > 4 ? 4 : lines.length);
              validationMessage = '';
              showValidationMessage = false;
              showTextArea = true;
              croppedImageFile = File(picture.path); // Save the captured image
            });
          } else {
            setState(() {
              showValidationMessage = true;
              validationMessage =
                  'Error: ${lines[0].trim()} is not a valid batch number';
              validationMessageColor = Colors.red;
              validationIcon = Icons.error;
              showTextArea = false;
              scannedTextLines = [];
              croppedImageFile = File(picture.path); // Save the captured image
            });
          }
        }
      }
    } catch (e) {
      print(e);
    }

    isBusy = false;
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
      initializeCamera();
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
        title: const Text(
          'Product Scanner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Center(
              child: Container(
                width: MediaQuery.of(context)
                    .size
                    .width, // Use the width of the screen
                child: AspectRatio(
                  aspectRatio: 1, // Set aspect ratio to 1:1 for square view
                  child: Stack(
                    key: _cameraPreviewKey,
                    children: [
                      if (isCameraInitialized && croppedImageFile == null)
                        Center(child: CameraPreview(_cameraController!))
                      else if (croppedImageFile != null)
                        Center(child: Image.file(croppedImageFile!))
                      else
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (croppedImageFile ==
              null) // Show scan and reset buttons only if no image is captured
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: scanText,
                  icon: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                  ),
                  label: const Text(
                    'Scan',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: const BorderSide(
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: clearScannedText,
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.black,
                  ),
                  label: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: const BorderSide(
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else // Show only the reset button if an image is captured
            ElevatedButton.icon(
              onPressed: clearScannedText,
              icon: const Icon(
                Icons.refresh,
                color: Colors.black,
              ),
              label: const Text(
                'Reset',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: const BorderSide(
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (showTextArea)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.white.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(
                      color: Colors.black,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: scannedTextLines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          line,
                          style: const TextStyle(fontSize: 18),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          if (showTextArea &&
              !isValidating) // Validate button shown only if there are lines and not validating
            ElevatedButton(
              onPressed: validateBatchNumber,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: const BorderSide(color: Colors.black),
                ),
              ),
              child: const Text(
                'Validate',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
          if (isValidating) // Show progress indicator while validating
            const CircularProgressIndicator(),
          const SizedBox(height: 10),
          if (showValidationMessage)
            Container(
              padding: const EdgeInsets.all(18.0),
              color: validationMessageColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(validationIcon, color: Colors.black),
                  const SizedBox(width: 10),
                  Text(
                    validationMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
