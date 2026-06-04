import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DepthMap {
  final int width;
  final int height;
  final Float32List data;

  const DepthMap({
    required this.width,
    required this.height,
    required this.data,
  });

  double valueAt(int x, int y) {
    final clampedX = x.clamp(0, width - 1);
    final clampedY = y.clamp(0, height - 1);
    return data[clampedY * width + clampedX];
  }
}

class MidasDepthEngine {
  final String assetPath;
  final int inputSize;
  final int threads;

  Interpreter? _interpreter;
  int? _outputWidth;
  int? _outputHeight;
  TensorType? _inputType;
  TensorType? _outputType;
  double _inputScale = 1.0;
  int _inputZeroPoint = 0;
  double _outputScale = 1.0;
  int _outputZeroPoint = 0;

  MidasDepthEngine({
    required this.assetPath,
    required this.inputSize,
    required this.threads,
  });

  Future<void> _ensureInitialized() async {
    if (_interpreter != null) return;
    final options = InterpreterOptions()..threads = threads;
    debugPrint('[MiDaS] Loading model: $assetPath (threads=$threads)');
    _interpreter = await Interpreter.fromAsset(assetPath, options: options);
    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    final outputShape = outputTensor.shape;
    _inputType = inputTensor.type;
    _outputType = outputTensor.type;
    _inputScale = inputTensor.params.scale;
    _inputZeroPoint = inputTensor.params.zeroPoint;
    _outputScale = outputTensor.params.scale;
    _outputZeroPoint = outputTensor.params.zeroPoint;
    debugPrint('[MiDaS] Input shape: $inputShape');
    debugPrint('[MiDaS] Input type: $_inputType scale=$_inputScale zp=$_inputZeroPoint');
    debugPrint('[MiDaS] Output shape: $outputShape');
    debugPrint('[MiDaS] Output type: $_outputType scale=$_outputScale zp=$_outputZeroPoint');
    _resolveOutputSize(outputShape);
  }

  void _resolveOutputSize(List<int> shape) {
    if (shape.length == 4) {
      if (shape[1] == 1) {
        _outputHeight = shape[2];
        _outputWidth = shape[3];
      } else if (shape[3] == 1) {
        _outputHeight = shape[1];
        _outputWidth = shape[2];
      } else {
        _outputHeight = shape[1];
        _outputWidth = shape[2];
      }
      return;
    }
    if (shape.length == 3) {
      _outputHeight = shape[1];
      _outputWidth = shape[2];
      return;
    }
    _outputHeight = inputSize;
    _outputWidth = inputSize;
  }

  Future<DepthMap> run(img.Image frame) async {
    await _ensureInitialized();
    debugPrint('[MiDaS] Running inference on ${frame.width}x${frame.height}');
    final resized = img.copyResize(
      frame,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = _prepareInput(resized);

    final outputWidth = _outputWidth ?? inputSize;
    final outputHeight = _outputHeight ?? inputSize;
    final outputLength = outputWidth * outputHeight;
    final outputRaw = _outputType == TensorType.uint8
        ? Uint8List(outputLength)
        : Float32List(outputLength);

    _interpreter!.run(input, outputRaw);

    final output = _dequantizeOutput(outputRaw, outputLength);

    return DepthMap(width: outputWidth, height: outputHeight, data: output);
  }

  dynamic _prepareInput(img.Image resized) {
    final length = 1 * inputSize * inputSize * 3;
    var idx = 0;
    final scale = _inputScale == 0 ? 1.0 : _inputScale;
    if (_inputType == TensorType.uint8) {
      final input = Uint8List(length);
      for (var y = 0; y < inputSize; y++) {
        for (var x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          input[idx++] = _quantize(pixel.r / 255.0, scale, _inputZeroPoint);
          input[idx++] = _quantize(pixel.g / 255.0, scale, _inputZeroPoint);
          input[idx++] = _quantize(pixel.b / 255.0, scale, _inputZeroPoint);
        }
      }
      return input;
    }

    final input = Float32List(length);
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[idx++] = pixel.r / 255.0;
        input[idx++] = pixel.g / 255.0;
        input[idx++] = pixel.b / 255.0;
      }
    }
    return input;
  }

  int _quantize(double value, double scale, int zeroPoint) {
    final q = (value / scale + zeroPoint).round();
    return q.clamp(0, 255);
  }

  Float32List _dequantizeOutput(dynamic raw, int length) {
    if (raw is Float32List) return raw;
    if (raw is Uint8List) {
      final output = Float32List(length);
      final scale = _outputScale == 0 ? 1.0 : _outputScale;
      for (var i = 0; i < length; i++) {
        output[i] = scale * (raw[i] - _outputZeroPoint);
      }
      return output;
    }
    return Float32List(length);
  }
}
