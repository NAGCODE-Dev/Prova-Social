import 'package:pdfrx/pdfrx.dart';

class OcrService {
  const OcrService();

  bool get isSupported => false;

  Future<String> recognizePage(PdfPage page) async => '';
}
