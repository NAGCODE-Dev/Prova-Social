class ImportedQuestion {
  ImportedQuestion({
    required this.statement,
    required this.options,
    this.correctIndex,
  });

  String statement;
  List<String> options;
  int? correctIndex;

  Map<String, Object?> toJson(int position) => {
        'position': position,
        'statement': statement.trim(),
        'options': options.map((text) => {'text': text.trim()}).toList(),
        'correctIndex': correctIndex,
      };
}

class QuestionParser {
  const QuestionParser();

  List<ImportedQuestion> parse(String source) {
    final normalized = source
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
    final starts = RegExp(
      r'(?m)^\s*(?:quest[aã]o\s*)?(\d{1,3})\s*(?:[.:–)]|-)+\s*',
      caseSensitive: false,
    ).allMatches(normalized).toList();
    final questions = <ImportedQuestion>[];
    for (var index = 0; index < starts.length; index++) {
      final start = starts[index].end;
      final end = index + 1 < starts.length ? starts[index + 1].start : normalized.length;
      final parsed = _parseBlock(normalized.substring(start, end));
      if (parsed != null) {
        questions.add(parsed);
      }
    }
    return questions;
  }

  ImportedQuestion? _parseBlock(String block) {
    final optionPattern = RegExp(
      r'(?m)^\s*(?:\(|\[)?([A-Ea-e])(?:\)|\]|[.:-])\s+',
    );
    final matches = optionPattern.allMatches(block).toList();
    if (matches.length < 2) {
      return null;
    }
    final statement = block.substring(0, matches.first.start).trim();
    if (statement.length < 8) {
      return null;
    }
    final options = <String>[];
    for (var index = 0; index < matches.length; index++) {
      final start = matches[index].end;
      final end = index + 1 < matches.length ? matches[index + 1].start : block.length;
      final text = block.substring(start, end).trim();
      if (text.isNotEmpty) {
        options.add(text);
      }
    }
    if (options.length < 2) {
      return null;
    }
    return ImportedQuestion(statement: statement, options: options.take(5).toList());
  }
}
