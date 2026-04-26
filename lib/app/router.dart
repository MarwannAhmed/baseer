// // lib/router.dart

// import 'package:baseer/features/camera/presentation/camera_page.dart';
// import 'package:flutter/material.dart';

// /// Named-route registry for the app.
// /// [BaseerApp] passes [AppRouter.generateRoute] to [MaterialApp.onGenerateRoute].
// class AppRouter {
//   AppRouter._();

//   static const String camera = '/';

//   static Route<dynamic> generateRoute(RouteSettings settings) {
//     switch (settings.name) {
//       case camera:
//         return MaterialPageRoute(
//           builder: (_) => const LiveCameraPage(),
//         );
//       default:
//         return MaterialPageRoute(
//           builder: (_) => const Scaffold(
//             backgroundColor: Colors.black,
//             body: Center(
//               child: Text(
//                 'الصفحة غير موجودة',
//                 style: TextStyle(color: Colors.white, fontSize: 18),
//                 textDirection: TextDirection.rtl,
//               ),
//             ),
//           ),
//         );
//     }
//   }
// }


// lib/router.dart

import 'package:baseer/features/camera/presentation/color_test_page.dart';
import 'package:flutter/material.dart';

class AppRouter {
  AppRouter._();

  static const String colorTest = '/';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case colorTest:
        return MaterialPageRoute(builder: (_) => const ColorTestPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'الصفحة غير موجودة',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
        );
    }
  }
}