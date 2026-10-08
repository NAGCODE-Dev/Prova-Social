/// Universal-ish exam/question parser.
///
/// Structural uncertainty is kept on the resulting question for human review;
/// detected candidates are not silently discarded because their format differs.
class ImportedQuestion {
  ImportedQuestion({
    required this.statement,
    required this.options,
    this.correctIndex,
    this.number,
    this.format = QuestionFormat.multipleChoice,
    this.confidence = 1,
    this.warning,
    QuestionReviewState? reviewState,
    this.versionLabel = 'Versão principal',
    List<ImportedQuestionVersion>? alternateVersions,
  }) : reviewState =
           reviewState ??
           (confidence < .85 || warning != null
               ? QuestionReviewState.needsAttention
               : QuestionReviewState.unreviewed),
       alternateVersions = alternateVersions ?? <ImportedQuestionVersion>[];

  String statement;
  List<String> options;
  int? correctIndex;
  int? number;
  QuestionFormat format;
  double confidence;
  String? warning;
  QuestionReviewState reviewState;
  String versionLabel;
  final List<ImportedQuestionVersion> alternateVersions;

  void selectAlternateVersion(int index) {
    if (index < 0 || index >= alternateVersions.length) return;
    final previous = ImportedQuestionVersion(
      label: versionLabel,
      statement: statement,
      options: List.of(options),
      correctIndex: correctIndex,
      format: format,
      confidence: confidence,
      warning: warning,
    );
    final selected = alternateVersions[index];
    statement = selected.statement;
    options = List.of(selected.options);
    correctIndex = selected.correctIndex;
    format = selected.format;
    confidence = selected.confidence;
    warning = selected.warning;
    versionLabel = selected.label;
    reviewState = confidence < .85 || warning != null
        ? QuestionReviewState.needsAttention
        : QuestionReviewState.inReview;
    alternateVersions[index] = previous;
  }

  Map<String, Object?> toJson(int position) => {
    'position': position,
    'statement': statement.trim(),
    'options': options.map((text) => {'text': text.trim()}).toList(),
    'correctIndex': correctIndex,
  };
}

enum QuestionReviewState { unreviewed, inReview, reviewed, needsAttention }

class ImportedQuestionVersion {
  const ImportedQuestionVersion({
    required this.label,
    required this.statement,
    required this.options,
    required this.correctIndex,
    required this.format,
    required this.confidence,
    required this.warning,
  });

  final String label;
  final String statement;
  final List<String> options;
  final int? correctIndex;
  final QuestionFormat format;
  final double confidence;
  final String? warning;

  factory ImportedQuestionVersion.fromJson(Map<String, dynamic> json) =>
      ImportedQuestionVersion(
        label: json['label'] as String? ?? 'Versão alternativa',
        statement: json['statement'] as String? ?? '',
        options: List<String>.from(json['options'] as List? ?? const []),
        correctIndex: json['correctIndex'] as int?,
        format: QuestionFormat.values.firstWhere(
          (format) => format.name == json['format'],
          orElse: () => QuestionFormat.unknown,
        ),
        confidence: ((json['confidence'] as num?)?.toDouble() ?? 0.5)
            .clamp(0, 1)
            .toDouble(),
        warning: json['warning'] as String?,
      );

  Map<String, Object?> toJson() => {
    'label': label,
    'statement': statement,
    'options': options,
    'correctIndex': correctIndex,
    'format': format.name,
    'confidence': confidence,
    'warning': warning,
  };
}

enum QuestionFormat { multipleChoice, trueFalse, assertion, openEnded, unknown }

class QuestionParser {
  const QuestionParser();

  List<ImportedQuestion> parse(String source) {
    final text = _normalize(source);
    if (text.trim().isEmpty) return const [];

    final lines = text.split('\n');
    final candidates = <_QuestionStart>[];
    final seenVariantsByNumber = <int, Set<String>>{};
    final candidateVariantLabels = <int, String>{};
    var currentVariantLabel = 'Versão principal';
    var previousNumber = -1;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final sectionVariant = _languageVariantHeading(line);
      if (sectionVariant != null) {
        currentVariantLabel = sectionVariant;
      } else if (_isMajorSectionHeading(line)) {
        currentVariantLabel = 'Versão principal';
      }
      final hasFollowingOptions = _hasFollowingOptions(lines, i + 1);
      final trueFalseContext = _looksLikeTrueFalse(lines.take(i).join('\n'));
      final hasLeadingGap = i == 0 || lines[i - 1].trim().isEmpty;
      final candidate = _detectQuestionStart(
        line,
        previousNumber,
        lines: lines,
        lineIndex: i,
        hasFollowingOptions: hasFollowingOptions,
        trueFalseContext: trueFalseContext,
        hasLeadingGap: hasLeadingGap,
        seenVariantsByNumber: seenVariantsByNumber,
        currentVariantLabel: currentVariantLabel,
      );
      if (candidate == null) continue;

      // A numeric marker is much more trustworthy when the sequence is
      // coherent or the block eventually contains options.
      if (candidate.number != null) {
        previousNumber = candidate.number!;
        seenVariantsByNumber
            .putIfAbsent(candidate.number!, () => <String>{})
            .add(currentVariantLabel);
        candidateVariantLabels[i] = currentVariantLabel;
      }
      candidates.add(candidate.copyWith(lineIndex: i));
    }

    final questions = <ImportedQuestion>[];
    var inheritedTrueFalse =
        candidates.isNotEmpty &&
        _looksLikeTrueFalse(lines.take(candidates.first.lineIndex).join('\n'));
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
        parsed.versionLabel =
            candidateVariantLabels[candidate.lineIndex] ?? 'Versão principal';
        questions.add(parsed);
        inheritedTrueFalse = parsed.format == QuestionFormat.trueFalse;
      } else if (candidate.explicit) {
        inheritedTrueFalse = false;
      }
    }

    return _coalesceParallelNumberedVersions(questions);
  }

  String? _languageVariantHeading(String line) {
    final heading = line.trim();
    if (RegExp(
      r'^l[ií]ngua\s+espanhola\b',
      caseSensitive: false,
    ).hasMatch(heading)) {
      return 'Espanhol';
    }
    if (RegExp(
      r'^l[ií]ngua\s+inglesa\b',
      caseSensitive: false,
    ).hasMatch(heading)) {
      return 'Inglês';
    }
    if (RegExp(
      r'^l[ií]ngua\s+portuguesa\b',
      caseSensitive: false,
    ).hasMatch(heading)) {
      return 'Português';
    }
    return null;
  }

  bool _isMajorSectionHeading(String line) {
    final heading = line.trim();
    if (heading.length < 8 || heading != heading.toUpperCase()) return false;
    return RegExp(r'[A-ZÁÉÍÓÚÂÊÔÃÕÇ]{3}').hasMatch(heading);
  }

  List<ImportedQuestion> _coalesceParallelNumberedVersions(
    List<ImportedQuestion> questions,
  ) {
    final counts = <int, int>{};
    for (final question in questions) {
      final number = question.number;
      if (number != null) {
        counts.update(number, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final repeated =
        counts.entries
            .where((entry) => entry.value > 1)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    // Repeated numbering alone is ambiguous. Coalesce only a run of at least
    // three consecutive repeated IDs, the common signature of parallel
    // language/booklet tracks. Isolated duplicates remain visible to QA.
    final parallelNumbers = <int>{};
    var run = <int>[];
    for (final number in repeated) {
      if (run.isEmpty || number == run.last + 1) {
        run.add(number);
      } else {
        if (run.length >= 3) parallelNumbers.addAll(run);
        run = [number];
      }
    }
    if (run.length >= 3) parallelNumbers.addAll(run);
    if (parallelNumbers.isEmpty) return questions;

    final primaryByNumber = <int, ImportedQuestion>{};
    final result = <ImportedQuestion>[];
    for (final question in questions) {
      final number = question.number;
      if (number == null || !parallelNumbers.contains(number)) {
        result.add(question);
        continue;
      }
      final primary = primaryByNumber[number];
      if (primary == null) {
        primaryByNumber[number] = question;
        result.add(question);
        continue;
      }
      primary.alternateVersions.add(
        ImportedQuestionVersion(
          label: question.versionLabel == primary.versionLabel
              ? 'Versão alternativa ${primary.alternateVersions.length + 1}'
              : question.versionLabel,
          statement: question.statement,
          options: List.unmodifiable(question.options),
          correctIndex: question.correctIndex,
          format: question.format,
          confidence: question.confidence,
          warning: question.warning,
        ),
      );
    }
    return result;
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

  bool _hasFollowingOptions(List<String> lines, int start) {
    if (start >= lines.length) return false;
    final followingLines = <String>[];
    final end = (start + 80).clamp(0, lines.length);
    for (var index = start; index < end; index++) {
      if (index > start && RegExp(r'^\s*\d{1,3}\s*$').hasMatch(lines[index])) {
        break;
      }
      followingLines.add(lines[index]);
      final scan = _findOptionMarkers(followingLines.join('\n'));
      if (scan.markers.length >= 2 || scan.rawMarkerCount >= 2) return true;
    }
    return false;
  }

  bool _hasQuestionBodyAfter(List<String> lines, int lineIndex) {
    for (var index = lineIndex + 1; index < lines.length; index++) {
      final candidate = lines[index].trim();
      if (candidate.isEmpty) continue;
      if (RegExp(r'^\d{1,3}$').hasMatch(candidate) ||
          _findOptionMarkers(candidate).rawMarkerCount > 0) {
        return false;
      }
      return candidate.length >= 4;
    }
    return false;
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

  _QuestionStart? _detectQuestionStart(
    String line,
    int previousNumber, {
    required List<String> lines,
    required int lineIndex,
    required bool hasFollowingOptions,
    required bool trueFalseContext,
    required bool hasLeadingGap,
    required Map<int, Set<String>> seenVariantsByNumber,
    required String currentVariantLabel,
  }) {
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
      r'^\s*(\d{1,4})\s*[ªº°]\s*quest(?:ão|ao)\s*[:.\-]?\s*(.*)$',
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

    // Section labels such as “39 a 44” and “Questions 39 to 44” are ranges,
    // not question starts. They otherwise look sequential and can swallow the
    // passage that precedes a language-specific question track.
    if (RegExp(
      r'^\s*\d{1,4}\s+(?:a|até|to|through|hasta)\s+\d{1,4}[.:)]?\s*$',
      caseSensitive: false,
    ).hasMatch(line)) {
      return null;
    }

    final bareNumber = RegExp(r'^\s*(\d{1,4})[.)]?\s*$').firstMatch(line);
    final bareQuestionNumber = int.tryParse(bareNumber?.group(1) ?? '');
    final followsQuestionNumber =
        bareQuestionNumber != null && bareQuestionNumber == previousNumber + 1;
    final hasQuestionBody = _hasQuestionBodyAfter(lines, lineIndex);
    if (bareNumber != null &&
        ((followsQuestionNumber && (hasQuestionBody || hasFollowingOptions)) ||
            (hasFollowingOptions &&
                (previousNumber < 0 ||
                    hasLeadingGap ||
                    (currentVariantLabel != 'Versão principal' &&
                        seenVariantsByNumber[bareQuestionNumber]?.any(
                              (label) => label != currentVariantLabel,
                            ) ==
                            true))))) {
      return _QuestionStart(
        lineIndex: -1,
        number: int.tryParse(bareNumber.group(1)!),
        content: '',
        confidence: .86,
        explicit: false,
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
    final hasQuestionPunctuation =
        rest.contains('?') ||
        RegExp(
          r'^(?:qual|quais|como|por que|porque|assinale|considere|analise|leia|sobre|julgue)\b',
          caseSensitive: false,
        ).hasMatch(rest);

    final hasBlockEvidence =
        hasFollowingOptions && (previousNumber < 0 || hasLeadingGap);
    if (!sequential &&
        !hasQuestionPunctuation &&
        !hasBlockEvidence &&
        !trueFalseContext) {
      return null;
    }

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
    if (content.trim().length < 4) return _uncertainQuestion(content, start);

    final optionScan = _findOptionMarkers(content);
    if (optionScan.markers.length >= 2) {
      final parsed = _parseOptions(content, optionScan.markers);
      if (parsed == null) return _uncertainQuestion(content, start);
      final statement = _cleanStatement(parsed.statement);
      if (!_plausibleStatement(statement)) {
        return _uncertainQuestion(content, start);
      }
      final warnings = <String>[];
      if (parsed.options.length < 4) {
        warnings.add(
          'Foram detectadas ${parsed.options.length} alternativas; revisar estrutura.',
        );
      } else if (parsed.options.length > 5) {
        warnings.add(
          'Estrutura incomum: ${parsed.options.length} alternativas preservadas.',
        );
      }
      if (optionScan.hasIncoherentMarkers) {
        warnings.add(
          'Marcadores de alternativas incompletos ou fora de ordem.',
        );
      }
      return ImportedQuestion(
        statement: statement,
        options: parsed.options,
        number: start.number,
        format: QuestionFormat.multipleChoice,
        confidence: _optionConfidence(
          start,
          parsed.options.length,
          hasIncoherentMarkers: optionScan.hasIncoherentMarkers,
        ),
        warning: warnings.isEmpty ? null : warnings.join(' '),
      );
    }

    if (_looksLikeTrueFalse(content) || inheritedTrueFalse) {
      final statement = _cleanTrueFalseStatement(content);
      if (statement.length < 8) return _uncertainQuestion(statement, start);
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

    if (_looksLikeOpenEnded(content)) {
      return ImportedQuestion(
        statement: _cleanStatement(content),
        options: const [],
        number: start.number,
        format: QuestionFormat.openEnded,
        confidence: .7,
        warning: 'Questão discursiva sem alternativas; revisar resposta esperada e critérios.',
      );
    }

    return _uncertainQuestion(content, start);
  }

  ImportedQuestion _uncertainQuestion(String content, _QuestionStart start) {
    final statement = _cleanStatement(content.trim());
    return ImportedQuestion(
      statement: statement,
      options: const [],
      number: start.number,
      format: QuestionFormat.unknown,
      confidence: (start.confidence * .55).clamp(0, 1).toDouble(),
      warning: 'Estrutura não reconhecida completamente; revisar questão e alternativas.',
    );
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

  _OptionScan _findOptionMarkers(String block) {
    final result = <_OptionMarker>[];
    final lines = block.split('\n');
    var offset = 0;

    for (final line in lines) {
      // Unwrapped labels require punctuation so ordinary prose like "A questão"
      // is not mistaken for an alternative. Parenthesized/bracketed and
      // marker-only labels remain supported for image-based alternatives.
      final wrapped = RegExp(
        r'^\s*(?:\(([A-Z])\)|\[([A-Z])\])\s*(?:[.):\-–])?\s*(.*?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final unwrapped = RegExp(
        r'^\s*([A-Z])\s*[.):\-–]\s*(.*?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final markerOnly = RegExp(
        r'^\s*([A-Z])\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final unwrappedText = RegExp(
        r'^\s*([A-Z])\s+(.+?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      final letter =
          wrapped?.group(1) ??
          wrapped?.group(2) ??
          unwrapped?.group(1) ??
          markerOnly?.group(1) ??
          unwrappedText?.group(1);
      final optionText =
          wrapped?.group(3) ??
          unwrapped?.group(2) ??
          unwrappedText?.group(2) ??
          '';
      final markerMatch = wrapped ?? unwrapped ?? markerOnly ?? unwrappedText;
      if (letter != null && markerMatch != null) {
        final normalizedLetter = letter.toUpperCase();
        final contentStart = optionText.isEmpty
            ? line.length
            : line.indexOf(optionText);
        result.add(
          _OptionMarker(
            start: offset,
            contentStart: offset + contentStart,
            letter: normalizedLetter,
            text: optionText.trim(),
            requiresSequence: unwrappedText != null,
          ),
        );
      }
      offset += line.length + 1;
    }

    final sequenceFiltered = <_OptionMarker>[];
    var unwrappedRun = <_OptionMarker>[];
    void flushUnwrappedRun() {
      if (unwrappedRun.length >= 3) sequenceFiltered.addAll(unwrappedRun);
      unwrappedRun = [];
    }

    for (final marker in result) {
      if (!marker.requiresSequence) {
        flushUnwrappedRun();
        sequenceFiltered.add(marker);
        continue;
      }
      if (unwrappedRun.isNotEmpty &&
          marker.letter.codeUnitAt(0) !=
              unwrappedRun.last.letter.codeUnitAt(0) + 1) {
        flushUnwrappedRun();
      }
      unwrappedRun.add(marker);
    }
    flushUnwrappedRun();
    result
      ..clear()
      ..addAll(sequenceFiltered);

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

    final coherent = _coherentOptions(result);
    var expectedLabel = 'A'.codeUnitAt(0);
    final hasLabelGap =
        coherent.any((marker) {
          final label = marker.letter.codeUnitAt(0);
          final isGap = label != expectedLabel;
          expectedLabel = label + 1;
          return isGap;
        }) ||
        (coherent.isNotEmpty && coherent.first.letter != 'A');
    return _OptionScan(
      markers: coherent,
      rawMarkerCount: result.length,
      hasIncoherentMarkers: coherent.length != result.length || hasLabelGap,
    );
  }

  List<_OptionMarker> _coherentOptions(List<_OptionMarker> markers) {
    if (markers.length < 2) return const [];
    final output = <_OptionMarker>[markers.first];
    var previous = markers.first.letter.codeUnitAt(0);
    for (var i = 1; i < markers.length; i++) {
      final code = markers[i].letter.codeUnitAt(0);
      if (code > previous) {
        output.add(markers[i]);
        previous = code;
      } else if (code == 'A'.codeUnitAt(0) && previous >= 'E'.codeUnitAt(0)) {
        output.add(markers[i]);
        previous = code;
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

  double _optionConfidence(
    _QuestionStart start,
    int count, {
    required bool hasIncoherentMarkers,
  }) {
    var score = start.confidence;
    if (count >= 4 && count <= 5) score += .05;
    if (count < 4 || count > 5) score -= .1;
    if (hasIncoherentMarkers) score -= .15;
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

  bool _looksLikeOpenEnded(String content) => RegExp(
    r'\b(redija|discorra|elabore|descreva|explique|responda|justifique)\b',
    caseSensitive: false,
  ).hasMatch(content);

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
    this.requiresSequence = false,
  });

  final int start;
  final int contentStart;
  final String letter;
  final String text;
  final bool requiresSequence;
}

class _ParsedOptions {
  const _ParsedOptions({required this.statement, required this.options});

  final String statement;
  final List<String> options;
}

class _OptionScan {
  const _OptionScan({
    required this.markers,
    required this.rawMarkerCount,
    required this.hasIncoherentMarkers,
  });

  final List<_OptionMarker> markers;
  final int rawMarkerCount;
  final bool hasIncoherentMarkers;
}
