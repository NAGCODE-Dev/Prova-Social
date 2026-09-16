import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

class OcrService {
  const OcrService();

  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<String> recognizePage(PdfPage page) async {
    if (!isSupported) return '';
    final scale =
        math.min(2.2, 2200 / math.max(page.width, page.height)).toDouble();
    final rendered = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xffffffff,
    );
    if (rendered == null) return '';

    File? temporary;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final bitmap = img.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: rendered.pixels.buffer,
        order: img.ChannelOrder.bgra,
      );
      final jpeg = img.encodeJpg(bitmap, quality: 88);
      final directory = await getTemporaryDirectory();
      temporary = File(
        '${directory.path}/prova_social_ocr_${page.pageNumber}_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await temporary.writeAsBytes(jpeg, flush: true);
      final result = await recognizer.processImage(
        InputImage.fromFilePath(temporary.path),
      );
      return result.text.trim();
    } finally {
      rendered.dispose();
      await recognizer.close();
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
