import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  bool isDetecting = false;
  late FaceDetector _faceDetector;
  String detectionMessage = 'No Faces Detected';
  List<Face> detectedFaces = [];
  bool isDetectionEnabled = true;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    _faceDetector = GoogleMlKit.vision.faceDetector(
      FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
      ),
    );
  }

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamerasAvailable', 'No cameras found on the device.');
      }
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
      );

      await _cameraController!.initialize();
      if (isDetectionEnabled) startFaceDetection();
      setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void startFaceDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera not initialized.');
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (isDetecting || !isDetectionEnabled) return;
      isDetecting = true;

      try {
        final InputImage? inputImage = getInputImageFromCameraImage(image) as InputImage?;
        if (inputImage == null) {
          print('InputImage is null. Skipping frame.');
          isDetecting = false;
          return;
        }

        final List<Face> faces = await _faceDetector.processImage(inputImage);

        setState(() {
          detectedFaces = faces;
          detectionMessage = faces.isNotEmpty
              ? 'Faces Detected: ${faces.length}'
              : 'No Faces Detected';
        });
      } catch (e) {
        print('Error detecting faces: $e');
      }

      isDetecting = false;
    });
  }

  Type? getInputImageFromCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImageData = InputImageData(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        imageRotation: InputImageRotationMethods.fromRawValue(
            _cameraController?.description.sensorOrientation) ??
            InputImageRotation.rotation0deg,
        inputImageFormat:
        InputImageFormatMethods.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21,
        planeData: image.planes
            .map(
              (Plane plane) => InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          ),
        )
            .toList(),
      );

      return InputImage;
    } catch (e) {
      print('Error creating InputImage: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Face Detection')),
      body: Stack(
        children: [
          CameraPreview(_cameraController!),
          ...detectedFaces.map((face) {
            final boundingBox = face.boundingBox;
            return Positioned(
              left: boundingBox.left,
              top: boundingBox.top,
              width: boundingBox.width,
              height: boundingBox.height,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red, width: 2),
                ),
              ),
            );
          }).toList(),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(8.0),
              color: Colors.black.withOpacity(0.7),
              child: Text(
                detectionMessage,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    isDetectionEnabled = !isDetectionEnabled;
                    detectionMessage = isDetectionEnabled
                        ? 'Face Detection Enabled'
                        : 'Face Detection Disabled';
                    if (isDetectionEnabled) {
                      startFaceDetection();
                    } else {
                      _cameraController?.stopImageStream();
                    }
                  });
                },
                child: Text(
                  isDetectionEnabled ? 'Disable Detection' : 'Enable Detection',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputImage? InputImagePlaneMetadata({required int bytesPerRow, int? height, int? width}) {
}

InputImageData({required Size size, required InputImageRotation imageRotation, required InputImageFormat inputImageFormat, required List<dynamic> planeData}) {
}

class InputImageFormatMethods {
  static InputImageFormat? fromRawValue(int? rawValue) {
    switch (rawValue) {
      case 17: // NV21 format for Android
        return InputImageFormat.nv21;
      case 35: // YUV_420_888 format for iOS
        return InputImageFormat.yuv420;
      default:
        return null;
    }
  }
}

class InputImageRotationMethods {
  static InputImageRotation? fromRawValue(int? rawValue) {
    switch (rawValue) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }
}
