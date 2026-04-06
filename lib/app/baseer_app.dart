import 'package:baseer/features/camera/presentation/pages/camera_launcher_page.dart';
import 'package:flutter/material.dart';

class BaseerApp extends StatelessWidget {
  const BaseerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraLauncherPage(),
    );
  }
}
