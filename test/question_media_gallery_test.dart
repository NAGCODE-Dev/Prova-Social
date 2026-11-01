import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/widgets/question_media_gallery.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  testWidgets('exposes an accessible description for original question media', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final image = (await rootBundle.load('assets/branding/app_icon.png')).buffer
        .asUint8List();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionMediaGallery(
            media: [
              QuestionMedia(
                id: 'media-1',
                objectKey: 'ignored-for-local-bytes',
                mimeType: 'image/png',
                sha256: '',
                altText: 'Diagrama da questão',
                localBytes: image,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Diagrama da questão'), findsOneWidget);
    semantics.dispose();
  });
}
