import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/app/router.dart';
import 'package:baseer/features/onboarding/presentation/permissions_page.dart';
import '../helpers/platform_channel_stubs.dart';

void main() {
  setUp(setupPlatformChannelStubs);

  group('AppRouter.generateRoute', () {
    test('/ returns a MaterialPageRoute', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: '/'));
      expect(route, isA<MaterialPageRoute>());
    });

    test('/camera returns a MaterialPageRoute', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: '/camera'));
      expect(route, isA<MaterialPageRoute>());
    });

    testWidgets('/permissions yields PermissionsPage', (tester) async {
      final route = AppRouter.generateRoute(
        const RouteSettings(name: '/permissions'),
      );
      expect(route, isA<MaterialPageRoute>());
      final matRoute = route as MaterialPageRoute;
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: matRoute.builder)),
      );
      expect(find.byType(PermissionsPage), findsOneWidget);
    });

    testWidgets('unknown route shows Arabic not-found text', (tester) async {
      final route = AppRouter.generateRoute(
        const RouteSettings(name: '/nonexistent'),
      );
      expect(route, isA<MaterialPageRoute>());
      final matRoute = route as MaterialPageRoute;
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: matRoute.builder)),
      );
      expect(find.textContaining('الصفحة غير موجودة'), findsOneWidget);
    });
  });
}
