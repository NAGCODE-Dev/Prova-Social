import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/local_exam_store.dart';
import '../../core/backend/attempt_sync_service.dart';
import '../auth/auth_page.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/backend/exam_publication_service.dart';
import '../../core/import/pdf_text_extractor.dart';
import '../../core/import/import_quality_gate.dart';
import '../../core/import/question_parser.dart';
import '../../core/import/exam_metadata_suggester.dart';
import '../../core/theme/app_theme.dart';

class PublishPage extends StatelessWidget {
  const PublishPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Criar e compartilhar',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Escolha como o material entra. Você revisa tudo antes de publicar.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final options = [
                    _PublishChoice(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'Importar PDF',
                      description: 'Extraia texto e figuras, confira as questões e publique.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PdfImportPage(),
                        ),
                      ),
                    ),
                    _PublishChoice(
                      icon: Icons.data_object_rounded,
                      title: 'Importar JSON',
                      description: 'Use um arquivo já estruturado no formato Prova Social.',
                      onTap: () => _importJson(context),
                    ),
                    _PublishChoice(
                      icon: Icons.edit_note_rounded,
                      title: 'Criar manualmente',
                      description:
                          'Monte questões e alternativas usando o editor.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ImportReviewPage(
                            title: '',
                            category: '',
                            source: '',
                            durationMinutes: 0,
                            questions: [],
                          ),
                        ),
                      ),
                    ),
                  ];
                  return Column(
                    children: options
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: item,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              const _PrivacyNote(),
            ],
          ),
        ),
      ),
    ],
  );

  static Future<void> _importJson(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final length = file.lengthSync() ?? await file.length();
      if (length != null && length > 4 * 1024 * 1024) {
        throw const FormatException('Limite: 4 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        throw const FormatException('Limite: 4 MB.');
      }
      final data = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      data['id'] = 'local-${AttemptSyncService.newClientAttemptId()}';
      data['pendingPublication'] = false;
      final exam = LocalExam.fromJson(data);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImportReviewPage(
            title: exam.title,
            category: exam.category,
            source: exam.source,
            sourceUrl: exam.sourceUrl,
            durationMinutes: exam.durationMinutes,
            year: exam.year,
            questions: exam.questions,
            localId: exam.id,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível importar. Use um JSON exportado pelo editor Prova Social (até 4 MB).',
            ),
          ),
        );
      }
    }
  }
}

class _PublishChoice extends StatelessWidget {
  const _PublishChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

class PdfImportPage extends StatefulWidget {
  const PdfImportPage({super.key});

  @override
  State<PdfImportPage> createState() => _PdfImportPageState();
}

class _PdfImportPageState extends State<PdfImportPage> {
  PlatformFile? file;
  int fileSize = 0;
  bool selecting = false;

  Future<void> pickPdf() async {
    setState(() => selecting = true);
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (selected != null) {
        final selectedSize =
            selected.lengthSync() ?? await selected.length() ?? 0;
        if (selectedSize > 25 * 1024 * 1024) {
          throw const FormatException('O PDF excede o limite de 25 MB.');
        }
        if (mounted) {
          setState(() {
            file = selected;
            fileSize = selectedSize;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o PDF. Escolha um arquivo de até 25 MB e tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Importar prova em PDF')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ImportSteps(current: 0),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Escolha o arquivo',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'O PDF será usado para extrair texto. Confira enunciados e alternativas; imagens do arquivo ainda não são importadas.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  button: true,
                  label: 'Selecionar arquivo PDF',
                  child: InkWell(
                    onTap: selecting ? null : pickPdf,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 144),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: file == null
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.primary,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: AnimatedSwitcher(
                        duration: AppMotion.of(context, AppMotion.fast),
                        child: selecting
                            ? const Column(
                                key: ValueKey('selecting'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: AppSpacing.md),
                                  Text('Abrindo seus arquivos…'),
                                ],
                              )
                            : file == null
                            ? Column(
                                key: const ValueKey('empty'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file_rounded,
                                    size: 36,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Toque para selecionar o PDF',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: AppSpacing.sm),
                                  Text('Limite inicial: 25 MB'),
                                ],
                              )
                            : Column(
                                key: const ValueKey('selected'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 36,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    file!.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(_fileSize(fileSize)),
                                  const SizedBox(height: AppSpacing.md),
                                  const Text('Toque para trocar'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: file == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PdfProcessingPage(file: file!),
                          ),
                        ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Escanear e identificar'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  String _fileSize(int bytes) => bytes < 1048576
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

class PdfProcessingPage extends StatefulWidget {
  const PdfProcessingPage({required this.file, super.key});

  final PlatformFile file;

  @override
  State<PdfProcessingPage> createState() => _PdfProcessingPageState();
}

class _PdfProcessingPageState extends State<PdfProcessingPage> {
  late Future<_ImportResult> work;
  final processingStatus = ValueNotifier<String>('Lendo arquivo');
  final title = TextEditingController();
  final category = TextEditingController();
  final source = TextEditingController();
  final sourceUrl = TextEditingController();
  final year = TextEditingController();
  final duration = TextEditingController(text: '120');
  bool suggestionsApplied = false;

  @override
  void initState() {
    super.initState();
    work = _process();
  }

  @override
  void dispose() {
    title.dispose();
    category.dispose();
    source.dispose();
    sourceUrl.dispose();
    year.dispose();
    duration.dispose();
    processingStatus.dispose();
    super.dispose();
  }

  Future<_ImportResult> _process() async {
    processingStatus.value = 'Lendo arquivo';
    final bytes = await widget.file.readAsBytes();
    processingStatus.value = 'Reconhecendo texto e páginas';
    final extraction = await const PdfTextExtractor().extract(
      bytes,
      sourceName: widget.file.name,
    );
    processingStatus.value = 'Identificando questões e alternativas';
    final questions = const QuestionParser().parsePages(
      extraction.pages.map((page) => page.text).toList(growable: false),
    );
    processingStatus.value = 'Conferindo estrutura e dados da prova';
    const qualityGate = ImportQualityGate();
    qualityGate.markNumberingIssues(questions);
    final quality = qualityGate.assess(extraction, questions);
    final suggestion = suggestExamMetadata(
      fileName: widget.file.name,
      firstPageText: extraction.pages.firstOrNull?.text ?? '',
    );
    return _ImportResult(
      extraction: extraction,
      questions: questions,
      quality: quality,
      suggestion: suggestion,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Digitalizando prova')),
    body: FutureBuilder<_ImportResult>(
      future: work,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            '[PDF_IMPORT] falha ao processar: ${snapshot.error.runtimeType}',
          );
          if (snapshot.stackTrace != null) {
            debugPrint('[PDF_IMPORT] stack: ${snapshot.stackTrace}');
          }
          return _ProcessMessage(
            icon: Icons.error_outline_rounded,
            title: 'Não foi possível ler o PDF',
            text: 'O arquivo pode estar danificado, protegido ou em um formato incompatível. Confira se ele abre normalmente e escolha outro PDF para tentar novamente.',
            action: () => Navigator.pop(context),
            actionLabel: 'Escolher outro arquivo',
          );
        }
        if (!snapshot.hasData) {
          return ValueListenableBuilder<String>(
            valueListenable: processingStatus,
            builder: (context, status, _) => _ProcessMessage(
              icon: Icons.document_scanner_outlined,
              title: status,
              text: 'O arquivo está sendo processado no aparelho. O tempo depende do tamanho e da qualidade do PDF.',
              loading: true,
              loadingLabel: status,
            ),
          );
        }
        final result = snapshot.data!;
        if (result.extraction.looksScanned) {
          return _ProcessMessage(
            icon: Icons.image_search_rounded,
            title: result.extraction.ocrAvailable
                ? 'Não foi possível reconhecer a digitalização'
                : 'OCR disponível no aplicativo Android',
            text: result.extraction.ocrAvailable
                ? 'O OCR foi executado, mas não encontrou texto suficiente. Tente uma digitalização mais nítida, reta e com maior contraste.'
                : 'A versão Web encontrou ${result.extraction.pagesWithText} páginas com texto em ${result.extraction.pageCount}. Abra o PDF no aplicativo móvel para executar o OCR local.',
            action: () => Navigator.pop(context),
            actionLabel: 'Escolher outro arquivo',
          );
        }
        if (result.questions.isEmpty) {
          final diagnosticText = result.quality.diagnostics.isEmpty
              ? ''
              : ' Um padrão estrutural foi identificado localmente; o diagnóstico não envia o texto do arquivo.';
          return _ProcessMessage(
            icon: Icons.rule_folder_outlined,
            title: 'Texto lido, estrutura não reconhecida',
            text:
                'O arquivo possui texto, mas a estrutura das questões não foi reconhecida. Nenhum conteúdo foi publicado.$diagnosticText',
            action: () => Navigator.pop(context),
            actionLabel: 'Voltar',
          );
        }
        final extraction = result.extraction;
        final quality = result.quality;
        if (!suggestionsApplied) {
          title.text = result.suggestion.title;
          year.text = result.suggestion.year?.toString() ?? '';
          suggestionsApplied = true;
        }
        final accepted =
            result.questions.length - quality.questionsNeedingReview;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ImportSteps(current: 1),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Digitalização concluída',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${extraction.pageCount} páginas · ${result.questions.length} questões encontradas · $accepted validadas automaticamente (confiança ≥ 99%) · ${quality.questionsNeedingReview} para conferir.',
                    ),
                    if (quality.reasons.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(quality.reasons.join(' ')),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Confirme os dados identificados',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Título sugerido pelo PDF',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: source,
                      decoration: const InputDecoration(
                        labelText: 'Banca ou origem',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: category,
                      decoration: const InputDecoration(
                        labelText: 'Categoria ou assunto',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: sourceUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link da fonte (opcional)',
                        hintText: 'https://...',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: year,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Ano'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: duration,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duração em minutos',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () {
                        if (title.text.trim().isEmpty ||
                            category.text.trim().isEmpty ||
                            source.text.trim().isEmpty ||
                            !ExamPublicationService.isValidSourceUrl(
                              sourceUrl.text,
                            ) ||
                            (int.tryParse(duration.text) ?? 0) < 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Confirme título, banca, categoria e duração.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => ImportReviewPage(
                              title: title.text.trim(),
                              category: category.text.trim(),
                              source: source.text.trim(),
                              sourceUrl: sourceUrl.text.trim(),
                              year: int.tryParse(year.text),
                              durationMinutes:
                                  int.tryParse(duration.text) ?? 120,
                              questions: result.questions,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(
                        quality.questionsNeedingReview == 0
                            ? 'Continuar para revisão da prova'
                            : 'Conferir ${quality.questionsNeedingReview} questões necessárias',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ImportResult {
  const _ImportResult({
    required this.extraction,
    required this.questions,
    required this.quality,
    required this.suggestion,
  });
  final PdfExtractionResult extraction;
  final List<ImportedQuestion> questions;
  final ImportQualityAssessment quality;
  final ExamMetadataSuggestion suggestion;
}

class _ProcessMessage extends StatelessWidget {
  const _ProcessMessage({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.actionLabel,
    this.loading = false,
    this.loadingLabel,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? action;
  final String? actionLabel;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  semanticsLabel: loadingLabel ?? title,
                ),
              )
            else
              Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: action, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}

class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({
    required this.title,
    required this.category,
    required this.source,
    this.sourceUrl,
    required this.durationMinutes,
    required this.questions,
    this.year,
    this.localId,
    this.pendingPublication = false,
    this.reviewIndex = 0,
    super.key,
  });
  final String title, category, source;
  final String? sourceUrl;
  final int durationMinutes;
  final int? year;
  final String? localId;
  final bool pendingPublication;
  final int reviewIndex;
  final List<ImportedQuestion> questions;
  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage>
    with WidgetsBindingObserver {
  late final TextEditingController title,
      category,
      source,
      sourceUrl,
      duration,
      year;
  late final List<ImportedQuestion> questions;
  late final String localId;
  final store = LocalExamStore();
  bool busy = false, canPop = false;
  late bool pendingPublication;
  String status = 'Ainda não salvo';
  int revision = 0;
  int currentQuestionIndex = 0;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pendingPublication = widget.pendingPublication;
    currentQuestionIndex = widget.reviewIndex;
    localId =
        widget.localId ?? 'local-${AttemptSyncService.newClientAttemptId()}';
    title = TextEditingController(text: widget.title);
    category = TextEditingController(text: widget.category);
    source = TextEditingController(text: widget.source);
    sourceUrl = TextEditingController(text: widget.sourceUrl ?? '');
    duration = TextEditingController(
      text: widget.durationMinutes > 0 ? '${widget.durationMinutes}' : '',
    );
    year = TextEditingController(text: widget.year?.toString() ?? '');
    questions = widget.questions
        .map(
          (q) => ImportedQuestion(
            statement: q.statement,
            options: List.of(q.options),
            correctIndex: q.correctIndex,
            number: q.number,
            sourcePage: q.sourcePage,
            format: q.format,
            confidence: q.confidence,
            warning: q.warning,
            reviewState: q.reviewState,
            versionLabel: q.versionLabel,
            alternateVersions: q.alternateVersions
                .map(
                  (version) => ImportedQuestionVersion(
                    label: version.label,
                    statement: version.statement,
                    options: List.of(version.options),
                    correctIndex: version.correctIndex,
                    format: version.format,
                    confidence: version.confidence,
                    warning: version.warning,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    currentQuestionIndex = questions.isEmpty
        ? 0
        : currentQuestionIndex.clamp(0, questions.length - 1);
    if (questions.isNotEmpty) {
      final firstNeedsReview = questions.indexWhere(
        (question) => question.reviewState != QuestionReviewState.reviewed,
      );
      currentQuestionIndex = firstNeedsReview < 0 ? 0 : firstNeedsReview;
      if (questions[currentQuestionIndex].reviewState ==
          QuestionReviewState.unreviewed) {
        questions[currentQuestionIndex].reviewState =
            QuestionReviewState.inReview;
      }
    }
    for (final controller in [
      title,
      category,
      source,
      sourceUrl,
      duration,
      year,
    ]) {
      controller.addListener(() => _changed(debounce: true));
    }
    // Imported content becomes recoverable immediately, without an upload.
    if (questions.isNotEmpty || title.text.isNotEmpty) unawaited(_save());
    if (pendingPublication &&
        Supabase.instance.client.auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_publish());
      });
    }
  }

  LocalExam _snapshot() => LocalExam(
    id: localId,
    title: title.text,
    category: category.text,
    source: source.text,
    sourceUrl: sourceUrl.text.trim().isEmpty ? null : sourceUrl.text.trim(),
    durationMinutes: int.tryParse(duration.text) ?? 0,
    year: int.tryParse(year.text),
    questions: questions,
    pendingPublication: pendingPublication,
    reviewIndex: currentQuestionIndex,
  );
  void _changed({bool debounce = false}) {
    revision++;
    setState(() => status = 'Salvando no aparelho…');
    _saveDebounce?.cancel();
    if (debounce) {
      _saveDebounce = Timer(const Duration(milliseconds: 150), () {
        unawaited(_save());
      });
    } else {
      _saveDebounce = null;
      unawaited(_save());
    }
  }

  void _questionEdited(ImportedQuestion question, {bool debounce = false}) {
    if (question.reviewState == QuestionReviewState.reviewed) {
      question.reviewState = QuestionReviewState.inReview;
    }
    _changed(debounce: debounce);
  }

  Future<bool> _save({bool? pending}) async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (pending != null) pendingPublication = pending;
    final savedRevision = revision;
    try {
      await store.save(_snapshot());
      if (mounted && savedRevision == revision) {
        setState(() => status = 'Salvo no aparelho');
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('[LOCAL_SAVE] ERRO: ${error.runtimeType}');
      debugPrint('[LOCAL_SAVE] STACK: $stackTrace');
      if (mounted) {
        setState(
          () =>
              status = 'Falha ao salvar. Tente novamente ou exporte uma cópia.',
        );
      }
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_save());
    }
  }

  Future<void> _exit() async {
    if (busy || !mounted) return;
    if (!await _save() && mounted) {
      var hasSavedVersion = false;
      try {
        hasSavedVersion = (await store.load()).any(
          (exam) => exam.id == localId,
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[LOCAL_SAVE_EXIT] versão anterior indisponível: ${error.runtimeType}',
        );
        debugPrint('[LOCAL_SAVE_EXIT] stack: $stackTrace');
      }
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Não foi possível salvar'),
          content: Text(
            hasSavedVersion
                ? 'A última versão salva continua no aparelho. Você pode exportar as alterações atuais ou sair mantendo essa versão.'
                : 'Ainda não há uma versão salva desta prova. Exporte uma cópia antes de sair se quiser preservar as alterações atuais.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'stay'),
              child: const Text('Continuar editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'export'),
              child: const Text('Exportar cópia'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'exit'),
              child: Text(
                hasSavedVersion
                    ? 'Sair com a última versão salva'
                    : 'Sair sem salvar',
              ),
            ),
          ],
        ),
      );
      if (choice == 'export') await _export();
      if (choice == 'exit' && mounted) {
        setState(() => canPop = true);
        Navigator.of(context).pop();
      }
      return;
    }
    if (!mounted) return;
    setState(() => canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in [
      title,
      category,
      source,
      sourceUrl,
      duration,
      year,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _export() async {
    try {
      final exam = _snapshot();
      final contents = const JsonEncoder.withIndent('  ')
          .convert(exam.toJson());
      final safeName = exam.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final fileName = '${safeName.isEmpty ? 'prova-social' : safeName}.json';
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: utf8.encode('$contents\n'),
        mimeType: 'application/json',
        dialogTitle: 'Salvar prova em JSON',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved == null
                  ? 'Salvamento cancelado.'
                  : 'Arquivo JSON salvo. Você pode importá-lo quando quiser.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[LOCAL_EXPORT] ERRO: ${error.runtimeType}');
      debugPrint('[LOCAL_EXPORT] STACK: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar o arquivo. Tente novamente ou copie o JSON pelo menu de opções.',
            ),
          ),
        );
      }
    }
  }

  bool _valid() =>
      title.text.trim().length >= 3 &&
      title.text.trim().length <= 180 &&
      category.text.trim().length >= 2 &&
      category.text.trim().length <= 80 &&
      source.text.trim().length >= 2 &&
      source.text.trim().length <= 160 &&
      ExamPublicationService.isValidSourceUrl(sourceUrl.text) &&
      (int.tryParse(duration.text) ?? 0) > 0 &&
      (int.tryParse(duration.text) ?? 0) <= 1440 &&
      (year.text.isEmpty ||
          (int.tryParse(year.text) != null &&
              int.parse(year.text) >= 1900 &&
              int.parse(year.text) <= 2200)) &&
      questions.isNotEmpty &&
      questions.length <= 300 &&
      questions.every(
        (q) =>
            q.statement.trim().length >= 2 &&
            q.statement.length <= 20000 &&
            q.options.length >= 2 &&
            q.options.length <= 8 &&
            q.options.every((o) => o.trim().isNotEmpty) &&
            q.reviewState == QuestionReviewState.reviewed &&
            q.correctIndex != null &&
            q.correctIndex! >= 0 &&
            q.correctIndex! < q.options.length,
      );
  Future<void> _publish() async {
    if (busy) return;
    if (!_valid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha os dados e o gabarito; confirme as questões que pedem revisão.',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (!await _save(pending: true) || !mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AuthPage(closeAfterAuth: true),
          ),
        );
        if (!mounted || Supabase.instance.client.auth.currentUser == null) {
          return;
        }
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publicar para todos?'),
          content: Text(
            '“${title.text}” ficará visível no catálogo público. Confirme que pode compartilhar este conteúdo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter privada'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publicar para todos'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        await _save(pending: false);
        return;
      }
      if (!mounted) return;
      await ExamPublicationService().publish(
        title: title.text,
        category: category.text,
        source: source.text,
        sourceUrl: sourceUrl.text,
        durationMinutes: int.parse(duration.text),
        year: int.tryParse(year.text),
        questions: questions,
      );
      await _save(pending: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prova publicada. A cópia local foi preservada.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[PUBLICATION] ERRO: ${error.runtimeType}');
      debugPrint('[PUBLICATION] STACK: $stackTrace');
      if (mounted) {
        final message =
            error is PostgrestException &&
                error.code == 'PGRST202' &&
                sourceUrl.text.trim().isNotEmpty
            ? 'O servidor ainda não foi atualizado para salvar o link da fonte. Sua prova continua salva no aparelho; tente novamente após a atualização.'
            : 'Não foi possível publicar. Sua prova continua salva no aparelho.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Privada neste aparelho. Limpar dados ou desinstalar pode apagar suas provas. Exporte uma cópia. Não há sincronização de provas privadas.',
      ),
      const SizedBox(height: 12),
      Text(status, semanticsLabel: status),
      if (status.startsWith('Falha'))
        TextButton(
          onPressed: _save,
          child: const Text('Tentar salvar novamente'),
        ),
      for (final field in [
        (title, 'Título'),
        (category, 'Concurso / matéria'),
        (source, 'Banca ou origem'),
        (duration, 'Duração em minutos'),
        (year, 'Ano (opcional)'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextField(
            controller: field.$1,
            enabled: !busy,
            decoration: InputDecoration(labelText: field.$2),
          ),
        ),
    ],
  );

  List<String> get _importedVersionLabels {
    final labels = <String>{};
    for (final question in questions) {
      if (question.alternateVersions.isEmpty) continue;
      labels.add(question.versionLabel);
      labels.addAll(question.alternateVersions.map((version) => version.label));
    }
    labels.removeWhere(
      (label) =>
          label == 'Versão principal' || label.startsWith('Versão alternativa'),
    );
    return labels.toList();
  }

  Widget _versionChoice() {
    final labels = _importedVersionLabels;
    final affected = questions.where(
      (question) =>
          question.alternateVersions.isNotEmpty &&
          (labels.contains(question.versionLabel) ||
              question.alternateVersions.any(
                (version) => labels.contains(version.label),
              )),
    );
    if (labels.length < 2 || affected.isEmpty) return const SizedBox.shrink();
    final current = affected.first.versionLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${affected.length} questões têm versões em mais de um idioma.'),
          DropdownButtonFormField<String>(
            key: ValueKey('global-language-$current'),
            initialValue: labels.contains(current) ? current : labels.first,
            decoration: const InputDecoration(
              labelText: 'Idioma das versões alternativas',
            ),
            items: [
              for (final label in labels)
                DropdownMenuItem(value: label, child: Text(label)),
            ],
            onChanged: busy
                ? null
                : (label) {
                    if (label == null) return;
                    for (final question in questions) {
                      if (question.versionLabel == label) continue;
                      final version = question.alternateVersions.indexWhere(
                        (item) => item.label == label,
                      );
                      if (version >= 0) {
                        question.selectAlternateVersion(version);
                      }
                    }
                    _changed();
                  },
          ),
        ],
      ),
    );
  }

  Widget _reviewProgress() {
    final total = questions.length;
    final reviewed = questions
        .where(
          (question) => question.reviewState == QuestionReviewState.reviewed,
        )
        .length;
    final needingReview = questions
        .where(
          (question) => question.reviewState != QuestionReviewState.reviewed,
        )
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Questão ${total == 0 ? 0 : currentQuestionIndex + 1} de $total',
                ),
              ),
              Text('$reviewed revisadas'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: total == 0 ? 0 : reviewed / total),
          const SizedBox(height: 8),
          Text(
            '$needingReview para conferir · questões com confiança de 99% ou mais já foram validadas automaticamente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  total == 0
                      ? 'Sem questões'
                      : _reviewStateLabel(
                          questions[currentQuestionIndex].reviewState,
                        ),
                ),
              ),
              TextButton.icon(
                onPressed: total == 0 ? null : _showQuestionPicker,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Ir para questão'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reviewStateLabel(QuestionReviewState state) => switch (state) {
    QuestionReviewState.unreviewed => 'Ainda não revisada',
    QuestionReviewState.inReview => 'Em revisão',
    QuestionReviewState.reviewed => 'Revisada',
    QuestionReviewState.needsAttention => 'Precisa de atenção',
  };

  Future<void> _showQuestionPicker() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Escolha uma questão',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final state = questions[index].reviewState;
                    final marker = switch (state) {
                      QuestionReviewState.reviewed => '✓',
                      QuestionReviewState.needsAttention => '!',
                      QuestionReviewState.inReview => '◉',
                      QuestionReviewState.unreviewed => '○',
                    };
                    return OutlinedButton(
                      onPressed: () => Navigator.pop(context, index),
                      child: Text('${index + 1} $marker'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      currentQuestionIndex = selected;
      if (questions[selected].reviewState == QuestionReviewState.unreviewed) {
        questions[selected].reviewState = QuestionReviewState.inReview;
      }
    });
    _changed();
  }

  void _moveQuestion(int delta) {
    if (questions.isEmpty) return;
    var next = currentQuestionIndex + delta;
    while (next >= 0 &&
        next < questions.length &&
        questions[next].reviewState == QuestionReviewState.reviewed) {
      next += delta;
    }
    if (next < 0 || next >= questions.length || next == currentQuestionIndex) {
      return;
    }
    setState(() {
      currentQuestionIndex = next;
      if (questions[next].reviewState == QuestionReviewState.unreviewed) {
        questions[next].reviewState = QuestionReviewState.inReview;
      }
    });
    _changed();
  }

  Widget _questionNavigation() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed:
                questions
                    .take(currentQuestionIndex)
                    .any((q) => q.reviewState != QuestionReviewState.reviewed)
                ? () => _moveQuestion(-1)
                : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Anterior'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed:
                questions
                    .skip(currentQuestionIndex + 1)
                    .any((q) => q.reviewState != QuestionReviewState.reviewed)
                ? () => _moveQuestion(1)
                : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Próxima'),
          ),
        ),
      ],
    ),
  );

  Widget _question(int index) {
    final question = questions[index];
    return Card(
      key: ObjectKey(question),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Questão ${index + 1}')),
                IconButton(
                  tooltip: 'Remover questão ${index + 1}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy
                      ? null
                      : () {
                          questions.removeAt(index);
                          if (questions.isEmpty) {
                            currentQuestionIndex = 0;
                          } else if (index < currentQuestionIndex) {
                            currentQuestionIndex--;
                          } else if (currentQuestionIndex >= questions.length) {
                            currentQuestionIndex = questions.length - 1;
                          }
                          if (questions.isNotEmpty) {
                            questions[currentQuestionIndex].reviewState =
                                QuestionReviewState.inReview;
                          }
                          _changed();
                        },
                ),
              ],
            ),
            if (question.sourcePage case final page?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Origem: página $page do arquivo importado',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (question.alternateVersions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<int>(
                  key: ValueKey(
                    'question-version-$index-${question.versionLabel}',
                  ),
                  initialValue: 0,
                  decoration: const InputDecoration(
                    labelText: 'Versão do enunciado',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(question.versionLabel),
                    ),
                    for (
                      var version = 0;
                      version < question.alternateVersions.length;
                      version++
                    )
                      DropdownMenuItem(
                        value: version + 1,
                        child: Text(question.alternateVersions[version].label),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value == null || value == 0) return;
                          question.selectAlternateVersion(value - 1);
                          _changed();
                        },
                ),
              ),
            if (question.confidence < autoValidatedQuestionConfidence ||
                question.warning != null ||
                question.reviewState != QuestionReviewState.reviewed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.confidence < autoValidatedQuestionConfidence ||
                              question.warning != null
                          ? 'Conferir extração · confiança ${(question.confidence * 100).round()}%'
                          : question.reviewState == QuestionReviewState.inReview
                          ? 'Alteração pendente de confirmação manual'
                          : 'Confirmação manual necessária',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (question.warning case final warning?) Text(warning),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    busy || question.reviewState == QuestionReviewState.reviewed
                    ? null
                    : () {
                        question.reviewState = QuestionReviewState.reviewed;
                        _changed();
                      },
                icon: Icon(
                  question.reviewState == QuestionReviewState.reviewed
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  question.reviewState == QuestionReviewState.reviewed
                      ? 'Questão revisada'
                      : 'Marcar questão como revisada',
                ),
              ),
            ),
            TextFormField(
              key: ObjectKey(question),
              initialValue: question.statement,
              enabled: !busy,
              minLines: 2,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Enunciado'),
              onChanged: (value) {
                question.statement = value;
                _questionEdited(question, debounce: true);
              },
            ),
            for (var option = 0; option < question.options.length; option++)
              Row(
                children: [
                  IconButton(
                    tooltip:
                        'Marcar alternativa ${String.fromCharCode(65 + option)} como correta',
                    onPressed: busy
                        ? null
                        : () {
                            question.correctIndex = option;
                            _questionEdited(question);
                          },
                    icon: Icon(
                      question.correctIndex == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey(
                        '${identityHashCode(question)}-$option-${question.options.length}',
                      ),
                      initialValue: question.options[option],
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText:
                            'Alternativa ${String.fromCharCode(65 + option)}',
                      ),
                      onChanged: (value) {
                        question.options[option] = value;
                        _questionEdited(question, debounce: true);
                      },
                    ),
                  ),
                  if (question.options.length > 2)
                    IconButton(
                      tooltip:
                          'Remover alternativa ${String.fromCharCode(65 + option)}',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: busy
                          ? null
                          : () {
                              final correct = question.correctIndex;
                              question.options.removeAt(option);
                              if (correct == option) {
                                question.correctIndex = null;
                              } else if (correct != null && correct > option) {
                                question.correctIndex = correct - 1;
                              }
                              _questionEdited(question);
                            },
                    ),
                ],
              ),
            if (question.options.length < 8)
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        question.options.add('');
                        _questionEdited(question);
                      },
                child: const Text('Adicionar alternativa'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _footer() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: busy || questions.length >= 300
            ? null
            : () {
                questions.add(
                  ImportedQuestion(
                    statement: '',
                    options: ['', ''],
                    confidence: 0,
                  ),
                );
                currentQuestionIndex = questions.length - 1;
                questions[currentQuestionIndex].reviewState =
                    QuestionReviewState.inReview;
                _changed();
              },
        icon: const Icon(Icons.add),
        label: const Text('Adicionar questão'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                if (await _save(pending: false) && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prova privada salva na biblioteca local.'),
                    ),
                  );
                }
              },
        child: const Text('Salvar só para mim'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: busy ? null : _publish,
        child: Text(busy ? 'Aguarde…' : 'Publicar para todos — requer conta'),
      ),
      ExpansionTile(
        initiallyExpanded: sourceUrl.text.isNotEmpty,
        title: const Text('Adicionar link da fonte (opcional)'),
        tilePadding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: sourceUrl,
              enabled: !busy,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://...',
                helperText: 'O link será salvo junto da procedência da prova.',
              ),
            ),
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_exit());
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Editar e revisar prova'),
        actions: [
          IconButton(
            tooltip: 'Exportar JSON',
            onPressed: _export,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(),
              _versionChoice(),
              _reviewProgress(),
              if (questions.isNotEmpty) _question(currentQuestionIndex),
              _questionNavigation(),
              _footer(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ImportSteps extends StatelessWidget {
  const _ImportSteps({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    const labels = ['Arquivo', 'Identificação', 'Processamento', 'Revisão'];
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= current;
        return Expanded(
          child: Column(
            children: [
              Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index == labels.length - 1 ? 0 : 4,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                labels[index],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 20, color: muted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Rascunhos ficam privados. Uma prova só aparece para a comunidade depois da revisão e publicação.',
            style: TextStyle(color: muted),
          ),
        ),
      ],
    );
  }
}
