import 'package:flutter_test/flutter_test.dart';

import 'package:baseer/app/baseer_app.dart';

void main() {
  test('App bootstrap can be instantiated', () {
    const app = BaseerApp();
    expect(app, isNotNull);
  });
}
