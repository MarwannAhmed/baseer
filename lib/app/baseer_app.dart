// lib/baseer_app.dart

import '../app/router.dart';
import 'package:flutter/material.dart';

class BaseerApp extends StatelessWidget {
  const BaseerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: AppRouter.colorTest,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}