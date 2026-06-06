import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/tts_service.dart';

const _kNavy  = Color(0xFF152E3E);
const _kSteel = Color(0xFF2D6A8E);

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    TTSService().init().then((_) {
      if (mounted) TTSService().speak('مرحباً بك في بصير').catchError((_) {});
    }).catchError((_) {});

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/permissions');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/imgs/Team-18-Baseer.png',
              width: 240,
              errorBuilder: (context2, error, st) => Text(
                'img error: $error',
                style: const TextStyle(color: _kNavy),
              ),
            ),
            const SizedBox(height: 80),
            const SizedBox(
              width: 44, height: 44,
              child: CircularProgressIndicator(color: _kSteel, strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
