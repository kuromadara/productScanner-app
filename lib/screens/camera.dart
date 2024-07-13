import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
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
  bool isTypeOne = true;
  String? batchNo;

  late AnimationController _animationController;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    initializeCamera();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    Future.delayed(Duration.zero, () {
      _showPopup();
    });
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
    _animationController.dispose();
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

        List<String> lines = recognizedText.text.split('\n');

        if (lines.isNotEmpty) {
          if (isTypeOne) {
            processTypeOne(lines);
          } else {
            processTypeTwo(lines);
          }
        }
        setState(() {
          croppedImageFile = File(picture.path);
        });
      }
    } catch (e) {
      print(e);
    }

    isBusy = false;
  }

  void processTypeOne(List<String> lines) {
    if (lines.length >= 1) {
      String firstLine = lines[0].trim().replaceAll(' ', '');
      if (firstLine.length == 12) {
        setState(() {
          batchNo = firstLine;
          scannedTextLines =
              lines.sublist(0, lines.length > 4 ? 4 : lines.length);
          validationMessage = '';
          showValidationMessage = false;
          showTextArea = true;
        });
      } else {
        setErrorState(
            'Error: $firstLine is not a valid batch number for Type One');
      }
    } else {
      setErrorState('Error: No text detected for Type One');
    }
  }

  void processTypeTwo(List<String> lines) {
    if (lines.length >= 2) {
      String secondLine = lines[1].trim().replaceAll(' ', '');
      if (secondLine.length == 10) {
        setState(() {
          batchNo = secondLine;
          scannedTextLines =
              lines.sublist(0, lines.length > 4 ? 4 : lines.length);
          validationMessage = '';
          showValidationMessage = false;
          showTextArea = true;
        });
      } else {
        setErrorState(
            'Error: $secondLine is not a valid Batch No. for Type Two');
      }
    } else {
      setErrorState('Error: Not enough lines detected for Type Two');
    }
  }

  void setErrorState(String message) {
    setState(() {
      showValidationMessage = true;
      validationMessage = message;
      validationMessageColor = Colors.red;
      validationIcon = Icons.error;
      showTextArea = false;
      scannedTextLines = [];
      batchNo = null;
    });
  }

  Future<void> validateBatchNumber() async {
    if (batchNo == null) return;

    setState(() {
      isValidating = true;
    });

    final url = Uri.parse('http://192.168.0.100/productScan/public/api/scan');
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
      batchNo = null;
    });
  }

  void _showPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation.value,
              child: AlertDialog(
                title: const Text('Scanning Instructions'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.network(
                      'https://assets10.lottiefiles.com/packages/lf20_jcikwtux.json',
                      width: 200,
                      height: 200,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Please position the white area within the scanner frame for optimal scanning results.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    child: const Text('Got it!'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    _animationController.forward();
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
        backgroundColor: Colors.blue,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[100]!, Colors.blue[50]!],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Type One',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Switch(
                  value: !isTypeOne,
                  onChanged: (value) {
                    setState(() {
                      isTypeOne = !value;
                      clearScannedText();
                    });
                  },
                  activeColor: Colors.blue,
                ),
                const Text('Type Two',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 3),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: isCameraInitialized && croppedImageFile == null
                          ? CameraPreview(_cameraController!)
                          : croppedImageFile != null
                              ? Image.file(croppedImageFile!, fit: BoxFit.cover)
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (croppedImageFile == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: scanText,
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text(
                      'Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: clearScannedText,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: clearScannedText,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Reset',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (showTextArea)
              Expanded(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView(
                    children: [
                      Text(
                        'Batch Number: $batchNo',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...scannedTextLines.map((line) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            line,
                            style: const TextStyle(fontSize: 18),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            if (showTextArea && !isValidating)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: ElevatedButton(
                  onPressed: validateBatchNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Validate',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isValidating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: CircularProgressIndicator(),
              ),
            if (showValidationMessage)
              Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(16.0),
                margin: const EdgeInsets.only(bottom: 20.0),
                decoration: BoxDecoration(
                  color: validationMessageColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(validationIcon, color: Colors.white),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        validationMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
