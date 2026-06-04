import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;


class ColorResult {
  final String colorEn;
  final String colorAr;
  const ColorResult({required this.colorEn, required this.colorAr});

  @override
  String toString() => '$colorEn / $colorAr';
}

// gray world: clamp scale factors so a scene dominated by one colour
// doesnt crush that channel -- e.g. red wall turns reds into browns
// tried [0.5, 2.0] once, hues went weird. 0.75-1.50 works
const double _gwClampMin = 0.75;
const double _gwClampMax = 1.50;

// skip low-chroma pixels before clustering. was 15, lowered to 10 so
// mildly saturated colours (olive greens, dusty pinks) arent dropped
const double _chromaFilterThreshold = 10.0;

// if dominant centroid chroma < this, call it neutral (white/gray/black)
// was 20, lowered to 15 -- pale-but-coloured was getting called gray
const double _neutralChromaThreshold = 15.0;

const double _whiteLThreshold = 210.0; //L > 210 = white (opencv scale)
const double _blackLThreshold = 50.0;  //L < 50  = black

// const double _centerCropRatio = 0.6; // unused here, svm side uses it
const int    _kmeansK         = 3;
const int    _kmeansMaxIter   = 20;
const int    _pixelStride     = 3;
const int    _minBboxArea     = 400;

// brown = warm hue sector + low chroma + not too bright
// derived from prototype comparisons:
//   orange [255,140,0]  -> hue ~65, chroma ~84
//   brown  [100,60,20]  -> hue ~65, chroma ~33, L ~74
//   dark red [120,0,0]  -> hue ~37, chroma ~61
// chroma < 45 cleanly separates brown(33) from dark-red(61) and orange(84)
// L < 145 keeps sandy/tan out of brown
const double _brownHueMax    = 83.0;
const double _brownChromaMax = 45.0;
const double _brownLMax      = 145.0; // darkish on opencv 0-255 scale

// pink/red share same hue zone, split by lightness
const double _pinkLMin = 160.0;

// hue angle boundaries in [0, 360), midpoints between adjacent anchors:
//   Red [200,0,0] ~37  Orange [255,140,0] ~65  Yellow [230,230,0] ~103
//   Green [0,180,0] ~135  Blue [0,0,200] ~306  Purple [180,0,180] ~325
//   Pink [255,130,180] ~355
const double _hPinkRed      = 16.0;
const double _hRedOrange    = 51.0;
const double _hOrangeYellow = 84.0;
const double _hYellowGreen  = 119.0;
const double _hGreenBlue    = 220.0; //absorbs cyan too
const double _hBluePurple   = 315.0;
const double _hPurplePink   = 340.0;

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

const ColorResult _grayFallback = ColorResult(colorEn: 'gray', colorAr: 'رمادي');

// sRGB -> OpenCV LAB, matches cv2.COLOR_BGR2LAB exactly
//   L_cv = L* * 255/100  -> [0,255]
//   A_cv = a* + 128      -> [0,255], centre=128
//   B_cv = b* + 128      -> [0,255], centre=128

double _gammaExpand(double c) =>
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

double _labF(double t) =>
    t > 0.008856 ? pow(t, 1.0 / 3.0).toDouble() : (7.787 * t + 16.0 / 116.0);

void _rgbToOpenCvLabInto(int r, int g, int b, Float32List out, int offset) {
  final double rf = _gammaExpand(r / 255.0);
  final double gf = _gammaExpand(g / 255.0);
  final double bf = _gammaExpand(b / 255.0);

  // D65 illuminant
  final double x = rf*0.4124564 + gf*0.3575761 + bf*0.1804375;
  final double y = rf*0.2126729 + gf*0.7151522 + bf*0.0721750;
  final double z = rf*0.0193339 + gf*0.1191920 + bf*0.9503041;

  final double fx = _labF(x / 0.95047);
  final double fy = _labF(y / 1.00000);
  final double fz = _labF(z / 1.08883);

  out[offset    ] = ((116.0*fy - 16.0) * 255.0/100.0).clamp(0.0, 255.0);
  out[offset + 1] = (500.0*(fx - fy) + 128.0).clamp(0.0, 255.0);
  out[offset + 2] = (200.0*(fy - fz) + 128.0).clamp(0.0, 255.0);
}

// isolate payload
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

// runs in background isolate via compute()
Float32List _buildLabFrame(_FrameData data) {
  final int w     = data.width;
  final int h     = data.height;
  final int total = w * h;
  final Uint8List src = data.rgbaBytes;

  // gray world: per-channel sums for AWB
  double rSum = 0, gSum = 0, bSum = 0;
  for (int i = 0; i < total; i++) {
    final int base = i * 4;
    rSum += src[base];
    gSum += src[base + 1];
    bSum += src[base + 2];
  }

  const double eps = 1e-6;
  final double grayAvg = (rSum + gSum + bSum) / (3.0 * total);

  // clamp so dominant-color scenes dont crush the channel
  final double rScale = (grayAvg / (rSum/total + eps)).clamp(_gwClampMin, _gwClampMax);
  final double gScale = (grayAvg / (gSum/total + eps)).clamp(_gwClampMin, _gwClampMax);
  final double bScale = (grayAvg / (bSum/total + eps)).clamp(_gwClampMin, _gwClampMax);

  //second pass: convert to lab with white-balanced rgb
  final Float32List lab = Float32List(total * 3);
  for (int i = 0; i < total; i++) {
    final int srcBase = i*4;
    final int dstBase = i*3;

    final int r = (src[srcBase    ]*rScale).clamp(0, 255).round();
    final int g = (src[srcBase + 1]*gScale).clamp(0, 255).round();
    final int b = (src[srcBase + 2]*bScale).clamp(0, 255).round();

    _rgbToOpenCvLabInto(r, g, b, lab, dstBase);
  }

  return lab;
}

class ColorDetector {
  Float32List? _labFrame;
  int _frameWidth  = 0;
  int _frameHeight = 0;

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

    x1 = _clamp(x1, _frameWidth);
    x2 = _clamp(x2, _frameWidth);
    y1 = _clamp(y1, _frameHeight);
    y2 = _clamp(y2, _frameHeight);

    if (x2 <= x1 || y2 <= y1) return _fallback();
    if ((x2-x1) * (y2-y1) < _minBboxArea) return _fallback(); //bbox too small

    final Float32List pixels = _sampleLabPixels(x1, y1, x2, y2);
    if (pixels.isEmpty) return _fallback();

    // try saturated pixels only; fall back to everthing if too few survive
    Float32List filtered = _filterLowChroma(pixels, pixels.length ~/ 3);
    if (filtered.length ~/ 3 < 10) filtered = pixels;

    final Float32List dom = _dominantLabColor(filtered, filtered.length ~/ 3);
    return _labToColorName(dom[0], dom[1], dom[2]);
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

  ColorResult _fallback() => _grayFallback;

  int _clamp(int v, int max) => v.clamp(0, max).toInt();

  Float32List _sampleLabPixels(int x1, int y1, int x2, int y2) {
    final int cw  = x2 - x1;
    final int ch  = y2 - y1;
    final int cap =
        ((cw + _pixelStride-1) ~/ _pixelStride) *
        ((ch + _pixelStride-1) ~/ _pixelStride);

    final Float32List sampled = Float32List(cap * 3);
    int count = 0;

    for (int py = y1; py < y2; py += _pixelStride) {
      for (int px = x1; px < x2; px += _pixelStride) {
        final int si = (py * _frameWidth + px) * 3;
        final int di = count * 3;
        sampled[di    ] = _labFrame![si];
        sampled[di + 1] = _labFrame![si + 1];
        sampled[di + 2] = _labFrame![si + 2];
        count++;
      }
    }

    return Float32List.sublistView(sampled, 0, count*3);
  }

  Float32List _filterLowChroma(Float32List pixels, int count) {
    final double threshSq = _chromaFilterThreshold * _chromaFilterThreshold;
    int kept = 0;
    for (int i = 0; i < count; i++) {
      final double da = pixels[i*3 + 1] - 128.0;
      final double db = pixels[i*3 + 2] - 128.0;
      if (da*da + db*db >= threshSq) kept++;
    }
    if (kept == 0) return pixels; //all neutral, let caller decide

    final Float32List out = Float32List(kept * 3);
    int j = 0;
    for (int i = 0; i < count; i++) {
      final double da = pixels[i*3 + 1] - 128.0;
      final double db = pixels[i*3 + 2] - 128.0;
      if (da*da + db*db >= threshSq) {
        out[j*3    ] = pixels[i*3];
        out[j*3 + 1] = pixels[i*3 + 1];
        out[j*3 + 2] = pixels[i*3 + 2];
        j++;
      }
    }
    return out;
  }

  Float32List _dominantLabColor(Float32List pixels, int count) {
    if (count < _kmeansK * 2) return _meanColor(pixels, count);

    final Random rng = Random(0); //fixed seed -- deterministic across frames
    final List<Float32List> centroids = [];

    centroids.add(_pixelAt(pixels, rng.nextInt(count)));

    // kmeans++ seeding: weight next seed by distance to nearest existing centroid
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

    //pick largest cluster
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
      l += pixels[i*3];
      a += pixels[i*3 + 1];
      b += pixels[i*3 + 2];
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

  // replaced old euclidean prototype distance (included L channel, caused dark reds
  // to match brown) with:
  //   1. neutral guard -- chroma threshold, unchanged logic, just lower value
  //   2. brown rule -- warm hue + low chroma + moderate L, checked before hue buckets
  //      so vivid reds/oranges are never pulled toward brown
  //   3. hue bucketing -- atan2(b*,a*) angle at computed midpoints, no L contamination
  //   4. pink/red split -- same hue zone, split by lightness threshold
  ColorResult _labToColorName(double L, double rawA, double rawB) {
    final double A = rawA - 128.0;
    final double B = rawB - 128.0;
    final double chroma = sqrt(A*A + B*B);

    if (chroma < _neutralChromaThreshold) {
      if (L > _whiteLThreshold) return const ColorResult(colorEn: 'white', colorAr: 'أبيض');
      if (L < _blackLThreshold) return const ColorResult(colorEn: 'black', colorAr: 'أسود');
      return const ColorResult(colorEn: 'gray', colorAr: 'رمادي');
    }

    double h = atan2(B, A) * 180.0 / pi;
    if (h < 0) h += 360.0;

    // brown check first -- dark desaturated red would otherwise slip
    // through as "red" or "orange" in hue buckets
    if (_isBrownCandidate(h, chroma, L)) {
      return const ColorResult(colorEn: 'brown', colorAr: 'بني');
    }

    final String name;

    if (_isPinkRedHue(h)) {
      name = L >= _pinkLMin ? 'pink' : 'red';
    } else if (h < _hRedOrange) {
      name = 'red'; //[16, 51)
    } else if (h < _hOrangeYellow) {
      name = 'orange'; //[51, 84)
    } else if (h < _hYellowGreen) {
      name = 'yellow'; //[84, 119)
    } else if (h < _hGreenBlue) {
      name = 'green'; //[119, 220) -- cyan lands here too
    } else if (h < _hBluePurple) {
      name = 'blue'; //[220, 315)
    } else {
      name = 'purple'; //[315, 340)
    }

    return ColorResult(
      colorEn: name,
      colorAr: _colorArabic[name] ?? name,
    );
  }

  bool _isBrownCandidate(double hue, double chroma, double lightness) =>
      hue < _brownHueMax && chroma < _brownChromaMax && lightness < _brownLMax;

  bool _isPinkRedHue(double hue) => hue >= _hPurplePink || hue < _hPinkRed;
}
