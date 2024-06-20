import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
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
  bool showValidationMessage =
      false; // Flag to control visibility of the validation message
  bool showTextArea =
      false; // Flag to control visibility of the text area and validate button
  bool isValidating = false; // Flag to indicate validation process
  String validationMessage = '';
  Color validationMessageColor = Colors.red;
  IconData validationIcon = Icons.error; // Icon to show validation result

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

          // Perform text recognition on the cropped image
          final RecognizedText recognizedText =
              await textRecognizer.processImage(inputImage);
          setState(() {
            scannedTextLines = recognizedText.text.split('\n');
            validationMessage = ''; // Reset validation message
            showValidationMessage = false; // Hide validation message initially
            showTextArea = true; // Show text area and validate button
          });
        }
      }
    } catch (e) {
      print(e);
    }

    isBusy = false;
  }

  Future<File?> cropImage(String imagePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: null,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          minimumAspectRatio: 1.0,
        ),
      ],
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> validateBatchNumber() async {
    if (scannedTextLines.isEmpty) return;

    setState(() {
      isValidating = true; // Set validating state to true
    });

    final batchNo = scannedTextLines[0];
    final url = Uri.parse('http://192.168.0.118/productScan/public/api/scan');
    final response = await http.post(url, body: {'batchNo': batchNo});

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      setState(() {
        showValidationMessage = true; // Show validation message
        if (responseBody['status']) {
          validationMessage = responseBody['message'];
          validationMessageColor = Colors.green;
          validationIcon = Icons.check_circle; // Success icon
        } else {
          validationMessage = responseBody['message'];
          validationMessageColor = Colors.red;
          validationIcon = Icons.error; // Error icon
        }
      });
    } else {
      setState(() {
        showValidationMessage = true; // Show validation message
        validationMessage = 'Error: ${response.statusCode}';
        validationMessageColor = Colors.red;
        validationIcon = Icons.error; // Error icon
      });
    }

    setState(() {
      isValidating = false; // Set validating state to false
    });
  }

  void clearScannedText() {
    setState(() {
      scannedTextLines = [];
      showTextArea = false; // Hide text area and validate button
      showValidationMessage = false; // Hide validation message
      validationMessage = '';
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
            child: isCameraInitialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
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
          if (showTextArea) // Conditionally render the text area and validate button
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
          if (showTextArea) // Conditionally render the validate button or loading icon
            isValidating
                ? CircularProgressIndicator() // Show loading icon
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
          if (showValidationMessage) // Conditionally render the validation message container
            Container(
              padding: const EdgeInsets.all(18.0),
              color:
                  validationMessageColor, // Set the background color of the container
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(validationIcon,
                      color: Colors.black), // Show validation icon
                  SizedBox(width: 10),
                  Text(
                    validationMessage,
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.black), // Set the text color to black
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
