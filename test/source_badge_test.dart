import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/home/home_page.dart';

void main() {
  for (final (type, label, icon) in [
    (ExamSourceType.official, 'Fonte oficial', Icons.verified_outlined),
    (ExamSourceType.community, 'Enviado pela comunidade', Icons.people_outline_rounded),
    (ExamSourceType.unverified, 'Fonte não verificada', Icons.help_outline_rounded),
  ]) {
    testWidgets('SourceBadge mostra texto e ícone para ${type.name}', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SourceBadge(sourceType: type)),
      ));
      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
    });
  }

  testWidgets('badge compacto mantém texto e ícone', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SourceBadge(sourceType: ExamSourceType.unverified, compact: true),
      ),
    ));
    expect(find.text('Não verificada'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
  });
}
