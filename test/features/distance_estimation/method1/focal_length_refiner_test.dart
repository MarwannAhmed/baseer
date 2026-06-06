import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/application/method1/focal_length_refiner.dart';
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';
import '../../../helpers/test_fixtures.dart';

void main() {
  group('FocalLengthRefiner', () {
    late FocalLengthRefiner refiner;
    late CameraIntrinsicsManager intrinsics;
    final prior = makeObjectSizePrior(
      typicalHeightM: 1.70,
      heightConfidence: 0.85,
    );

    setUp(() {
      refiner = FocalLengthRefiner(bufferSize: 4); // smaller buffer for tests
      intrinsics = CameraIntrinsicsManager(width: 1280, height: 720);
    });

    group('consider() skip conditions', () {
      test('skips when isClipped is true', () {
        refiner.consider(
          detectionConfidence: 0.95,
          prior: prior,
          dist: 3.0,
          height: 200,
          isClipped: true,
          intrinsics: intrinsics,
        );
        expect(intrinsics.calibratedFocalL, isNull);
      });

      test('skips when detectionConfidence <= 0.85', () {
        refiner.consider(
          detectionConfidence: 0.85,
          prior: prior,
          dist: 3.0,
          height: 200,
          isClipped: false,
          intrinsics: intrinsics,
        );
        expect(intrinsics.calibratedFocalL, isNull);
      });

      test('skips when prior.heightConfidence <= 0.80', () {
        final lowConfPrior = makeObjectSizePrior(
          typicalHeightM: 1.70,
          heightConfidence: 0.80,
        );
        refiner.consider(
          detectionConfidence: 0.95,
          prior: lowConfPrior,
          dist: 3.0,
          height: 200,
          isClipped: false,
          intrinsics: intrinsics,
        );
        expect(intrinsics.calibratedFocalL, isNull);
      });

      test('skips when height <= 0', () {
        refiner.consider(
          detectionConfidence: 0.95,
          prior: prior,
          dist: 3.0,
          height: 0,
          isClipped: false,
          intrinsics: intrinsics,
        );
        expect(intrinsics.calibratedFocalL, isNull);
      });
    });

    group('buffer behaviour', () {
      void addValid({double dist = 3.0, double height = 200}) {
        refiner.consider(
          detectionConfidence: 0.95,
          prior: prior,
          dist: dist,
          height: height,
          isClipped: false,
          intrinsics: intrinsics,
        );
      }

      test('does not calibrate until bufferSize samples collected', () {
        addValid(); addValid(); addValid(); // 3 of 4
        expect(intrinsics.calibratedFocalL, isNull);
      });

      test('calibrates after exactly bufferSize valid samples', () {
        for (int i = 0; i < 4; i++) { addValid(); }
        expect(intrinsics.calibratedFocalL, isNotNull);
      });

      test('buffer clears after calibration (next sample does not re-trigger)', () {
        for (int i = 0; i < 4; i++) { addValid(); }
        intrinsics.calibratedFocalL = null; // reset to detect if it's set again
        addValid(); // only 1 new sample — should not calibrate yet
        expect(intrinsics.calibratedFocalL, isNull);
      });
    });

    group('calcMedian()', () {
      test('odd-length list returns middle element', () {
        expect(refiner.calcMedian([1.0, 3.0, 5.0]), equals(3.0));
      });

      test('even-length list returns average of two middle elements', () {
        expect(refiner.calcMedian([1.0, 3.0, 5.0, 7.0]), equals(4.0));
      });

      test('single element returns itself', () {
        expect(refiner.calcMedian([42.0]), equals(42.0));
      });

      test('unsorted list is sorted before finding median', () {
        expect(refiner.calcMedian([5.0, 1.0, 3.0]), equals(3.0));
      });
    });
  });
}
