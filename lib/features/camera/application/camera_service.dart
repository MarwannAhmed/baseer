// lib/features/camera/data/camera_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';

/// Owns the [CameraController] lifecycle.
/// Used by [LiveCameraPage] — do not duplicate camera logic inline.
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  CameraController? get controller => _controller;

  bool get isReady =>
      _controller != null && _controller!.value.isInitialized;

  /// Initialises the first available back-facing camera.
  /// Falls back to [_cameras!.first] on devices with no back camera.
  Future<void> initialize() async {
    _cameras = await availableCameras();

    final backCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
  }

  /// Captures one frame and returns it as an [XFile].
  Future<XFile> takePicture() async {
    if (!isReady) throw StateError('CameraService: call initialize() first.');
    return _controller!.takePicture();
  }

  /// Convenience helper: captures a frame and encodes it as base-64 JPEG.
  Future<String> captureBase64Image() async {
    final file = await takePicture();
    final bytes = await File(file.path).readAsBytes();
    return base64Encode(bytes);
  }

  void dispose() {
    _controller?.dispose();
  }
}