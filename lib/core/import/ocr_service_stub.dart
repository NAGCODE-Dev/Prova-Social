import 'package:pdfrx/pdfrx.dart';

import 'ocr_recognition.dart';
import 'ocr_router.dart';

class OcrService {
  const OcrService();

  bool get isSupported => false;

  Set<OcrEngine> get availableEngines => const {};

  Future<OcrRecognition> recognizePage(
    PdfPage page, {
    required OcrEngine engine,
  }) async => OcrRecognition(engine: engine, text: '');
}
