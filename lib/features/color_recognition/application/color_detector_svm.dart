import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

class SvmColorResult {
  final String colorEn;
  final String colorAr;
  const SvmColorResult({required this.colorEn, required this.colorAr});
  @override
  String toString() => '$colorEn / $colorAr';
}

// ── Constants — exact sync with color_detector.dart ──────────────────────────

const double _chromaFilterThreshold  = 10.0;
const double _neutralChromaThreshold = 15.0;
const double _whiteLThreshold        = 210.0;
const double _blackLThreshold        = 50.0;
const double _centerCropRatio        = 0.6;
const int    _kmeansK                = 3;
const int    _kmeansMaxIter          = 20;
const int    _pixelStride            = 3;
const int    _minBboxArea            = 400;

const Map<String, String> _colorArabic = {
  'red':    '\u0623\u062d\u0645\u0631',
  'green':  '\u0623\u062e\u0636\u0631',
  'blue':   '\u0623\u0632\u0631\u0642',
  'yellow': '\u0623\u0635\u0641\u0631',
  'orange': '\u0628\u0631\u062a\u0642\u0627\u0644\u064a',
  'brown':  '\u0628\u0646\u064a',
  'purple': '\u0628\u0646\u0641\u0633\u062c\u064a',
  'pink':   '\u0648\u0631\u062f\u064a',
  'white':  '\u0623\u0628\u064a\u0636',
  'gray':   '\u0631\u0645\u0627\u062f\u064a',
  'black':  '\u0623\u0633\u0648\u062f',
};

// ── sRGB → OpenCV LAB ────────────────────────────────────────────────────────

double _gammaExpand(double c) =>
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
double _labF(double t) =>
    t > 0.008856 ? pow(t, 1.0 / 3.0).toDouble() : (7.787 * t + 16.0 / 116.0);

void _rgbToOpenCvLabInto(int r, int g, int b, Float32List out, int offset) {
  final double rf = _gammaExpand(r / 255.0);
  final double gf = _gammaExpand(g / 255.0);
  final double bf = _gammaExpand(b / 255.0);
  final double x = rf * 0.4124564 + gf * 0.3575761 + bf * 0.1804375;
  final double y = rf * 0.2126729 + gf * 0.7151522 + bf * 0.0721750;
  final double z = rf * 0.0193339 + gf * 0.1191920 + bf * 0.9503041;
  final double fx = _labF(x / 0.95047);
  final double fy = _labF(y / 1.00000);
  final double fz = _labF(z / 1.08883);
  out[offset    ] = ((116.0 * fy - 16.0) * 255.0 / 100.0).clamp(0.0, 255.0);
  out[offset + 1] = (500.0 * (fx - fy) + 128.0).clamp(0.0, 255.0);
  out[offset + 2] = (200.0 * (fy - fz) + 128.0).clamp(0.0, 255.0);
}

// ── Isolate payload ───────────────────────────────────────────────────────────

class _SvmFrameData {
  final Uint8List rgbaBytes;
  final int width;
  final int height;
  const _SvmFrameData({required this.rgbaBytes, required this.width, required this.height});
}

/// Raw LAB conversion — no AWB. Matches train_and_eval.py extract_dominant_lab().
/// AWB is skipped because applying it to a single-color crop pushes the
/// dominant hue toward gray, destroying the color signal.
Float32List _buildSvmLabFrame(_SvmFrameData data) {
  final int total = data.width * data.height;
  final Uint8List src = data.rgbaBytes;
  final Float32List lab = Float32List(total * 3);
  for (int i = 0; i < total; i++) {
    final int s = i * 4, d = i * 3;
    _rgbToOpenCvLabInto(src[s], src[s + 1], src[s + 2], lab, d);
  }
  return lab;
}

// ── SvmColorClassifier ────────────────────────────────────────────────────────

class SvmColorClassifier {
  SvmColorClassifier._();
  static SvmColorClassifier? _instance;
  static SvmColorClassifier get instance => _instance ??= SvmColorClassifier._();

  OrtSession?   _session;
  List<String>? _labels;
  bool          _initialising = false;

  Future<void> init() async {
    debugPrint('[SvmColorClassifier] init() called');  // ← add here
    if (_session != null || _initialising) return;
    _initialising = true;
    try {
      OrtEnv.instance.init();
      final ByteData modelData = await rootBundle.load('assets/ml/color_svm.onnx');
      _session = OrtSession.fromBuffer(modelData.buffer.asUint8List(), OrtSessionOptions());
      final String labelsJson = await rootBundle.loadString('assets/ml/color_labels.json');
      _labels = List<String>.from(jsonDecode(labelsJson) as List<dynamic>);
      debugPrint('[SvmColorClassifier] Ready — ${_labels!.length} classes: ${_labels!.join(", ")}');
    } catch (e) {
      debugPrint('[SvmColorClassifier] Init failed: $e');
    } finally {
      _initialising = false;
    }
  }

  bool get isReady => _session != null && _labels != null;

  /// Feature vector [L, rawA, rawB, chroma, hue] matches train_and_eval.py make_feature().
  /// rawA / rawB are OpenCV-scale (0-255, centred at 128), NOT shifted.
  String? classify(double L, double rawA, double rawB) {
    if (!isReady) return null;
    final double A      = rawA - 128.0;
    final double B      = rawB - 128.0;
    final double chroma = sqrt(A * A + B * B);
    final double hue    = atan2(B, A);
    final Float32List feat = Float32List.fromList([L, rawA, rawB, chroma, hue]);
    final OrtValueTensor input = OrtValueTensor.createTensorWithDataList(feat, [1, 5]);
    try {
      final runOptions = OrtRunOptions();
      final List<OrtValue?> outputs = _session!.run(runOptions, {_session!.inputNames.first: input});

      // Parse a variety of possible output shapes coming from the native runtime.
      int idx = 0;
      try {
        final dynamic v0 = outputs[0]!.value;
        if (v0 is List) {
          if (v0.isEmpty) throw Exception('empty output');
          final first = v0[0];
          if (first is List) {
            final inner = first[0];
            if (inner is num) idx = inner.toInt(); else idx = int.parse(inner.toString());
          } else if (first is num) {
            idx = first.toInt();
          } else {
            idx = int.parse(first.toString());
          }
        } else if (v0 is num) {
          idx = v0.toInt();
        } else {
          idx = int.parse(v0.toString());
        }
      } catch (e) {
        debugPrint('[SvmColorClassifier] Parse output error: $e');
        idx = 0;
      }

      for (final o in outputs) { o?.release(); }
      runOptions.release();
      return _labels![idx.clamp(0, _labels!.length - 1)];
    } catch (e) {
      debugPrint('[SvmColorClassifier] Inference error: $e');
      return null;
    } finally {
      input.release();
    }
  }

  void dispose() {
    _session?.release();
    _session = null; _labels = null; _instance = null;
  }
}

// ── ColorDetectorSvm ──────────────────────────────────────────────────────────
//
// Identical public API to ColorDetector.
// detect() returns SvmColorResult (has .colorEn / .colorAr).

class ColorDetectorSvm {
  Float32List? _labFrame;
  int _frameWidth  = 0;
  int _frameHeight = 0;

  Future<void> setFrame(img.Image frame) async {
    await SvmColorClassifier.instance.init();
    _frameWidth  = frame.width;
    _frameHeight = frame.height;
    _labFrame = await compute(
      _buildSvmLabFrame,
      _SvmFrameData(
        rgbaBytes: frame.getBytes(order: img.ChannelOrder.rgba),
        width: frame.width, height: frame.height,
      ),
    );
  }

  SvmColorResult detect(int x1, int y1, int x2, int y2) {
    if (_labFrame == null) throw StateError('Call setFrame() first.');
    x1 = x1.clamp(0, _frameWidth);  x2 = x2.clamp(0, _frameWidth);
    y1 = y1.clamp(0, _frameHeight); y2 = y2.clamp(0, _frameHeight);
    if (x2 <= x1 || y2 <= y1) return _fallback();
    if ((x2 - x1) * (y2 - y1) < _minBboxArea) return _fallback();

    final int bw = x2 - x1, bh = y2 - y1;
    final int dx = (bw * (1.0 - _centerCropRatio) / 2.0).round();
    final int dy = (bh * (1.0 - _centerCropRatio) / 2.0).round();
    final int cx1 = (dx > 0 && x1+dx < x2-dx) ? x1+dx : x1;
    final int cx2 = (dx > 0 && x1+dx < x2-dx) ? x2-dx : x2;
    final int cy1 = (dy > 0 && y1+dy < y2-dy) ? y1+dy : y1;
    final int cy2 = (dy > 0 && y1+dy < y2-dy) ? y2-dy : y2;

    final int sCount =
        ((cx2-cx1+_pixelStride-1) ~/ _pixelStride) *
        ((cy2-cy1+_pixelStride-1) ~/ _pixelStride);
    final Float32List buf = Float32List(sCount * 3);
    int count = 0;
    for (int py = cy1; py < cy2; py += _pixelStride) {
      for (int px = cx1; px < cx2; px += _pixelStride) {
        final int s = (py * _frameWidth + px) * 3;
        buf[count*3    ] = _labFrame![s    ];
        buf[count*3 + 1] = _labFrame![s + 1];
        buf[count*3 + 2] = _labFrame![s + 2];
        count++;
      }
    }
    if (count == 0) return _fallback();

    final Float32List pixels  = Float32List.sublistView(buf, 0, count * 3);
    Float32List       filtered = _filterLowChroma(pixels, count);
    if (filtered.length ~/ 3 < 10) filtered = pixels;

    final Float32List dom = _dominantLabColor(filtered, filtered.length ~/ 3);
    return _classify(dom[0], dom[1], dom[2]);
  }

  Future<List<Map<String, dynamic>>> detectColorsForObjects(
    img.Image frame, List<Map<String, dynamic>> objects,
  ) async {
    await setFrame(frame);
    return objects.map((obj) {
      final bbox = obj['bbox'] as Map<String, dynamic>;
      final r = detect(
        (bbox['x1'] as num).toInt(), (bbox['y1'] as num).toInt(),
        (bbox['x2'] as num).toInt(), (bbox['y2'] as num).toInt(),
      );
      return {...obj, 'color_en': r.colorEn, 'color_ar': r.colorAr};
    }).toList();
  }

  SvmColorResult _classify(double L, double rawA, double rawB) {
    debugPrint('[SVM] isReady=${SvmColorClassifier.instance.isReady}');
    final double A      = rawA - 128.0;
    final double B      = rawB - 128.0;
    final double chroma = sqrt(A * A + B * B);
    debugPrint('[SVM] L=$L A=$rawA B=$rawB chroma=$chroma');  // ADD THIS

    // Neutral guard — same thresholds as color_detector.dart
    if (chroma < _neutralChromaThreshold) {
      if (L > _whiteLThreshold) return const SvmColorResult(colorEn: 'white', colorAr: '\u0623\u0628\u064a\u0636');
      if (L < _blackLThreshold) return const SvmColorResult(colorEn: 'black', colorAr: '\u0623\u0633\u0648\u062f');
      return const SvmColorResult(colorEn: 'gray',  colorAr: '\u0631\u0645\u0627\u062f\u064a');
    }

    final String? label = SvmColorClassifier.instance.classify(L, rawA, rawB);
    if (label != null) {
      return SvmColorResult(colorEn: label, colorAr: _colorArabic[label] ?? label);
    }
    return _fallback();
  }

  SvmColorResult _fallback() =>
      const SvmColorResult(colorEn: 'gray', colorAr: '\u0631\u0645\u0627\u062f\u064a');

  Float32List _filterLowChroma(Float32List pixels, int count) {
    int kept = 0;
    for (int i = 0; i < count; i++) {
      final double da = pixels[i*3+1] - 128.0, db = pixels[i*3+2] - 128.0;
      if (da*da + db*db >= _chromaFilterThreshold * _chromaFilterThreshold) kept++;
    }
    if (kept == 0) return pixels;
    final Float32List out = Float32List(kept * 3);
    int j = 0;
    for (int i = 0; i < count; i++) {
      final double da = pixels[i*3+1] - 128.0, db = pixels[i*3+2] - 128.0;
      if (da*da + db*db >= _chromaFilterThreshold * _chromaFilterThreshold) {
        out[j*3] = pixels[i*3]; out[j*3+1] = pixels[i*3+1]; out[j*3+2] = pixels[i*3+2]; j++;
      }
    }
    return out;
  }

  Float32List _dominantLabColor(Float32List pixels, int count) {
    if (count < _kmeansK * 2) return _meanColor(pixels, count);
    final Random rng = Random(0);
    final List<Float32List> centroids = [_pixelAt(pixels, rng.nextInt(count))];
    for (int k = 1; k < _kmeansK; k++) {
      final Float32List dists = Float32List(count);
      double total = 0;
      for (int i = 0; i < count; i++) {
        double minDist = double.infinity;
        for (final c in centroids) { final d = _distSq(pixels, i, c); if (d < minDist) minDist = d; }
        dists[i] = minDist; total += minDist;
      }
      double thr = rng.nextDouble() * total;
      int chosen = count - 1;
      for (int i = 0; i < count; i++) { thr -= dists[i]; if (thr <= 0) { chosen = i; break; } }
      centroids.add(_pixelAt(pixels, chosen));
    }
    final List<int>    labels = List.filled(count, 0);
    final List<double> lS = List.filled(_kmeansK, 0), aS = List.filled(_kmeansK, 0), bS = List.filled(_kmeansK, 0);
    final List<int>    cnt = List.filled(_kmeansK, 0);
    for (int iter = 0; iter < _kmeansMaxIter; iter++) {
      bool changed = false;
      for (int i = 0; i < count; i++) {
        int best = 0; double bestD = double.infinity;
        for (int k = 0; k < _kmeansK; k++) { final d = _distSq(pixels, i, centroids[k]); if (d < bestD) { bestD = d; best = k; } }
        if (labels[i] != best) { labels[i] = best; changed = true; }
      }
      if (!changed) break;
      for (int k = 0; k < _kmeansK; k++) { lS[k]=0; aS[k]=0; bS[k]=0; cnt[k]=0; }
      for (int i = 0; i < count; i++) {
        final int k = labels[i];
        lS[k] += pixels[i*3]; aS[k] += pixels[i*3+1]; bS[k] += pixels[i*3+2]; cnt[k]++;
      }
      for (int k = 0; k < _kmeansK; k++) {
        if (cnt[k] > 0) { centroids[k][0]=lS[k]/cnt[k]; centroids[k][1]=aS[k]/cnt[k]; centroids[k][2]=bS[k]/cnt[k]; }
      }
    }
    final List<int> sizes = List.filled(_kmeansK, 0);
    for (final l in labels) sizes[l]++;
    int best = 0;
    for (int k = 1; k < _kmeansK; k++) { if (sizes[k] > sizes[best]) best = k; }
    return centroids[best];
  }

  Float32List _meanColor(Float32List pixels, int count) {
    double l = 0, a = 0, b = 0;
    for (int i = 0; i < count; i++) { l += pixels[i*3]; a += pixels[i*3+1]; b += pixels[i*3+2]; }
    return Float32List.fromList([l/count, a/count, b/count]);
  }

  Float32List _pixelAt(Float32List pixels, int i) =>
      Float32List.fromList([pixels[i*3], pixels[i*3+1], pixels[i*3+2]]);

  double _distSq(Float32List pixels, int i, Float32List c) {
    final double dl = pixels[i*3]-c[0], da = pixels[i*3+1]-c[1], db = pixels[i*3+2]-c[2];
    return dl*dl + da*da + db*db;
  }
}