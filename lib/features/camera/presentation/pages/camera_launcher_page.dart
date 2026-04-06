import 'package:baseer/features/camera/application/camera_initializer.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CameraLauncherPage extends StatefulWidget {
  const CameraLauncherPage({super.key});

  @override
  State<CameraLauncherPage> createState() => _CameraLauncherPageState();
}

class _CameraLauncherPageState extends State<CameraLauncherPage> {
  final CameraInitializer _cameraInitializer = const CameraInitializer();

  CameraController? _cameraController;
  String? _errorMessage;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    if (!_supportsCamera()) {
      setState(() {
        _errorMessage = 'Camera startup is currently supported on Android and iOS only.';
        _isInitializing = false;
      });
      return;
    }

    try {
      final cameras = await _cameraInitializer.getAvailableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera was found on this device.';
          _isInitializing = false;
        });
        return;
      }

      final controller = _cameraInitializer.createController(cameras.first);
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Unable to start camera.';
        _isInitializing = false;
      });
    }
  }

  bool _supportsCamera() {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: _isInitializing
              ? const CircularProgressIndicator()
              : _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    )
                  : controller != null
                      ? CameraPreview(controller)
                      : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
