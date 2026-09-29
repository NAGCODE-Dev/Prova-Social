import 'package:flutter/services.dart';

class PaddleOcrAndroid {
  const PaddleOcrAndroid();

  static const _channel = MethodChannel('dev.nagcode.prova_social/paddle_ocr');

  Future<Map<String, Object?>?> recognize(Uint8List imageBytes) => _channel
      .invokeMapMethod<String, Object?>('recognize', {'image': imageBytes});
}
