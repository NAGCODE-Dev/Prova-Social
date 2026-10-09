class ExamMetadataSuggestion {
  const ExamMetadataSuggestion({required this.title, this.year});

  final String title;
  final int? year;
}

/// Produces a conservative title/year suggestion from a PDF name and its first
/// extracted page. The values are suggestions for the user to confirm.
ExamMetadataSuggestion suggestExamMetadata({
  required String fileName,
  required String firstPageText,
}) {
  final lines = firstPageText
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.length >= 4 && line.length <= 140)
      .where((line) => !_looksLikeNoise(line))
      .take(14)
      .toList(growable: false);

  final titleLine = lines.cast<String?>().firstWhere(
    (line) =>
        line != null &&
        RegExp(
          r'\b(prova|concurso|vestibular|processo seletivo|exame|enem)\b',
          caseSensitive: false,
        ).hasMatch(line),
    orElse: () => null,
  );
  final fromText = titleLine == null ? null : _cleanTitle(titleLine);
  final fromFile = _cleanTitle(
    fileName
        .split(RegExp(r'[/\\]'))
        .last
        .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
  );
  final title = fromText != null && fromText.length >= 6
      ? fromText
      : fromFile.length >= 4
      ? fromFile
      : lines.firstOrNull ?? 'Prova importada';
  final yearMatch = RegExp(r'\b(19\d{2}|20\d{2}|21\d{2})\b')
      .firstMatch('${lines.join(' ')} $fileName');
  return ExamMetadataSuggestion(
    title: title,
    year: int.tryParse(yearMatch?.group(1) ?? ''),
  );
}

bool _looksLikeNoise(String line) =>
    RegExp(
      r'^(p[aá]gina\s+\d+|quest[aã]o\s+\d+|caderno\s+\d+)$',
      caseSensitive: false,
    ).hasMatch(line) ||
    RegExp(r'^[\d\W_]+$').hasMatch(line);

String _cleanTitle(String value) => value
    .replaceAll(RegExp(r'[_-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(
      RegExp(r'\b(c[oó]pia|copy|scan|digitalizado)\b', caseSensitive: false),
      '',
    )
    .trim();
