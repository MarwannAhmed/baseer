import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// ─────────────────────────────────────────────────────────────────────────────
// Public types
// ─────────────────────────────────────────────────────────────────────────────

class ColorResult {
  final String colorEn;
  final String colorAr;
  const ColorResult({required this.colorEn, required this.colorAr});

  @override
  String toString() => '$colorEn / $colorAr';
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

// ── Gray world clamping ───────────────────────────────────────────────────────
// Without clamping, a scene dominated by one colour (e.g. a red wall) causes
// gray world to crush that channel to near-neutral, turning reds into browns
// and greens into yellows.  Limiting scale to [0.75, 1.50] keeps hues intact.
const double _gwClampMin = 0.75;
const double _gwClampMax = 1.50;

// ── Chroma filter (pre K-Means) ───────────────────────────────────────────────
// Pixels whose chroma (distance from a*b* centre) is below this are skipped
// during clustering.  Lowered from 15 → 10 so mildly saturated colours
// (olive greens, dusty pinks, etc.) are not silently discarded before voting.
const double _chromaFilterThreshold = 10.0;

// ── Neutral guard ─────────────────────────────────────────────────────────────
// If the dominant centroid's chroma is below this it is classified as a
// neutral (white / gray / black) rather than forcing a hue match.
// Lowered from 20 → 15 to prevent pale-but-coloured pixels being called gray.
const double _neutralChromaThreshold = 15.0;

const double _whiteLThreshold = 210.0; // OpenCV L > 210 → white
const double _blackLThreshold = 50.0;  // OpenCV L < 50  → black

// ── Spatial sampling ──────────────────────────────────────────────────────────
const double _centerCropRatio = 0.6;
const int    _kmeansK         = 3;
const int    _kmeansMaxIter   = 20;
const int    _pixelStride     = 3;
const int    _minBboxArea     = 400;

// ── Brown rule ────────────────────────────────────────────────────────────────
// Brown = warm hue (red-orange sector) + low chroma + not too bright.
// The warm hue sector covers [0°, _brownHueMax°) in the normalised [0,360)
// angle.  Chroma and L caps prevent vivid oranges / reds from being mislabelled.
//
// How the numbers were derived:
//   Orange prototype [255,140,0]  → hue ≈ 65°, chroma ≈ 84
//   Brown  prototype [100, 60,20] → hue ≈ 65°, chroma ≈ 33, L ≈ 74
//   Dark red         [120,  0, 0] → hue ≈ 37°, chroma ≈ 61
//
// chroma < 45 cleanly separates brown (≈33) from dark-red (≈61) and orange (≈84).
// L < 145 keeps bright sandy/tan colours out of brown.
const double _brownHueMax    = 83.0;  // hue < 83° = warm sector
const double _brownChromaMax = 45.0;  // must be desaturated
const double _brownLMax      = 145.0; // must be darkish (OpenCV L scale 0-255)

// ── Pink vs Red split ─────────────────────────────────────────────────────────
// Both share the same hue zone (~340°–16°).  Pink is the lighter variant.
// OpenCV L > 160 → pink;  ≤ 160 → red.
const double _pinkLMin = 160.0;

// ── Hue-angle boundaries (degrees, [0, 360)) ─────────────────────────────────
// Derived from computed OpenCV LAB positions of representative camera colours
// and placed at the midpoint between adjacent colour anchors.
//
//  Colour  │ prototype RGB     │  hue in LAB
//  ────────┼───────────────────┼─────────────
//  Red     │ [200,  0,  0]     │  ~37°
//  Orange  │ [255,140,  0]     │  ~65°
//  Yellow  │ [230,230,  0]     │ ~103°
//  Green   │ [  0,180,  0]     │ ~135°
//  Blue    │ [  0,  0,200]     │ ~306°
//  Purple  │ [180,  0,180]     │ ~325°
//  Pink    │ [255,130,180]     │ ~355°
//
// Midpoints → boundaries:
//   Pink↔Red    = 16°    Pink↔Purple = 340°
//   Red↔Orange  = 51°    Purple↔Blue = 315°
//   Orange↔Yel  = 84°    Blue↔Green  = 220°  (absorbs cyan)
//   Yel↔Green   = 119°
const double _hPinkRed      = 16.0;
const double _hRedOrange    = 51.0;
const double _hOrangeYellow = 84.0;
const double _hYellowGreen  = 119.0;
const double _hGreenBlue    = 220.0;
const double _hBluePurple   = 315.0;
const double _hPurplePink   = 340.0;

// ── Arabic labels ─────────────────────────────────────────────────────────────
const Map<String, String> _colorArabic = {
  'red':    'أحمر',
  'green':  'أخضر',
  'blue':   'أزرق',
  'yellow': 'أصفر',
  'orange': 'برتقالي',
  'brown':  'بني',
  'purple': 'بنفسجي',
  'pink':   'وردي',
  'white':  'أبيض',
  'gray':   'رمادي',
  'black':  'أسود',
};

// ─────────────────────────────────────────────────────────────────────────────
// sRGB → OpenCV LAB  (matches cv2.COLOR_BGR2LAB exactly)
//   L_cv = L* × 255/100   → [0, 255]
//   A_cv = a* + 128        → [0, 255], centre = 128
//   B_cv = b* + 128        → [0, 255], centre = 128
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// _FrameData — payload for the background isolate
// ─────────────────────────────────────────────────────────────────────────────

class _FrameData {
  final Uint8List rgbaBytes;
  final int width;
  final int height;

  const _FrameData({
    required this.rgbaBytes,
    required this.width,
    required this.height,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _buildLabFrame — runs in a background isolate via compute()
// ─────────────────────────────────────────────────────────────────────────────

Float32List _buildLabFrame(_FrameData data) {
  final int w     = data.width;
  final int h     = data.height;
  final int total = w * h;
  final Uint8List src = data.rgbaBytes;

  // ── 1. Gray World: per-channel averages ──────────────────────────────────
  double rSum = 0, gSum = 0, bSum = 0;
  for (int i = 0; i < total; i++) {
    final int base = i * 4;
    rSum += src[base    ];
    gSum += src[base + 1];
    bSum += src[base + 2];
  }

  const double eps    = 1e-6;
  final double grayAvg = (rSum + gSum + bSum) / (3.0 * total);

  // FIX: clamp scale factors to [_gwClampMin, _gwClampMax].
  // Without clamping, pointing the camera at a single dominant colour causes
  // gray world to massively shift hues (e.g. red scene → reds desaturate to
  // brown; green scene → greens become yellow).
  final double rScale = (grayAvg / (rSum / total + eps)).clamp(_gwClampMin, _gwClampMax);
  final double gScale = (grayAvg / (gSum / total + eps)).clamp(_gwClampMin, _gwClampMax);
  final double bScale = (grayAvg / (bSum / total + eps)).clamp(_gwClampMin, _gwClampMax);

  // ── 2. Normalise + convert to OpenCV LAB ─────────────────────────────────
  final Float32List lab = Float32List(total * 3);
  for (int i = 0; i < total; i++) {
    final int srcBase = i * 4;
    final int dstBase = i * 3;

    final int r = (src[srcBase    ] * rScale).clamp(0, 255).round();
    final int g = (src[srcBase + 1] * gScale).clamp(0, 255).round();
    final int b = (src[srcBase + 2] * bScale).clamp(0, 255).round();

    _rgbToOpenCvLabInto(r, g, b, lab, dstBase);
  }

  return lab;
}

// ─────────────────────────────────────────────────────────────────────────────
// ColorDetector
// ─────────────────────────────────────────────────────────────────────────────

class ColorDetector {
  Float32List? _labFrame;
  int _frameWidth  = 0;
  int _frameHeight = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> setFrame(img.Image frame) async {
    _frameWidth  = frame.width;
    _frameHeight = frame.height;

    final Uint8List rgba = frame.getBytes(order: img.ChannelOrder.rgba);
    _labFrame = await compute(
      _buildLabFrame,
      _FrameData(rgbaBytes: rgba, width: frame.width, height: frame.height),
    );
  }

  ColorResult detect(int x1, int y1, int x2, int y2) {
    if (_labFrame == null) throw StateError('Call setFrame() first.');

    x1 = x1.clamp(0, _frameWidth);
    x2 = x2.clamp(0, _frameWidth);
    y1 = y1.clamp(0, _frameHeight);
    y2 = y2.clamp(0, _frameHeight);

    if (x2 <= x1 || y2 <= y1) return _fallback();
    if ((x2 - x1) * (y2 - y1) < _minBboxArea) return _fallback();

    // ── Center crop ──────────────────────────────────────────────────────────
    final int bw = x2 - x1, bh = y2 - y1;
    final int dx = (bw * (1.0 - _centerCropRatio) / 2.0).round();
    final int dy = (bh * (1.0 - _centerCropRatio) / 2.0).round();
    final int cx1 = (dx > 0 && x1+dx < x2-dx) ? x1+dx : x1;
    final int cx2 = (dx > 0 && x1+dx < x2-dx) ? x2-dx : x2;
    final int cy1 = (dy > 0 && y1+dy < y2-dy) ? y1+dy : y1;
    final int cy2 = (dy > 0 && y1+dy < y2-dy) ? y2-dy : y2;

    // ── Sample pixels ─────────────────────────────────────────────────────────
    final int croppedW = cx2 - cx1;
    final int croppedH = cy2 - cy1;
    final int sampledCount =
        ((croppedW + _pixelStride - 1) ~/ _pixelStride) *
        ((croppedH + _pixelStride - 1) ~/ _pixelStride);

    final Float32List buf = Float32List(sampledCount * 3);
    int count = 0;

    for (int py = cy1; py < cy2; py += _pixelStride) {
      for (int px = cx1; px < cx2; px += _pixelStride) {
        final int src = (py * _frameWidth + px) * 3;
        final int dst = count * 3;
        buf[dst    ] = _labFrame![src    ];
        buf[dst + 1] = _labFrame![src + 1];
        buf[dst + 2] = _labFrame![src + 2];
        count++;
      }
    }

    if (count == 0) return _fallback();

    // ── Filter low-chroma pixels, then K-Means ────────────────────────────────
    final Float32List pixels  = Float32List.sublistView(buf, 0, count * 3);
    Float32List       filtered = _filterLowChroma(pixels, count);
    if (filtered.length ~/ 3 < 10) filtered = pixels;

    final Float32List dominant = _dominantLabColor(filtered, filtered.length ~/ 3);
    return _labToColorName(dominant[0], dominant[1], dominant[2]);
  }

  Future<List<Map<String, dynamic>>> detectColorsForObjects(
    img.Image frame,
    List<Map<String, dynamic>> objects,
  ) async {
    await setFrame(frame);
    return objects.map((obj) {
      final bbox   = obj['bbox'] as Map<String, dynamic>;
      final result = detect(
        (bbox['x1'] as num).toInt(),
        (bbox['y1'] as num).toInt(),
        (bbox['x2'] as num).toInt(),
        (bbox['y2'] as num).toInt(),
      );
      return {...obj, 'color_en': result.colorEn, 'color_ar': result.colorAr};
    }).toList();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  ColorResult _fallback() =>
      const ColorResult(colorEn: 'gray', colorAr: 'رمادي');

  Float32List _filterLowChroma(Float32List pixels, int count) {
    int kept = 0;
    for (int i = 0; i < count; i++) {
      final double da = pixels[i*3+1] - 128.0;
      final double db = pixels[i*3+2] - 128.0;
      if (da*da + db*db >= _chromaFilterThreshold * _chromaFilterThreshold) kept++;
    }
    if (kept == 0) return pixels;

    final Float32List out = Float32List(kept * 3);
    int j = 0;
    for (int i = 0; i < count; i++) {
      final double da = pixels[i*3+1] - 128.0;
      final double db = pixels[i*3+2] - 128.0;
      if (da*da + db*db >= _chromaFilterThreshold * _chromaFilterThreshold) {
        out[j*3    ] = pixels[i*3    ];
        out[j*3 + 1] = pixels[i*3 + 1];
        out[j*3 + 2] = pixels[i*3 + 2];
        j++;
      }
    }
    return out;
  }

  Float32List _dominantLabColor(Float32List pixels, int count) {
    if (count < _kmeansK * 2) return _meanColor(pixels, count);

    final Random rng = Random(0);
    final List<Float32List> centroids = [];

    centroids.add(_pixelAt(pixels, rng.nextInt(count)));

    for (int k = 1; k < _kmeansK; k++) {
      final Float32List dists = Float32List(count);
      double total = 0;
      for (int i = 0; i < count; i++) {
        double minDist = double.infinity;
        for (final c in centroids) {
          final double d = _distSq(pixels, i, c);
          if (d < minDist) minDist = d;
        }
        dists[i] = minDist;
        total   += minDist;
      }
      double threshold = rng.nextDouble() * total;
      int chosen = count - 1;
      for (int i = 0; i < count; i++) {
        threshold -= dists[i];
        if (threshold <= 0) { chosen = i; break; }
      }
      centroids.add(_pixelAt(pixels, chosen));
    }

    final List<int>    labels = List.filled(count, 0);
    final List<double> lSum   = List.filled(_kmeansK, 0);
    final List<double> aSum   = List.filled(_kmeansK, 0);
    final List<double> bSum   = List.filled(_kmeansK, 0);
    final List<int>    cnt    = List.filled(_kmeansK, 0);

    for (int iter = 0; iter < _kmeansMaxIter; iter++) {
      bool changed = false;
      for (int i = 0; i < count; i++) {
        int best = 0; double bestD = double.infinity;
        for (int k = 0; k < _kmeansK; k++) {
          final double d = _distSq(pixels, i, centroids[k]);
          if (d < bestD) { bestD = d; best = k; }
        }
        if (labels[i] != best) { labels[i] = best; changed = true; }
      }
      if (!changed) break;

      for (int k = 0; k < _kmeansK; k++) { lSum[k]=0; aSum[k]=0; bSum[k]=0; cnt[k]=0; }
      for (int i = 0; i < count; i++) {
        final int k = labels[i];
        lSum[k] += pixels[i*3    ];
        aSum[k] += pixels[i*3 + 1];
        bSum[k] += pixels[i*3 + 2];
        cnt[k]++;
      }
      for (int k = 0; k < _kmeansK; k++) {
        if (cnt[k] > 0) {
          centroids[k][0] = lSum[k] / cnt[k];
          centroids[k][1] = aSum[k] / cnt[k];
          centroids[k][2] = bSum[k] / cnt[k];
        }
      }
    }

    final List<int> sizes = List.filled(_kmeansK, 0);
    for (final l in labels) sizes[l]++;
    int best = 0;
    for (int k = 1; k < _kmeansK; k++) {
      if (sizes[k] > sizes[best]) best = k;
    }
    return centroids[best];
  }

  Float32List _meanColor(Float32List pixels, int count) {
    double l = 0, a = 0, b = 0;
    for (int i = 0; i < count; i++) {
      l += pixels[i*3]; a += pixels[i*3+1]; b += pixels[i*3+2];
    }
    return Float32List.fromList([l/count, a/count, b/count]);
  }

  Float32List _pixelAt(Float32List pixels, int i) =>
      Float32List.fromList([pixels[i*3], pixels[i*3+1], pixels[i*3+2]]);

  double _distSq(Float32List pixels, int i, Float32List centroid) {
    final double dl = pixels[i*3    ] - centroid[0];
    final double da = pixels[i*3 + 1] - centroid[1];
    final double db = pixels[i*3 + 2] - centroid[2];
    return dl*dl + da*da + db*db;
  }

  // ── Colour naming ──────────────────────────────────────────────────────────
  //
  // FIX: replaced prototype Euclidean distance (which included the L channel
  // and caused dark reds to match brown, and all warm low-saturation colours
  // to cluster toward the central brown prototype) with:
  //
  //   1. Neutral guard    — chroma threshold (unchanged logic, lower value)
  //   2. Brown rule       — warm hue + low chroma + moderate L
  //                         Keeps brown OUT of the hue-bucket competition so
  //                         vivid reds/oranges are never pulled toward it.
  //   3. Hue bucketing    — atan2(b*, a*) angle divided at computed midpoints
  //                         between anchor colours; no L contamination.
  //   4. Pink / Red split — same hue zone, split by lightness (L threshold).

  ColorResult _labToColorName(double L, double rawA, double rawB) {
    final double A      = rawA - 128.0;
    final double B      = rawB - 128.0;
    final double chroma = sqrt(A * A + B * B);

    // ── 1. Neutral guard ──────────────────────────────────────────────────────
    if (chroma < _neutralChromaThreshold) {
      if (L > _whiteLThreshold) return const ColorResult(colorEn: 'white', colorAr: 'أبيض');
      if (L < _blackLThreshold) return const ColorResult(colorEn: 'black', colorAr: 'أسود');
      return const ColorResult(colorEn: 'gray',  colorAr: 'رمادي');
    }

    // ── 2. Hue angle in [0, 360) ──────────────────────────────────────────────
    double h = atan2(B, A) * 180.0 / pi;
    if (h < 0) h += 360.0;

    // ── 3. Brown rule ─────────────────────────────────────────────────────────
    // Brown lives in the warm sector (red/orange hue) but is desaturated and
    // darker than orange.  Checking this first removes it from the hue buckets
    // so a dark desaturated red is never incorrectly called "red" or "orange".
    if (h < _brownHueMax && chroma < _brownChromaMax && L < _brownLMax) {
      return const ColorResult(colorEn: 'brown', colorAr: 'بني');
    }

    // ── 4. Hue bucketing ──────────────────────────────────────────────────────
    final String name;

    if (h >= _hPurplePink) {
      // [340°, 360°) — pink / red zone
      name = L >= _pinkLMin ? 'pink' : 'red';
    } else if (h < _hPinkRed) {
      // [0°, 16°) — pink / red zone (wraps through 0°)
      name = L >= _pinkLMin ? 'pink' : 'red';
    } else if (h < _hRedOrange) {
      // [16°, 51°)
      name = 'red';
    } else if (h < _hOrangeYellow) {
      // [51°, 84°)
      name = 'orange';
    } else if (h < _hYellowGreen) {
      // [84°, 119°)
      name = 'yellow';
    } else if (h < _hGreenBlue) {
      // [119°, 220°) — includes cyan, mapped to green
      name = 'green';
    } else if (h < _hBluePurple) {
      // [220°, 315°)
      name = 'blue';
    } else {
      // [315°, 340°)
      name = 'purple';
    }

    return ColorResult(
      colorEn: name,
      colorAr: _colorArabic[name] ?? name,
    );
  }
}