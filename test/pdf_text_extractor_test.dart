import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/ocr_layout_orderer.dart';
import 'package:prova_social/core/import/ocr_recognition.dart';
import 'package:prova_social/core/import/ocr_router.dart';
import 'package:prova_social/core/import/pdf_text_extractor.dart';

void main() {
  group('PdfExtractionResult', () {
    test('preserva a origem do texto e resume páginas para revisão', () {
      const result = PdfExtractionResult(
        pages: [
          PdfPageExtraction(
            pageNumber: 1,
            nativeText: 'Questão 1. Texto nativo com tamanho suficiente.',
            text: 'Questão 1. Texto nativo com tamanho suficiente.',
            source: PdfPageTextSource.nativeText,
            ocrAttempted: false,
            route: OcrRoute.nativeText,
            routeReason: 'A camada nativa contém texto suficiente.',
          ),
          PdfPageExtraction(
            pageNumber: 2,
            nativeText: '',
            text: 'Questão 2. Texto reconhecido pelo OCR local.',
            source: PdfPageTextSource.onDeviceOcr,
            ocrAttempted: true,
            route: OcrRoute.mlKit,
            routeReason: 'A página não tem texto nativo; usar ML Kit.',
          ),
          PdfPageExtraction(
            pageNumber: 3,
            nativeText: '',
            text: '',
            source: PdfPageTextSource.none,
            ocrAttempted: true,
            route: OcrRoute.mlKit,
            routeReason: 'A página não tem texto nativo; usar ML Kit.',
            warning: 'OCR não encontrou texto suficiente nesta página.',
          ),
          PdfPageExtraction(
            pageNumber: 4,
            nativeText: 'curto',
            text: 'curto',
            source: PdfPageTextSource.nativeText,
            ocrAttempted: false,
            route: OcrRoute.unavailable,
            routeReason: 'Não há motor OCR disponível.',
            warning: 'OCR indisponível para esta página neste dispositivo.',
          ),
        ],
        ocrAvailable: true,
      );

      expect(result.pageCount, 4);
      expect(result.pagesWithText, 1);
      expect(result.ocrPages, 1);
      expect(result.unreadablePages, 2);
      expect(result.pagesWithWarnings, 2);
      expect(result.text, contains('Questão 1'));
      expect(result.text, contains('Questão 2'));
      expect(result.text, contains('curto'));
      expect(result.looksScanned, isFalse);
    });

    test('identifica documento digitalizado sem texto extraído', () {
      const result = PdfExtractionResult(
        pages: [
          PdfPageExtraction(
            pageNumber: 1,
            nativeText: '',
            text: '',
            source: PdfPageTextSource.none,
            ocrAttempted: true,
            route: OcrRoute.mlKit,
            routeReason: 'A página não tem texto nativo; usar ML Kit.',
            warning: 'OCR não encontrou texto suficiente nesta página.',
          ),
          PdfPageExtraction(
            pageNumber: 2,
            nativeText: '',
            text: '',
            source: PdfPageTextSource.none,
            ocrAttempted: true,
            route: OcrRoute.mlKit,
            routeReason: 'A página não tem texto nativo; usar ML Kit.',
            warning: 'OCR não encontrou texto suficiente nesta página.',
          ),
        ],
        ocrAvailable: true,
      );

      expect(result.looksScanned, isTrue);
      expect(result.unreadablePages, 2);
      expect(result.ocrPages, 0);
    });
  });

  group('OcrRouter', () {
    const router = OcrRouter();

    test('prefere a camada nativa quando tem texto suficiente', () {
      final decision = router.decide(
        nativeText: 'Texto extraído diretamente do PDF.',
        availableEngines: const {OcrEngine.mlKit},
      );

      expect(decision.route, OcrRoute.nativeText);
    });

    test('usa ML Kit quando a camada nativa é insuficiente', () {
      final decision = router.decide(
        nativeText: 'trecho curto',
        availableEngines: const {OcrEngine.mlKit, OcrEngine.paddleOcr},
      );

      expect(decision.route, OcrRoute.mlKit);
      expect(decision.enginesToTry, [OcrEngine.mlKit, OcrEngine.paddleOcr]);
    });

    test('prefere PaddleOCR em página sem camada de texto', () {
      final decision = router.decide(
        nativeText: '',
        availableEngines: const {OcrEngine.mlKit, OcrEngine.paddleOcr},
      );

      expect(decision.route, OcrRoute.paddleOcr);
      expect(decision.enginesToTry, [OcrEngine.paddleOcr, OcrEngine.mlKit]);
    });

    test('marca revisão quando nenhum motor está disponível', () {
      final decision = router.decide(
        nativeText: '',
        availableEngines: const {},
      );

      expect(decision.route, OcrRoute.unavailable);
    });
  });

  group('OcrLayoutOrderer', () {
    const orderer = OcrLayoutOrderer();

    test('lê uma página em duas colunas de cima para baixo', () {
      final regions = [
        _region('Direita 1', 300, 10),
        _region('Esquerda 2', 10, 40),
        _region('Direita 2', 300, 40),
        _region('Esquerda 1', 10, 10),
      ];

      expect(orderer.order(regions), [
        'Esquerda 1\nEsquerda 2',
        'Direita 1\nDireita 2',
      ]);
    });

    test('mantém a ordem vertical quando não há separação de colunas', () {
      final regions = [_region('Linha 2', 20, 40), _region('Linha 1', 10, 10)];

      expect(orderer.text(regions), 'Linha 1\nLinha 2');
    });
  });
}

OcrTextRegion _region(String text, double x, double y) => OcrTextRegion(
  text: text,
  points: [
    OcrPoint(x, y),
    OcrPoint(x + 80, y),
    OcrPoint(x + 80, y + 12),
    OcrPoint(x, y + 12),
  ],
);
