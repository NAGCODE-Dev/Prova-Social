import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/content_package_service.dart';

void main() {
  test('compacta e restaura JSON sem perder dados', () {
    final service = ContentPackageService();
    final payload = <String, Object?>{
      'schemaVersion': 1,
      'examId': 'exam-1',
      'questions': List.generate(
        80,
        (index) => {
          'position': index + 1,
          'statement': 'Enunciado repetido para compactação eficiente.',
          'options': ['A', 'B', 'C', 'D', 'E'],
        },
      ),
    };

    final package = service.create(payload);
    final restored = service.open(package.bytes);

    expect(restored['examId'], 'exam-1');
    expect((restored['questions'] as List).length, 80);
    expect(package.bytes.length, lessThan(package.uncompressedBytes));
    expect(package.sha256, hasLength(64));
  });
}
