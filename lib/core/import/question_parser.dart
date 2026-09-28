/// Universal-ish exam/question parser.
///
/// The parser intentionally prefers false negatives over destructive false
/// positives: content that does not confidently look like a question is not
/// silently converted into one, and unusual option counts are preserved.
class ImportedQuestion {
  ImportedQuestion({
    required this.statement,
    required this.options,
    this.correctIndex,
    this.number,
    this.format = QuestionFormat.multipleChoice,
    this.confidence = 1,
    this.warning,
  });

  String statement;
  List<String> options;
  int? correctIndex;
  int? number;
  QuestionFormat format;
  double confidence;
  String? warning;

  Map<String, Object?> toJson(int position) => {
    'position': position,
    'statement': statement.trim(),
    'options': options.map((text) => {'text': text.trim()}).toList(),
    'correctIndex': correctIndex,
  };
}

enum QuestionFormat { multipleChoice, trueFalse, assertion }

class QuestionParser {
  const QuestionParser();

  List<ImportedQuestion> parse(String source) {
    final text = _normalize(source);
    if (text.trim().isEmpty) return const [];

    final lines = text.split('\n');
    final candidates = <_QuestionStart>[];
    var previousNumber = -1;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final candidate = _detectQuestionStart(line, previousNumber);
      if (candidate == null) continue;

      // A numeric marker is much more trustworthy when the sequence is
      // coherent or the block eventually contains options.
      if (candidate.number != null) previousNumber = candidate.number!;
      candidates.add(candidate.copyWith(lineIndex: i));
    }

    final questions = <ImportedQuestion>[];
    var inheritedTrueFalse = false;
    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final nextLine = i + 1 < candidates.length
          ? candidates[i + 1].lineIndex
          : lines.length;
      final block = lines
          .sublist(candidate.lineIndex, nextLine)
          .join('\n')
          .trim();

      final parsed = _parseBlock(
        block,
        candidate,
        inheritedTrueFalse: inheritedTrueFalse,
      );
      if (parsed != null) {
        questions.add(parsed);
        inheritedTrueFalse = parsed.format == QuestionFormat.trueFalse;
      } else if (candidate.explicit) {
        inheritedTrueFalse = false;
      }
    }

    return questions;
  }

  /// Parses independently extracted PDF columns/pages and merges them in the
  /// order supplied by the PDF/layout extractor. This is intentionally kept
  /// separate from [parse], because plain text has no reliable x/y geometry.
  /// A PDF extractor that exposes columns can therefore avoid interleaving
  /// left/right content before this parser sees it.
  List<ImportedQuestion> parseColumns(Iterable<String> columns) {
    final result = <ImportedQuestion>[];
    for (final column in columns) {
      result.addAll(parse(column));
    }
    return result;
  }

  String _normalize(String source) {
    return source
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u200b', '')
        .replaceAll('\u200c', '')
        .replaceAll('\u200d', '')
        .replaceAll('\ufeff', '')
        .replaceAll('\u2010', '-')
        .replaceAll('\u2011', '-')
        .replaceAll('\u2012', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2212', '-')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trimRight())
        .join('\n');
  }

  _QuestionStart? _detectQuestionStart(String line, int previousNumber) {
    final explicit = RegExp(
      r'^\s*(?:quest(?:ão|ao)|q(?:uestão|uestao)?\.?)[ \t]*(?:n[º°.]?[ \t]*)?(\d{1,4})\s*(?:[.:)\-]+)?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (explicit != null) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(explicit.group(1)!),
        content: explicit.group(2)?.trim() ?? '',
        confidence: 1,
        explicit: true,
      );
    }

    final ordinal = RegExp(
      r'^\s*(\d{1,4})\s*[ªº°]\s*(?:quest(?:ão|ao))?\s*[:.\-]?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (ordinal != null) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(ordinal.group(1)!),
        content: ordinal.group(2)?.trim() ?? '',
        confidence: 1,
        explicit: true,
      );
    }

    final compact = RegExp(
      r'^\s*Q\s*(\d{1,4})\s*[.:)\-]?\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (compact != null) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(compact.group(1)!),
        content: compact.group(2)?.trim() ?? '',
        confidence: .98,
        explicit: true,
      );
    }

    // Numeric markers are deliberately conservative. This avoids turning
    // dates, percentages, enumerations, measurements and years into questions.
    final numeric = RegExp(r'^\s*(\d{1,4})(?:\s*[.):-]\s*|\s+)(.*)$')
        .firstMatch(line);
    if (numeric == null) return null;

    final number = int.tryParse(numeric.group(1)!);
    if (number == null || number > 9999) return null;
    final rest = numeric.group(2)?.trim() ?? '';

    final sequential =
        previousNumber >= 0 &&
        (number == previousNumber + 1 || (previousNumber == 0 && number == 1));
    final marker = line.trimLeft().substring(number.toString().length).trim();
    final hasQuestionPunctuation =
        rest.contains('?') ||
        RegExp(
          r'^(?:qual|quais|como|por que|porque|assinale|considere|analise|leia|sobre)\b',
          caseSensitive: false,
        ).hasMatch(rest);

    if (!sequential && !hasQuestionPunctuation && marker.isEmpty) return null;

    return _QuestionStart(
      lineIndex: -1,
      number: number,
      content: rest,
      confidence: sequential ? .94 : .78,
      explicit: false,
    );
  }

  ImportedQuestion? _parseBlock(
    String block,
    _QuestionStart start, {
    bool inheritedTrueFalse = false,
  }) {
    final content = start.content.isEmpty
        ? _removeMarker(block, start)
        : _joinContent(block, start.content);
    if (content.trim().length < 4) return null;

    final optionMatches = _findOptionMarkers(content);
    if (optionMatches.length >= 2) {
      final parsed = _parseOptions(content, optionMatches);
      if (parsed == null) return null;
      final statement = _cleanStatement(parsed.statement);
      if (!_plausibleStatement(statement)) return null;
      final warning = parsed.options.length > 5
          ? 'Estrutura incomum: ${parsed.options.length} alternativas preservadas.'
          : null;
      return ImportedQuestion(
        statement: statement,
        options: parsed.options,
        number: start.number,
        format: QuestionFormat.multipleChoice,
        confidence: _optionConfidence(start, parsed.options.length),
        warning: warning,
      );
    }

    if (_looksLikeTrueFalse(content) || inheritedTrueFalse) {
      final statement = _cleanTrueFalseStatement(content);
      if (statement.length < 8) return null;
      return ImportedQuestion(
        statement: statement,
        options: const ['CERTO', 'ERRADO'],
        number: start.number,
        format: QuestionFormat.trueFalse,
        confidence: .9,
      );
    }

    // Assertion-style blocks may have a command but no A-E alternatives.
    if (_looksLikeAssertion(content)) {
      return ImportedQuestion(
        statement: _cleanStatement(content),
        options: const [],
        number: start.number,
        format: QuestionFormat.assertion,
        confidence: .72,
        warning: 'Questão sem alternativas detectadas; revisar importação.',
      );
    }

    return null;
  }

  String _joinContent(String block, String firstLineContent) {
    final lines = block.split('\n');
    if (lines.isEmpty) return firstLineContent;
    lines[0] = firstLineContent;
    return lines.join('\n').trim();
  }

  String _removeMarker(String block, _QuestionStart start) {
    final lines = block.split('\n');
    if (lines.isNotEmpty) lines.removeAt(0);
    return lines.join('\n').trim();
  }

  List<_OptionMarker> _findOptionMarkers(String block) {
    final result = <_OptionMarker>[];
    final lines = block.split('\n');
    var offset = 0;

    for (final line in lines) {
      // Supports A), A., A:, A-, (A), [A], lowercase and Unicode variants.
      final match = RegExp(
        r'^\s*(?:\(([A-Z])\)|\[([A-Z])\](?=\s)|([A-Z]))\s*(?:[.):\-–])?\s+(.*)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) {
        final letter = (match.group(1) ?? match.group(2) ?? match.group(3)!)
            .toUpperCase();
        result.add(
          _OptionMarker(
            start: offset,
            contentStart:
                offset + match.start + match.group(0)!.indexOf(match.group(4)!),
            letter: letter,
            text: match.group(4)!.trim(),
          ),
        );
      }
      offset += line.length + 1;
    }

    // Also accept inline markers produced by some PDF text extractors, but
    // only when the sequence is coherent (A -> B -> C ...).
    if (result.length < 2) {
      final inline = RegExp(
        r'(?:^|\s)(?:\(([A-Z])\)|([A-Z]))\s*[.):\-–]\s+',
        caseSensitive: false,
      ).allMatches(block).toList();
      if (inline.length >= 2) {
        result
          ..clear()
          ..addAll(
            inline.map(
              (m) => _OptionMarker(
                start: m.start,
                contentStart: m.end,
                letter: (m.group(1) ?? m.group(2)!).toUpperCase(),
                text: '',
              ),
            ),
          );
      }
    }

    return _coherentOptions(result);
  }

  List<_OptionMarker> _coherentOptions(List<_OptionMarker> markers) {
    if (markers.length < 2) return const [];
    final output = <_OptionMarker>[markers.first];
    var expected = markers.first.letter.codeUnitAt(0) + 1;
    for (var i = 1; i < markers.length; i++) {
      final code = markers[i].letter.codeUnitAt(0);
      if (code == expected || (code == 'A'.codeUnitAt(0) && expected > code)) {
        output.add(markers[i]);
        expected = code + 1;
      }
    }
    return output.length >= 2 ? output : const [];
  }

  _ParsedOptions? _parseOptions(String block, List<_OptionMarker> markers) {
    final options = <String>[];
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      final end = i + 1 < markers.length ? markers[i + 1].start : block.length;
      var text = block.substring(marker.contentStart, end).trim();
      if (text.isEmpty) continue;
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      options.add(text);
    }
    if (options.length < 2) return null;

    final statementEnd = markers.first.start;
    final statement = block.substring(0, statementEnd).trim();
    return _ParsedOptions(statement: statement, options: options);
  }

  double _optionConfidence(_QuestionStart start, int count) {
    var score = start.confidence;
    if (count >= 4 && count <= 5) score += .05;
    if (count == 2 || count == 3 || count > 5) score -= .03;
    return score.clamp(0, 1).toDouble();
  }

  bool _plausibleStatement(String statement) {
    if (statement.length < 8) return false;
    if (RegExp(r'^\d+(?:[.,]\d+)?\s*%?$').hasMatch(statement)) return false;
    return true;
  }

  bool _looksLikeTrueFalse(String content) {
    final lower = content.toLowerCase();
    return RegExp(
          r'(julgue|julgar|certo ou errado|certo/errado|verdadeiro ou falso|v ou f|verdadeiro/falso)',
        ).hasMatch(lower) ||
        RegExp(r'\b(certo|errado)\b').allMatches(lower).length >= 2;
  }

  String _cleanTrueFalseStatement(String content) {
    return content
        .replaceFirst(
          RegExp(
            r'^.*?(?:julgue os itens[^.]*\.|julgue o item[^.]*\.)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  bool _looksLikeAssertion(String content) {
    final lower = content.toLowerCase();
    return lower.contains('assertiva:') ||
        lower.contains('situação hipotética:') ||
        lower.contains('situação hipotetica:');
  }

  String _cleanStatement(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([,.;:!?])'), r'\1')
        .trim();
  }
}

class _QuestionStart {
  const _QuestionStart({
    required this.lineIndex,
    required this.number,
    required this.content,
    required this.confidence,
    required this.explicit,
  });

  final int lineIndex;
  final int? number;
  final String content;
  final double confidence;
  final bool explicit;

  _QuestionStart copyWith({int? lineIndex}) => _QuestionStart(
    lineIndex: lineIndex ?? this.lineIndex,
    number: number,
    content: content,
    confidence: confidence,
    explicit: explicit,
  );
}

class _OptionMarker {
  const _OptionMarker({
    required this.start,
    required this.contentStart,
    required this.letter,
    required this.text,
  });

  final int start;
  final int contentStart;
  final String letter;
  final String text;
}

class _ParsedOptions {
  const _ParsedOptions({required this.statement, required this.options});

  final String statement;
  final List<String> options;
}
