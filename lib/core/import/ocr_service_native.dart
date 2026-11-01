import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:paddleocr_android/paddleocr_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'ocr_recognition.dart';
import 'ocr_router.dart';

/// OCR session scoped to one PDF import; native ML Kit state is reused per page.
class OcrService {
  OcrService();

  static const _paddleOcr = PaddleOcrAndroid();
  TextRecognizer? _mlKitRecognizer;

  Set<OcrEngine> get availableEngines => switch (defaultTargetPlatform) {
    TargetPlatform.android => const {OcrEngine.paddleOcr, OcrEngine.mlKit},
    TargetPlatform.iOS => const {OcrEngine.mlKit},
    _ => const {},
  };

  Future<OcrRecognition> recognizePage(
    PdfPage page, {
    required OcrEngine engine,
  }) async {
    if (!availableEngines.contains(engine)) {
      return OcrRecognition(engine: engine, text: '');
    }

    final scale = math
        .min(2.2, 2200 / math.max(page.width, page.height))
        .toDouble();
    final rendered = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: 0xffffffff,
    );
    if (rendered == null) return OcrRecognition(engine: engine, text: '');

    try {
      // Pixel conversion and JPEG compression are CPU-heavy; keep them off the
      // UI isolate so scanned pages do not freeze import progress.
      final jpeg = await compute(_encodeOcrPage, (
        pixels: rendered.pixels,
        width: rendered.width,
        height: rendered.height,
      ));
      return switch (engine) {
        OcrEngine.paddleOcr => await _recognizeWithPaddle(jpeg),
        OcrEngine.mlKit => await _recognizeWithMlKit(jpeg, page.pageNumber),
      };
    } finally {
      rendered.dispose();
    }
  }

  Future<OcrRecognition> _recognizeWithPaddle(Uint8List imageBytes) async {
    debugPrint('[PADDLE] iniciando OCR: ${imageBytes.length} bytes');

    final stopwatch = Stopwatch()..start();

    final response = await _paddleOcr.recognize(imageBytes);

    stopwatch.stop();

    debugPrint(
      '[PADDLE] terminou em ${stopwatch.elapsedMilliseconds} ms '
      'response=${response != null}',
    );
    final rawLines = response?['lines'];
    final regions = <OcrTextRegion>[];
    if (rawLines is List) {
      for (final rawLine in rawLines) {
        if (rawLine is! Map) continue;
        final text = (rawLine['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;
        final confidence = (rawLine['confidence'] as num?)?.toDouble();
        final points = <OcrPoint>[];
        final rawPoints = rawLine['points'];
        if (rawPoints is List) {
          for (final rawPoint in rawPoints) {
            if (rawPoint is List &&
                rawPoint.length >= 2 &&
                rawPoint[0] is num &&
                rawPoint[1] is num) {
              points.add(
                OcrPoint(
                  (rawPoint[0] as num).toDouble(),
                  (rawPoint[1] as num).toDouble(),
                ),
              );
            }
          }
        }
        regions.add(
          OcrTextRegion(
            text: text,
            confidence: confidence,
            points: List.unmodifiable(points),
          ),
        );
      }
    }

    final confidences = regions
        .map((region) => region.confidence)
        .whereType<double>()
        .toList();
    final averageConfidence = confidences.isEmpty
        ? null
        : confidences.reduce((a, b) => a + b) / confidences.length;
    return OcrRecognition(
      engine: OcrEngine.paddleOcr,
      text: regions.map((region) => region.text).join('\n'),
      confidence: averageConfidence,
      regions: List.unmodifiable(regions),
    );
  }

  Future<OcrRecognition> _recognizeWithMlKit(
    Uint8List imageBytes,
    int pageNumber,
  ) async {
    File? temporary;
    final recognizer = _mlKitRecognizer ??= TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final directory = await getTemporaryDirectory();
      temporary = File(
        '${directory.path}/prova_social_ocr_${pageNumber}_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await temporary.writeAsBytes(imageBytes, flush: true);
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(temporary.path),
      );
      final regions = recognized.blocks
          .map(
            (block) => OcrTextRegion(
              text: block.text,
              points: [
                OcrPoint(block.boundingBox.left, block.boundingBox.top),
                OcrPoint(block.boundingBox.right, block.boundingBox.top),
                OcrPoint(block.boundingBox.right, block.boundingBox.bottom),
                OcrPoint(block.boundingBox.left, block.boundingBox.bottom),
              ],
            ),
          )
          .toList(growable: false);
      return OcrRecognition(
        engine: OcrEngine.mlKit,
        text: recognized.text.trim(),
        regions: List.unmodifiable(regions),
      );
    } catch (_) {
      // Do not retain a potentially broken native handle for subsequent pages.
      if (identical(_mlKitRecognizer, recognizer)) {
        _mlKitRecognizer = null;
      }
      await recognizer.close();
      rethrow;
    } finally {
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  /// Releases native OCR state after the current document has been processed.
  Future<void> dispose() async {
    final recognizer = _mlKitRecognizer;
    _mlKitRecognizer = null;
    if (recognizer != null) await recognizer.close();
  }
}

Uint8List _encodeOcrPage(({Uint8List pixels, int width, int height}) page) {
  final bitmap = img.Image.fromBytes(
    width: page.width,
    height: page.height,
    bytes: page.pixels.buffer,
    order: img.ChannelOrder.bgra,
  );
  return img.encodeJpg(bitmap, quality: 88);
}
