import 'package:flutter/material.dart';
import 'camera_screen.dart';

void main() {
  runApp(FaceDetectionApp());
}

class FaceDetectionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}
