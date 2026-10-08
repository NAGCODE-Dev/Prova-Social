import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
  static Future<void>? _pdfrxInitialization;
  final OcrRouter router;
  final OcrLayoutOrderer layoutOrderer;

  static Future<void> initialize() => _initializePdfrx();

  static Future<void> _initializePdfrx() async {
    final existing = _pdfrxInitialization;
    if (existing != null) return existing;
    final initialization = pdfrxFlutterInitialize();
    _pdfrxInitialization = initialization;
    try {
      await initialization;
    } catch (_) {
      if (identical(_pdfrxInitialization, initialization)) {
        _pdfrxInitialization = null;
      }
      rethrow;
    }
  }

  Future<PdfExtractionResult> extract(
    Uint8List bytes, {
    String? sourceName,
  }) async {
    await _initializePdfrx();
    const ocr = OcrService();
    final document = await PdfDocument.openData(
      bytes,
      sourceName: sourceName ?? 'import.pdf',
    );
    try {
      final pageResults = <PdfPageExtraction>[];
      for (final page in document.pages) {
        final structuredText = await page.loadStructuredText();
        final nativeText = _nativeTextInReadingOrder(
          structuredText,
          pageWidth: page.width,
          pageHeight: page.height,
        ).trim();
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
          } catch (error, stackTrace) {
            debugPrint('[OCR] engine=$engine FALHOU: $error');
            debugPrint('$stackTrace');

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

  String _nativeTextInReadingOrder(
    PdfPageText pageText, {
    required double pageWidth,
    required double pageHeight,
  }) {
    if (pageText.fragments.isEmpty) return pageText.fullText;

    final lines = <_NativeTextLine>[];
    for (final fragment in pageText.fragments) {
      if (fragment.text.trim().isEmpty) continue;
      final lineY = (fragment.bounds.top + fragment.bounds.bottom) / 2;
      final fragmentHeight = (fragment.bounds.top - fragment.bounds.bottom)
          .abs();
      _NativeTextLine? matchingLine;
      for (final line in lines.reversed) {
        final tolerance = math.max(line.height, fragmentHeight) * .55;
        final horizontalGap = fragment.bounds.left > line.right
            ? fragment.bounds.left - line.right
            : line.left > fragment.bounds.right
            ? line.left - fragment.bounds.right
            : 0.0;
        if ((line.centerY - lineY).abs() <= tolerance &&
            horizontalGap <= pageWidth * .015) {
          matchingLine = line;
          break;
        }
      }
      if (matchingLine == null) {
        lines.add(_NativeTextLine(fragment));
      } else {
        matchingLine.add(fragment);
      }
    }

    for (final line in lines) {
      line.sortFragments();
    }
    lines.removeWhere((line) {
      if (line.centerY >= pageHeight * .06) return false;
      final text = line.text.trim();
      return RegExp(r'^\d{1,3}$').hasMatch(text) ||
          text.contains('Confidencial') ||
          text.contains('PMES2401');
    });
    final columnLines = lines
        .where((line) => line.width < pageWidth * .58)
        .toList(growable: false);
    final splitX = _findNativeColumnSplit(columnLines, pageWidth);
    if (splitX == null) {
      final singleColumn = [...lines]
        ..sort((a, b) => b.centerY.compareTo(a.centerY));
      return singleColumn.map((line) => line.text).join('\n');
    }

    final left = columnLines.where((line) => line.centerX < splitX).toList()
      ..sort((a, b) => b.centerY.compareTo(a.centerY));
    final right = columnLines.where((line) => line.centerX >= splitX).toList()
      ..sort((a, b) => b.centerY.compareTo(a.centerY));
    final spanning =
        lines.where((line) => line.width >= pageWidth * .58).toList()
          ..sort((a, b) => b.centerY.compareTo(a.centerY));

    final bodyMidpoint = columnLines.isEmpty
        ? 0.0
        : (columnLines.map((line) => line.centerY).reduce(math.max) +
                  columnLines.map((line) => line.centerY).reduce(math.min)) /
              2;
    final topSpanning = spanning
        .where((line) => line.centerY >= bodyMidpoint)
        .map((line) => line.text);
    final bottomSpanning = spanning
        .where((line) => line.centerY < bodyMidpoint)
        .map((line) => line.text);
    return [
      topSpanning.join('\n'),
      left.map((line) => line.text).join('\n'),
      right.map((line) => line.text).join('\n'),
      bottomSpanning.join('\n'),
    ].where((column) => column.isNotEmpty).join('\n\n');
  }

  double? _findNativeColumnSplit(
    List<_NativeTextLine> lines,
    double pageWidth,
  ) {
    if (lines.length < 10) return null;
    final centers = lines.map((line) => line.centerX).toList()..sort();
    final leftColumnLines = centers.where((x) => x < pageWidth * .42).length;
    final rightColumnLines = centers.where((x) => x > pageWidth * .58).length;
    if (leftColumnLines >= 4 && rightColumnLines >= 4) {
      return pageWidth / 2;
    }

    var largestGap = 0.0;
    var splitIndex = -1;
    for (var index = 1; index < centers.length; index++) {
      final gap = centers[index] - centers[index - 1];
      if (gap > largestGap) {
        largestGap = gap;
        splitIndex = index;
      }
    }
    if (splitIndex < 4 || centers.length - splitIndex < 4) return null;
    final splitX = (centers[splitIndex - 1] + centers[splitIndex]) / 2;
    if (largestGap < pageWidth * .12 ||
        splitX < pageWidth * .25 ||
        splitX > pageWidth * .75) {
      return null;
    }
    return splitX;
  }
}

class _NativeTextLine {
  _NativeTextLine(PdfPageTextFragment fragment) : _fragments = [fragment];

  final List<PdfPageTextFragment> _fragments;

  void add(PdfPageTextFragment fragment) => _fragments.add(fragment);

  void sortFragments() =>
      _fragments.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

  String get text =>
      _fragments.map((fragment) => fragment.text.trim()).join(' ');

  double get centerY =>
      _fragments
          .map((fragment) => (fragment.bounds.top + fragment.bounds.bottom) / 2)
          .reduce((a, b) => a + b) /
      _fragments.length;

  double get height => _fragments
      .map((fragment) => (fragment.bounds.top - fragment.bounds.bottom).abs())
      .reduce(math.max);

  double get centerX => (left + right) / 2;

  double get left =>
      _fragments.map((fragment) => fragment.bounds.left).reduce(math.min);

  double get right =>
      _fragments.map((fragment) => fragment.bounds.right).reduce(math.max);

  double get width => right - left;
}
