import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'ocr_service.dart';
import 'ocr_layout_orderer.dart';
import 'ocr_router.dart';
import 'ocr_recognition.dart';

enum PdfPageTextSource { nativeText, onDeviceOcr, none }

class PdfPageExtraction {
  const PdfPageExtraction({
    required this.pageNumber,
    required this.nativeText,
    required this.text,
    required this.source,
    required this.ocrAttempted,
    required this.route,
    required this.routeReason,
    this.engineUsed,
    this.confidence,
    this.regions = const [],
    this.warning,
  });

  final int pageNumber;
  final String nativeText;
  final String text;
  final PdfPageTextSource source;
  final bool ocrAttempted;
  final OcrRoute route;
  final String routeReason;
  final OcrEngine? engineUsed;
  final double? confidence;
  final List<OcrTextRegion> regions;
  final String? warning;

  bool get hasText => text.trim().isNotEmpty;

  bool get hasUsableText =>
      text.trim().length >= PdfTextExtractor.minimumNativeTextLength;
}

class PdfExtractionResult {
  const PdfExtractionResult({required this.pages, required this.ocrAvailable});

  final List<PdfPageExtraction> pages;
  final bool ocrAvailable;

  int get pageCount => pages.length;

  /// Pages with a usable native text layer. OCR results are counted separately.
  int get pagesWithText => pages
      .where(
        (page) =>
            page.source == PdfPageTextSource.nativeText &&
            page.text.trim().length >= PdfTextExtractor.minimumNativeTextLength,
      )
      .length;

  int get ocrPages => pages
      .where(
        (page) => page.source == PdfPageTextSource.onDeviceOcr && page.hasText,
      )
      .length;

  int get paddleOcrPages =>
      pages.where((page) => page.engineUsed == OcrEngine.paddleOcr).length;

  int get mlKitPages =>
      pages.where((page) => page.engineUsed == OcrEngine.mlKit).length;

  int get unreadablePages => pages.where((page) => !page.hasUsableText).length;

  int get pagesWithWarnings =>
      pages.where((page) => page.warning != null).length;

  String get text => pages
      .where((page) => page.hasText)
      .map((page) => page.text.trim())
      .join('\n\n');

  bool get looksScanned =>
      pageCount > 0 &&
      pagesWithText < (pageCount * .25).ceil() &&
      ocrPages == 0;
}

class PdfTextExtractor {
  const PdfTextExtractor({
    this.router = const OcrRouter(),
    this.layoutOrderer = const OcrLayoutOrderer(),
  });

  static const minimumNativeTextLength = OcrRouter.minimumNativeTextLength;
  final OcrRouter router;
  final OcrLayoutOrderer layoutOrderer;

  Future<PdfExtractionResult> extract(
    Uint8List bytes, {
    String? sourceName,
  }) async {
    const ocr = OcrService();
    final document = await PdfDocument.openData(
      bytes,
      sourceName: sourceName ?? 'import.pdf',
    );
    try {
      final pageResults = <PdfPageExtraction>[];
      for (final page in document.pages) {
        final nativeText = (await page.loadText())?.fullText.trim() ?? '';
        final decision = router.decide(
          nativeText: nativeText,
          availableEngines: ocr.availableEngines,
        );
        if (decision.route == OcrRoute.nativeText) {
          pageResults.add(
            PdfPageExtraction(
              pageNumber: page.pageNumber,
              nativeText: nativeText,
              text: nativeText,
              source: PdfPageTextSource.nativeText,
              ocrAttempted: false,
              route: decision.route,
              routeReason: decision.reason,
            ),
          );
          continue;
        }

        if (decision.route == OcrRoute.unavailable) {
          pageResults.add(
            PdfPageExtraction(
              pageNumber: page.pageNumber,
              nativeText: nativeText,
              text: nativeText,
              source: nativeText.isEmpty
                  ? PdfPageTextSource.none
                  : PdfPageTextSource.nativeText,
              ocrAttempted: false,
              route: decision.route,
              routeReason: decision.reason,
              warning: decision.reason,
            ),
          );
          continue;
        }

        OcrRecognition? recognized;
        var engineFailed = false;
        for (final engine in decision.enginesToTry) {
          try {
            final attempt = await ocr.recognizePage(page, engine: engine);
            if (attempt.text.trim().length >=
                OcrRouter.minimumNativeTextLength) {
              recognized = attempt;
              break;
            }
          } catch (_) {
            // A failed engine stays local to this page; try the next route.
            engineFailed = true;
          }
        }

        final recognizedText = recognized == null
            ? ''
            : recognized.regions.isEmpty
            ? recognized.text.trim()
            : layoutOrderer.text(recognized.regions).trim();
        final hasRecognizedText =
            recognizedText.length >= OcrRouter.minimumNativeTextLength;
        pageResults.add(
          PdfPageExtraction(
            pageNumber: page.pageNumber,
            nativeText: nativeText,
            text: hasRecognizedText ? recognizedText : nativeText,
            source: hasRecognizedText
                ? PdfPageTextSource.onDeviceOcr
                : nativeText.isEmpty
                ? PdfPageTextSource.none
                : PdfPageTextSource.nativeText,
            ocrAttempted: decision.enginesToTry.isNotEmpty,
            route: decision.route,
            routeReason: decision.reason,
            engineUsed: recognized?.engine,
            confidence: recognized?.confidence,
            regions: recognized?.regions ?? const [],
            warning: hasRecognizedText
                ? null
                : engineFailed
                ? 'Não foi possível aplicar os motores OCR nesta página.'
                : 'OCR não encontrou texto suficiente nesta página.',
          ),
        );
      }
      return PdfExtractionResult(
        pages: List.unmodifiable(pageResults),
        ocrAvailable: ocr.availableEngines.isNotEmpty,
      );
    } finally {
      await document.dispose();
    }
  }
}
