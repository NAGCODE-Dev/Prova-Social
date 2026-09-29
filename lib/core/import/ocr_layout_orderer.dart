import 'ocr_recognition.dart';

double _minDouble(double a, double b) => a < b ? a : b;
double _maxDouble(double a, double b) => a > b ? a : b;

/// Restores a practical reading order for OCR regions with page coordinates.
///
/// Paddle's detector returns line boxes, but its bundled SDK sorter treats
/// nearby lines across a page as one row. On two-column pages this can
/// interleave the columns. This orderer splits only when a clear horizontal
/// gap exists and both sides contain multiple regions.
class OcrLayoutOrderer {
  const OcrLayoutOrderer();

  List<String> order(List<OcrTextRegion> regions) {
    final usable = regions
        .where(
          (region) => region.text.trim().isNotEmpty && region.points.isNotEmpty,
        )
        .toList(growable: false);
    if (usable.isEmpty) return const [];

    final horizontal = [...usable]
      ..sort((a, b) => _centerX(a).compareTo(_centerX(b)));
    final split = _findColumnSplit(horizontal);
    if (split == null) return [_orderWithinColumn(usable)];

    return [
      _orderWithinColumn(horizontal.sublist(0, split)),
      _orderWithinColumn(horizontal.sublist(split)),
    ];
  }

  String text(List<OcrTextRegion> regions) => order(regions).join('\n');

  int? _findColumnSplit(List<OcrTextRegion> horizontal) {
    if (horizontal.length < 4) return null;
    final minX = horizontal.map(_centerX).reduce(_minDouble);
    final maxX = horizontal.map(_centerX).reduce(_maxDouble);
    final spread = maxX - minX;
    if (spread <= 0) return null;

    var largestGap = 0.0;
    var splitIndex = -1;
    for (var i = 1; i < horizontal.length; i++) {
      final gap = _centerX(horizontal[i]) - _centerX(horizontal[i - 1]);
      if (gap > largestGap) {
        largestGap = gap;
        splitIndex = i;
      }
    }

    if (splitIndex < 2 || horizontal.length - splitIndex < 2) return null;
    return largestGap >= spread * .28 ? splitIndex : null;
  }

  String _orderWithinColumn(List<OcrTextRegion> regions) {
    final sorted = [...regions]
      ..sort((a, b) {
        final yOrder = _top(a).compareTo(_top(b));
        return yOrder == 0 ? _left(a).compareTo(_left(b)) : yOrder;
      });
    return sorted.map((region) => region.text.trim()).join('\n');
  }

  double _centerX(OcrTextRegion region) => (_left(region) + _right(region)) / 2;

  double _left(OcrTextRegion region) =>
      region.points.map((point) => point.x).reduce(_minDouble);

  double _right(OcrTextRegion region) =>
      region.points.map((point) => point.x).reduce(_maxDouble);

  double _top(OcrTextRegion region) =>
      region.points.map((point) => point.y).reduce(_minDouble);
}
