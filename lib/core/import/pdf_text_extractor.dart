import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'ocr_service.dart';

class PdfExtractionResult {
  const PdfExtractionResult({
    required this.text,
    required this.pageCount,
    required this.pagesWithText,
    required this.ocrPages,
    required this.ocrAvailable,
  });

  final String text;
  final int pageCount;
  final int pagesWithText;
  final int ocrPages;
  final bool ocrAvailable;

  bool get looksScanned =>
      pageCount > 0 && pagesWithText < (pageCount * .25).ceil() && ocrPages == 0;
}

class PdfTextExtractor {
  const PdfTextExtractor();

  Future<PdfExtractionResult> extract(Uint8List bytes, {String? sourceName}) async {
    const ocr = OcrService();
    final document = await PdfDocument.openData(bytes, sourceName: sourceName ?? 'import.pdf');
    try {
      final buffer = StringBuffer();
      var pagesWithText = 0;
      var ocrPages = 0;
      for (final page in document.pages) {
        final raw = await page.loadText();
        var text = raw?.fullText.trim() ?? '';
        if (text.length >= 20) {
          pagesWithText++;
        } else if (ocr.isSupported) {
          final recognized = await ocr.recognizePage(page);
          if (recognized.length >= 20) {
            text = recognized;
            ocrPages++;
          }
        }
        if (text.isNotEmpty) buffer.writeln(text);
      }
      return PdfExtractionResult(
        text: buffer.toString(),
        pageCount: document.pages.length,
        pagesWithText: pagesWithText,
        ocrPages: ocrPages,
        ocrAvailable: ocr.isSupported,
      );
    } finally {
      await document.dispose();
    }
  }
}
