// lib/baseer_app.dart

import '../app/router.dart';
import '../features/onboarding/presentation/splash_page.dart';
import 'package:flutter/material.dart';

class BaseerApp extends StatelessWidget {
  const BaseerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Use home: so the SplashPage widget is always the first frame rendered.
      // initialRoute + onGenerateRoute can miss the first paint on slow devices.
      home: const SplashPage(),
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}