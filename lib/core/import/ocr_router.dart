enum OcrEngine { paddleOcr, mlKit }

enum OcrRoute { nativeText, paddleOcr, mlKit, unavailable }

class OcrRouteDecision {
  const OcrRouteDecision({
    required this.route,
    required this.reason,
    this.fallbackEngines = const [],
  });

  final OcrRoute route;
  final String reason;
  final List<OcrEngine> fallbackEngines;

  List<OcrEngine> get enginesToTry => switch (route) {
    OcrRoute.paddleOcr => [OcrEngine.paddleOcr, ...fallbackEngines],
    OcrRoute.mlKit => [OcrEngine.mlKit, ...fallbackEngines],
    OcrRoute.nativeText || OcrRoute.unavailable => const [],
  };
}

/// Chooses the least expensive available way to extract one PDF page.
///
/// Uses PaddleOCR first for image-only pages and ML Kit for pages with a short
/// text layer. Each route may fall back to the other installed on-device OCR.
class OcrRouter {
  const OcrRouter();

  static const minimumNativeTextLength = 20;

  OcrRouteDecision decide({
    required String nativeText,
    required Set<OcrEngine> availableEngines,
  }) {
    if (nativeText.trim().length >= minimumNativeTextLength) {
      return const OcrRouteDecision(
        route: OcrRoute.nativeText,
        reason: 'A camada de texto nativa tem conteúdo suficiente.',
      );
    }

    final hasPaddle = availableEngines.contains(OcrEngine.paddleOcr);
    final hasMlKit = availableEngines.contains(OcrEngine.mlKit);
    if (nativeText.trim().isEmpty && hasPaddle) {
      return OcrRouteDecision(
        route: OcrRoute.paddleOcr,
        reason: 'A página é imagem; usar PaddleOCR e recorrer ao ML Kit se necessário.',
        fallbackEngines: hasMlKit ? const [OcrEngine.mlKit] : const [],
      );
    }

    if (hasMlKit) {
      return OcrRouteDecision(
        route: OcrRoute.mlKit,
        reason: 'A camada de texto nativa é curta; tentar ML Kit.',
        fallbackEngines: hasPaddle ? const [OcrEngine.paddleOcr] : const [],
      );
    }

    if (hasPaddle) {
      return const OcrRouteDecision(
        route: OcrRoute.paddleOcr,
        reason: 'Não há ML Kit disponível; usar PaddleOCR.',
      );
    }

    return OcrRouteDecision(
      route: OcrRoute.unavailable,
      reason: nativeText.trim().isEmpty
          ? 'A página não tem texto nativo e não há motor OCR disponível.'
          : 'O texto nativo é curto e não há motor OCR disponível.',
    );
  }
}
