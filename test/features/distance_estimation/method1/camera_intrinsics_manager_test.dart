import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:baseer/features/distance_estimation/application/method1/camera_intrinsics_manager.dart';

void main() {
  group('CameraIntrinsicsManager', () {
    late CameraIntrinsicsManager mgr;

    setUp(() {
      mgr = CameraIntrinsicsManager(width: 1280, height: 720);
    });

    group('static converters', () {
      test('d2r(180.0) equals pi', () {
        expect(CameraIntrinsicsManager.d2r(180.0), closeTo(math.pi, 1e-10));
      });

      test('r2d(pi) equals 180.0', () {
        expect(CameraIntrinsicsManager.r2d(math.pi), closeTo(180.0, 1e-10));
      });

      test('d2r and r2d are inverses', () {
        expect(CameraIntrinsicsManager.r2d(CameraIntrinsicsManager.d2r(45.0)),
            closeTo(45.0, 1e-10));
      });
    });

    group('fPx', () {
      test('correct for width=1280 fovH=69 degrees', () {
        final expected = 640.0 / math.tan(CameraIntrinsicsManager.d2r(69.0 / 2));
        expect(mgr.fPx, closeTo(expected, 1.0));
      });

      test('fovH is 69 degrees by default', () {
        expect(mgr.fovH, equals(69.0));
      });
    });

    group('fPy', () {
      test('without calibration uses aspect-ratio-derived FOV', () {
        expect(mgr.fPy, isPositive);
      });

      test('returns calibratedFocalL when calibrated and positive', () {
        mgr.calibrateFocalL(800.0);
        expect(mgr.fPy, closeTo(800.0, 0.001));
      });
    });

    group('updateImageSize()', () {
      test('updates width and height fields', () {
        mgr.updateImageSize(640, 480);
        expect(mgr.width, equals(640));
        expect(mgr.height, equals(480));
      });

      test('fPx changes after size update', () {
        final fpxBefore = mgr.fPx;
        mgr.updateImageSize(640, 480);
        expect(mgr.fPx, isNot(closeTo(fpxBefore, 1.0)));
      });
    });

    group('calibrateFocalL()', () {
      test('first call sets calibratedFocalL to given value', () {
        mgr.calibrateFocalL(500.0);
        expect(mgr.calibratedFocalL, equals(500.0));
      });

      test('second call applies EMA with alpha=0.05', () {
        mgr.calibrateFocalL(500.0);
        mgr.calibrateFocalL(600.0);
        final expected = 0.05 * 600.0 + 0.95 * 500.0;
        expect(mgr.calibratedFocalL, closeTo(expected, 0.001));
      });

      test('non-positive value is rejected', () {
        mgr.calibrateFocalL(500.0);
        mgr.calibrateFocalL(0.0);
        expect(mgr.calibratedFocalL, equals(500.0)); // unchanged
      });

      test('negative value is rejected', () {
        mgr.calibrateFocalL(500.0);
        mgr.calibrateFocalL(-100.0);
        expect(mgr.calibratedFocalL, equals(500.0));
      });

      test('custom alpha is applied', () {
        mgr.calibrateFocalL(500.0);
        mgr.calibrateFocalL(600.0, alpha: 0.1);
        final expected = 0.1 * 600.0 + 0.9 * 500.0;
        expect(mgr.calibratedFocalL, closeTo(expected, 0.001));
      });
    });
  });
}
