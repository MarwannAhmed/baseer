// lib/app/router.dart

import 'package:baseer/features/camera/presentation/camera_page.dart';
import 'package:baseer/features/onboarding/presentation/splash_page.dart';
import 'package:baseer/features/onboarding/presentation/welcome_page.dart';
import 'package:baseer/features/onboarding/presentation/permissions_page.dart';
import 'package:baseer/features/onboarding/presentation/voice_setup_page.dart';
import 'package:baseer/features/onboarding/presentation/features_page.dart';
import 'package:flutter/material.dart';

class AppRouter {
  AppRouter._();

  static const String splash      = '/';
  static const String welcome     = '/welcome';
  static const String permissions = '/permissions';
  static const String voiceSetup  = '/voice_setup';
  static const String features    = '/features';
  static const String camera      = '/camera';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashPage());
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomePage());
      case permissions:
        return MaterialPageRoute(builder: (_) => const PermissionsPage());
      case voiceSetup:
        return MaterialPageRoute(builder: (_) => const VoiceSetupPage());
      case features:
        return MaterialPageRoute(builder: (_) => const FeaturesPage());
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
