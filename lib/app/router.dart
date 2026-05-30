// lib/app/router.dart

import 'package:baseer/features/camera/presentation/camera_page.dart';
import 'package:baseer/features/onboarding/presentation/splash_page.dart';
import 'package:baseer/features/onboarding/presentation/permissions_page.dart';
import 'package:flutter/material.dart';

class AppRouter {
  AppRouter._();

  static const String splash      = '/';
  static const String permissions = '/permissions';
  static const String camera      = '/camera';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case permissions:
        return MaterialPageRoute(builder: (_) => const PermissionsPage());
      case camera:
        return MaterialPageRoute(builder: (_) => const LiveCameraPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            backgroundColor: Color(0xFF152E3E),
            body: Center(
              child: Text(
                'الصفحة غير موجودة',
                style: TextStyle(color: Color(0xFFF7F5F0), fontSize: 18),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
        );
    }
  }
}
