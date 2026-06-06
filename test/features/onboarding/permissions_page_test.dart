import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/onboarding/presentation/permissions_page.dart';
import '../../helpers/platform_channel_stubs.dart';

Widget buildPermissionsApp() => MaterialApp(
      home: const PermissionsPage(),
      routes: {'/camera': (_) => const Scaffold(body: Text('camera'))},
    );

void main() {
  setUp(setupPlatformChannelStubs);

  group('PermissionsPage', () {
    testWidgets('builds without throwing', (tester) async {
      await tester.pumpWidget(buildPermissionsApp());
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders permission labels', (tester) async {
      await tester.pumpWidget(buildPermissionsApp());
      await tester.pump();
      // Locale is 'ar' by default so Arabic labels are shown
      expect(find.textContaining('كاميرا'), findsAtLeast(1));
      expect(find.textContaining('ميكروفون'), findsAtLeast(1));
    });

    testWidgets('shows allow-and-continue button text', (tester) async {
      await tester.pumpWidget(buildPermissionsApp());
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            (w.data?.contains('السماح') == true ||
                w.data?.contains('Allow') == true)),
        findsAtLeast(1),
      );
    });
  });
}
