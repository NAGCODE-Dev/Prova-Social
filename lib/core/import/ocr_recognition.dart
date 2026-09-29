import 'ocr_router.dart';

class OcrPoint {
  const OcrPoint(this.x, this.y);

  final double x;
  final double y;
}

class OcrTextRegion {
  const OcrTextRegion({
    required this.text,
    required this.points,
    this.confidence,
  });

  final String text;
  final List<OcrPoint> points;
  final double? confidence;
}

class OcrRecognition {
  const OcrRecognition({
    required this.engine,
    required this.text,
    this.confidence,
    this.regions = const [],
  });

  final OcrEngine engine;
  final String text;
  final double? confidence;
  final List<OcrTextRegion> regions;
}
