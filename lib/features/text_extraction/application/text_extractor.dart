import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

class _Box {
  final double x1, y1, x2, y2;
  const _Box(this.x1, this.y1, this.x2, this.y2);
  double get cx => (x1 + x2) / 2;
  double get cy => (y1 + y2) / 2;
  double get bh => y2 - y1;
}

class _OCRResult {
  final _Box   box;
  final String text;
  const _OCRResult(this.box, this.text);
}

class TextExtractor {
  static OrtSession? _detSession;
  static OrtSession? _recSession;
  static List<String> _dict          = [];
  static bool         _isInitialized = false;
  static const int    _detMaxSide  = 960;
  static const int    _recHeight   = 48;
  static const int    _recMaxWidth = 320;
  static const double _dbThresh    = 0.3;
  static const double _dbBoxThresh = 0.5;
  static const double _unclipRatio = 1.5;
  static const double _lineThreshold  = 0.6;
  static const int    _minArea     = 10;

  static const List<double> _detMean = [0.485, 0.456, 0.406];
  static const List<double> _detStd  = [0.229, 0.224, 0.225];

  static Future<void> initialize({
    String detModelPath = 'assets/models/det.onnx',
    String recModelPath = 'assets/models/rec.onnx',
    String dictPath     = 'assets/dict/ppocr_keys.txt',
  }) async {
    if (_isInitialized) return;
    OrtEnv.instance.init();

    final detBytes  = await _loadAsset(detModelPath);
    final recBytes  = await _loadAsset(recModelPath);
    final dictBytes = await _loadAsset(dictPath);

    _detSession = OrtSession.fromBuffer(detBytes, OrtSessionOptions());
    _recSession = OrtSession.fromBuffer(recBytes, OrtSessionOptions());

    final String dictContent = utf8.decode(dictBytes);
    final lines = dictContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    
    _dict = ['[BLANK]', ...lines, ' '];

    _isInitialized = true;
  }

  static Future<Uint8List> _loadAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  static Future<String> extractText(img.Image image) async {
    if (!_isInitialized) await initialize();

    final boxes = _detect(image);

    final results = <_OCRResult>[];

    for (int i = 0; i < boxes.length; i++) {
      final box = boxes[i];
      final x = box.x1.toInt().clamp(0, image.width - 1);
      final y = box.y1.toInt().clamp(0, image.height - 1);
      final w = (box.x2 - box.x1).toInt().clamp(1, image.width - x);
      final h = (box.y2 - box.y1).toInt().clamp(1, image.height - y);

      final crop = img.copyCrop(image, x: x, y: y, width: w, height: h);
      
      final text = _recognize(crop);
      if (text.isNotEmpty) {
        results.add(_OCRResult(box, text));
      }
    }

    final assembled = _assembleLines(results);
    print('OCR text: "$assembled"');
    return assembled;
  }

  static List<_Box> _detect(img.Image image) {
    final originalHeight   = image.height;
    final originalWidth   = image.width;
    final scale   = _detMaxSide / math.max(originalHeight, originalWidth);
    final newHeight    = ((originalHeight * scale) / 32).round() * 32;
    final newWidth    = ((originalWidth * scale) / 32).round() * 32;
    final resized = img.copyResize(image, width: newWidth, height: newHeight);
    final input   = _detPreprocess(resized, newHeight, newWidth);

    final tensor  = OrtValueTensor.createTensorWithDataList(input, [1, 3, newHeight, newWidth]);
    final opts    = OrtRunOptions();
    final outputs = _detSession!.run(opts, {_detSession!.inputNames.first: tensor});
    tensor.release();
    opts.release();

    final raw = outputs.first?.value;
    if (raw == null) return [];

    return _dbPostprocess(_flatten(raw), newHeight, newWidth, originalHeight, originalWidth);
  }

  static Float32List _detPreprocess(img.Image image, int h, int w) {
    final imageTensor = Float32List(3 * h * w);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p   = image.getPixel(x, y);
        final idx = y * w + x;
        imageTensor[0 * h * w + idx] = (p.r / 255.0 - _detMean[0]) / _detStd[0];
        imageTensor[1 * h * w + idx] = (p.g / 255.0 - _detMean[1]) / _detStd[1];
        imageTensor[2 * h * w + idx] = (p.b / 255.0 - _detMean[2]) / _detStd[2];
      }
    }
    return imageTensor;
  }

  static List<_Box> _dbPostprocess(
      List<double> prob, int mapHeight, int mapWidth, int origHeight, int origWidth) {
    final mask = List<bool>.filled(mapHeight * mapWidth, false);
    for (var i = 0; i < prob.length; i++) {
      if (i < mapHeight * mapWidth) mask[i] = prob[i] > _dbThresh;
    }

    final labels    = List<int>.filled(mapHeight * mapWidth, -1);
    var   numLabels = 0;

    for (var i = 0; i < mapHeight * mapWidth; i++) {
      if (!mask[i] || labels[i] != -1) continue;

      final queue = <int>[i];
      labels[i]   = numLabels;
      var head    = 0;

      while (head < queue.length) {
        final curr = queue[head++];
        final cy   = curr ~/ mapWidth;
        final cx   = curr % mapWidth;

        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dy == 0 && dx == 0) continue;
            final ny = cy + dy;
            final nx = cx + dx;
            if (ny < 0 || ny >= mapHeight || nx < 0 || nx >= mapWidth) continue;
            final ni = ny * mapWidth + nx;
            if (!mask[ni] || labels[ni] != -1) continue;
            labels[ni] = numLabels;
            queue.add(ni);
          }
        }
      }
      numLabels++;
    }

    final scaleX = origWidth / mapWidth;
    final scaleY = origHeight / mapHeight;
    final boxes  = <_Box>[];

    for (var label = 0; label < numLabels; label++) {
      var minX = mapWidth, minY = mapHeight, maxX = 0, maxY = 0;
      var sumP = 0.0;
      var cnt  = 0;

      for (var i = 0; i < mapHeight * mapWidth; i++) {
        if (labels[i] != label) continue;
        final py = i ~/ mapWidth;
        final px = i % mapWidth;
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        sumP += prob[i];
        cnt++;
      }

      if (cnt < _minArea || sumP / cnt < _dbBoxThresh) continue;

      final bw     = (maxX - minX).toDouble();
      final bh     = (maxY - minY).toDouble();
      final expand = (bw + bh) * (_unclipRatio - 1) / 2;

      final x1 = ((minX - expand) * scaleX).clamp(0.0, origWidth.toDouble());
      final y1 = ((minY - expand) * scaleY).clamp(0.0, origHeight.toDouble());
      final x2 = ((maxX + expand) * scaleX).clamp(0.0, origWidth.toDouble());
      final y2 = ((maxY + expand) * scaleY).clamp(0.0, origHeight.toDouble());

      if (x2 - x1 >= 5 && y2 - y1 >= 5) boxes.add(_Box(x1, y1, x2, y2));
    }

    return boxes;
  }

  static String _recognize(img.Image crop) {
    final scale   = _recHeight / crop.height;
    final tgtW    = math.min((crop.width * scale).round(), _recMaxWidth);
    final resized = img.copyResize(crop, width: tgtW, height: _recHeight);
    final input   = _recPreprocess(resized, _recHeight, tgtW);

    final tensor  = OrtValueTensor.createTensorWithDataList(input, [1, 3, _recHeight, tgtW]);
    final opts    = OrtRunOptions();
    final outputs = _recSession!.run(opts, {_recSession!.inputNames.first: tensor});
    tensor.release();
    opts.release();

    final raw = outputs.first?.value;
    if (raw == null) return '';

    return _ctcDecode(_flatten(raw));
  }

  static String _ctcDecode(List<double> logits) {
    final dictSize = _dict.length;
    final totalClasses = dictSize;
    final T = logits.length ~/ totalClasses;
    final buf = StringBuffer();
    var previousIdx = -1;

    for (var t = 0; t < T; t++) {
      var maxIdx = 0;
      var maxVal = logits[t * totalClasses];
      for (var c = 1; c < totalClasses; c++) {
        final v = logits[t * totalClasses + c];
        if (v > maxVal) {
          maxVal = v;
          maxIdx = c;
        }
      }
      
      final isBlank = maxIdx == 0;
      
      if (!isBlank && maxIdx != previousIdx) {
        final char = _dict[maxIdx];
        buf.write(char);
      }
      
      previousIdx = maxIdx;
    }

    final result = buf.toString();
    return result;
  }

  static Float32List _recPreprocess(img.Image image, int h, int w) {
    final imageTensor = Float32List(3 * h * w);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p   = image.getPixel(x, y);
        final idx = y * w + x;
        imageTensor[0 * h * w + idx] = (p.r / 255.0 - 0.5) / 0.5;
        imageTensor[1 * h * w + idx] = (p.g / 255.0 - 0.5) / 0.5;
        imageTensor[2 * h * w + idx] = (p.b / 255.0 - 0.5) / 0.5;
      }
    }
    return imageTensor;
  }

  static String _assembleLines(List<_OCRResult> results) {
    if (results.isEmpty) return '';

    results.sort((a, b) => a.box.cy.compareTo(b.box.cy));

    final avgH      = results.map((r) => r.box.bh).reduce((a, b) => a + b) / results.length;
    final threshold = avgH * _lineThreshold;
    final lines     = <List<_OCRResult>>[[results.first]];

    for (var i = 1; i < results.length; i++) {
      final last   = lines.last;
      final lineCy = last.map((r) => r.box.cy).reduce((a, b) => a + b) / last.length;
      if ((results[i].box.cy - lineCy).abs() <= threshold) {
        last.add(results[i]);
      } else {
        lines.add([results[i]]);
      }
    }

    return lines.map((line) {
      line.sort((a, b) => a.box.cx.compareTo(b.box.cx));
      return line.map((r) => r.text).join(' ');
    }).join('\n');
  }

  static List<double> _flatten(Object value) {
    final result = <double>[];
    _collect(value, result);
    return result;
  }

  static void _collect(dynamic value, List<double> out) {
    if (value is double) {
      out.add(value);
    } else if (value is num) {
      out.add(value.toDouble());
    } else if (value is Float32List) {
      for (final v in value) {out.add(v.toDouble()); }
    } else if (value is List) {
      for (final item in value) {_collect(item, out); }
    }
  }

  static void dispose() {
    _detSession?.release();
    _recSession?.release();
    _detSession    = null;
    _recSession    = null;
    _isInitialized = false;
  }
}