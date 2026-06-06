import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/domain/object_size_prior.dart';

void main() {
  group('ObjectSizePrior', () {
    const prior = ObjectSizePrior(
      className: 'car',
      typicalHeightM: 1.50,
      typicalWidthM: 1.80,
      heightStdM: 0.20,
      widthStdM: 0.25,
      heightConfidence: 0.75,
      widthConfidence: 0.70,
    );

    test('stores className correctly', () {
      expect(prior.className, equals('car'));
    });

    test('stores typicalHeightM correctly', () {
      expect(prior.typicalHeightM, equals(1.50));
    });

    test('stores typicalWidthM correctly', () {
      expect(prior.typicalWidthM, equals(1.80));
    });

    test('stores heightStdM correctly', () {
      expect(prior.heightStdM, equals(0.20));
    });

    test('stores widthStdM correctly', () {
      expect(prior.widthStdM, equals(0.25));
    });

    test('stores heightConfidence correctly', () {
      expect(prior.heightConfidence, equals(0.75));
    });

    test('stores widthConfidence correctly', () {
      expect(prior.widthConfidence, equals(0.70));
    });
  });
}
