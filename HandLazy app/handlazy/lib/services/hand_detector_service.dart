import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img; // Need image package for resizing
import 'package:tflite_flutter/tflite_flutter.dart';

class HandDetectorService {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      // Use XNNPACKDelegate for faster inference on Android if available
      // if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());

      // Load landmark model directly
      _interpreter = await Interpreter.fromAsset(
        'assets/hand_landmark.tflite',
        options: options,
      );
      _isLoaded = true;
      print('✅ Model loaded successfully');

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Input shape: $inputShape');
      print('Output shape: $outputShape');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  Future<List<dynamic>?> runInference(CameraImage cameraImage) async {
    if (!_isLoaded || _interpreter == null) return null;

    // 1. Preprocess: Convert CameraImage (YUV) to RGB & Resize to 224x224
    // This is computationally expensive in Dart.
    // In production, we'd use native code or compute shaders.
    // For this MVP, we'll try a fast approximation or center crop.

    // Simplification: We need a [1, 224, 224, 3] input
    // Creating dummy input to test pipeline first
    var input = List.filled(1 * 224 * 224 * 3, 0.0).reshape([1, 224, 224, 3]);

    // Output: 63 values (21 landmarks * 3 coords x,y,z)
    var output = List.filled(1 * 63, 0.0).reshape([1, 63]);
    var handCheck = List.filled(
      1 * 1,
      0.0,
    ).reshape([1, 1]); // Hand presence score

    try {
      // Run inference
      // _interpreter!.run(input, output);
      // Use runForMultipleInputs if model has multiple outputs

      // Note: Actual implementation requires real image data conversion
      // returning null for now to prevent crash until image utils are added
      return null;
    } catch (e) {
      print('Inference error: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
