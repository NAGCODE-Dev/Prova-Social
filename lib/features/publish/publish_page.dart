import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/local_exam_store.dart';
import '../../core/backend/attempt_sync_service.dart';
import '../auth/auth_page.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/backend/exam_publication_service.dart';
import '../../core/import/pdf_text_extractor.dart';
import '../../core/import/question_parser.dart';
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
      if (length != null && length > 4 * 1024 * 1024)
        throw const FormatException('Limite: 4 MB.');
      final bytes = await file.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024)
        throw const FormatException('Limite: 4 MB.');
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
            durationMinutes: exam.durationMinutes,
            year: exam.year,
            questions: exam.questions,
            localId: exam.id,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted)
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
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: AppColors.brandHover),
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
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
        if (selectedSize > 25 * 1024 * 1024)
          throw const FormatException('O PDF excede o limite de 25 MB.');
        if (mounted) {
          setState(() {
            file = selected;
            fileSize = selectedSize;
          });
        }
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o PDF. Escolha um arquivo de até 25 MB e tente novamente.',
            ),
          ),
        );
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
                  'O PDF será usado para extrair questões e figuras. O original não será distribuído aos estudantes.',
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
                              : AppColors.brand,
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
                            ? const Column(
                                key: ValueKey('empty'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_file_rounded,
                                    size: 36,
                                    color: AppColors.brand,
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
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 36,
                                    color: AppColors.brand,
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
                            builder: (_) => PdfPreparationPage(file: file!),
                          ),
                        ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continuar para identificação'),
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

class PdfPreparationPage extends StatefulWidget {
  const PdfPreparationPage({required this.file, super.key});
  final PlatformFile file;

  @override
  State<PdfPreparationPage> createState() => _PdfPreparationPageState();
}

class _PdfPreparationPageState extends State<PdfPreparationPage> {
  final title = TextEditingController();
  final source = TextEditingController();
  final category = TextEditingController();
  final year = TextEditingController();
  final duration = TextEditingController(text: '120');

  @override
  void dispose() {
    title.dispose();
    source.dispose();
    category.dispose();
    year.dispose();
    duration.dispose();
    super.dispose();
  }

  void start() {
    if (title.text.trim().isEmpty ||
        category.text.trim().isEmpty ||
        source.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o título, a categoria e a origem da prova.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfProcessingPage(
          file: widget.file,
          title: title.text.trim(),
          category: category.text.trim(),
          source: source.text.trim(),
          year: int.tryParse(year.text),
          durationMinutes: int.tryParse(duration.text) ?? 120,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Identificar prova')),
    body: ListView(
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
                  'Informações da prova',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Título da prova',
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
                    hintText: 'Ex.: Vestibulares, Concursos, Matemática',
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
                    SizedBox(width: AppSpacing.md),
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
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.brand,
                    ),
                    title: Text(widget.file.name),
                    subtitle: const Text(
                      'O processamento mostrará etapas reais e abrirá uma revisão antes da publicação.',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: start,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Iniciar digitalização'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class PdfProcessingPage extends StatefulWidget {
  const PdfProcessingPage({
    required this.file,
    required this.title,
    required this.category,
    required this.source,
    required this.durationMinutes,
    this.year,
    super.key,
  });

  final PlatformFile file;
  final String title;
  final String category;
  final String source;
  final int? year;
  final int durationMinutes;

  @override
  State<PdfProcessingPage> createState() => _PdfProcessingPageState();
}

class _PdfProcessingPageState extends State<PdfProcessingPage> {
  late final Future<_ImportResult> work = _process();

  Future<_ImportResult> _process() async {
    final bytes = await widget.file.readAsBytes();
    final extraction = await const PdfTextExtractor().extract(
      bytes,
      sourceName: widget.file.name,
    );
    final questions = const QuestionParser().parse(extraction.text);
    return _ImportResult(extraction: extraction, questions: questions);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Digitalizando prova')),
    body: FutureBuilder<_ImportResult>(
      future: work,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ProcessMessage(
            icon: Icons.error_outline_rounded,
            title: 'Não foi possível ler o PDF',
            text: '${snapshot.error}',
            action: () => Navigator.pop(context),
            actionLabel: 'Voltar',
          );
        }
        if (!snapshot.hasData) {
          return const _ProcessMessage(
            icon: Icons.document_scanner_outlined,
            title: 'Extraindo conteúdo',
            text: 'Lendo texto, aplicando OCR quando necessário e procurando questões e alternativas…',
            loading: true,
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
                : 'A versão Web encontrou ${result.extraction.pagesWithText} páginas com texto em ${result.extraction.pageCount}. Abra o mesmo PDF no aplicativo Android para executar o OCR local.',
            action: () => Navigator.pop(context),
            actionLabel: 'Escolher outro arquivo',
          );
        }
        if (result.questions.isEmpty) {
          return _ProcessMessage(
            icon: Icons.rule_folder_outlined,
            title: 'Texto lido, estrutura não reconhecida',
            text: 'O arquivo possui texto, mas as questões não seguem o padrão “Questão 1” com alternativas A–E. Nenhum conteúdo foi publicado.',
            action: () => Navigator.pop(context),
            actionLabel: 'Voltar',
          );
        }
        return _ProcessMessage(
          icon: Icons.check_circle_outline_rounded,
          title: '${result.questions.length} questões encontradas',
          text:
              '${result.extraction.pageCount} páginas analisadas, ${result.extraction.ocrPages} por OCR. Revise enunciados, alternativas e gabarito antes de publicar.',
          action: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ImportReviewPage(
                title: widget.title,
                category: widget.category,
                source: widget.source,
                year: widget.year,
                durationMinutes: widget.durationMinutes,
                questions: result.questions,
              ),
            ),
          ),
          actionLabel: 'Revisar questões',
        );
      },
    ),
  );
}

class _ImportResult {
  const _ImportResult({required this.extraction, required this.questions});
  final PdfExtractionResult extraction;
  final List<ImportedQuestion> questions;
}

class _ProcessMessage extends StatelessWidget {
  const _ProcessMessage({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.actionLabel,
    this.loading = false,
  });
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? action;
  final String? actionLabel;
  final bool loading;

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
              const CircularProgressIndicator()
            else
              Icon(icon, size: 56, color: AppColors.brand),
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
    required this.durationMinutes,
    required this.questions,
    this.year,
    this.localId,
    this.pendingPublication = false,
    super.key,
  });
  final String title, category, source;
  final int durationMinutes;
  final int? year;
  final String? localId;
  final bool pendingPublication;
  final List<ImportedQuestion> questions;
  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage>
    with WidgetsBindingObserver {
  late final TextEditingController title, category, source, duration, year;
  late final List<ImportedQuestion> questions;
  late final String localId;
  final store = LocalExamStore();
  bool busy = false, canPop = false;
  late bool pendingPublication;
  String status = 'Ainda não salvo';
  int revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pendingPublication = widget.pendingPublication;
    localId =
        widget.localId ?? 'local-${AttemptSyncService.newClientAttemptId()}';
    title = TextEditingController(text: widget.title);
    category = TextEditingController(text: widget.category);
    source = TextEditingController(text: widget.source);
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
          ),
        )
        .toList();
    for (final controller in [title, category, source, duration, year]) {
      controller.addListener(_changed);
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
    durationMinutes: int.tryParse(duration.text) ?? 0,
    year: int.tryParse(year.text),
    questions: questions,
    pendingPublication: pendingPublication,
  );
  void _changed() {
    revision++;
    setState(() => status = 'Salvando no aparelho…');
    unawaited(_save());
  }

  Future<bool> _save({bool? pending}) async {
    if (pending != null) pendingPublication = pending;
    final savedRevision = revision;
    try {
      await store.save(_snapshot());
      if (mounted && savedRevision == revision)
        setState(() => status = 'Salvo no aparelho');
      return true;
    } catch (_) {
      if (mounted)
        setState(
          () =>
              status = 'Falha ao salvar. Tente novamente ou exporte uma cópia.',
        );
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused)
      unawaited(_save());
  }

  Future<void> _exit() async {
    if (busy || !await _save() || !mounted) return;
    setState(() => canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in [title, category, source, duration, year]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _export() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: jsonEncode(_snapshot().toJson())),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'JSON copiado. Guarde em um arquivo .json para importar depois.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível copiar. Verifique a permissão da área de transferência.',
            ),
          ),
        );
    }
  }

  bool _valid() =>
      title.text.trim().length >= 3 &&
      title.text.trim().length <= 180 &&
      category.text.trim().length >= 2 &&
      category.text.trim().length <= 80 &&
      source.text.trim().length >= 2 &&
      source.text.trim().length <= 160 &&
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
            q.correctIndex != null,
      );
  Future<void> _publish() async {
    if (busy) return;
    if (!_valid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha título, categoria, origem, duração, questões, alternativas e gabarito.',
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
        if (!mounted || Supabase.instance.client.auth.currentUser == null)
          return;
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
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível publicar. Sua prova continua salva no aparelho.',
            ),
          ),
        );
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
  Widget _question(int index) {
    final entry = MapEntry(index, questions[index]);
    return Card(
      key: ObjectKey(entry.value),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Questão ${entry.key + 1}')),
                IconButton(
                  tooltip: 'Remover questão ${entry.key + 1}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy
                      ? null
                      : () {
                          questions.removeAt(entry.key);
                          _changed();
                        },
                ),
              ],
            ),
            TextFormField(
              key: ObjectKey(entry.value),
              initialValue: entry.value.statement,
              enabled: !busy,
              minLines: 2,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Enunciado'),
              onChanged: (value) {
                entry.value.statement = value;
                _changed();
              },
            ),
            for (var option = 0; option < entry.value.options.length; option++)
              Row(
                children: [
                  IconButton(
                    tooltip:
                        'Marcar alternativa ${String.fromCharCode(65 + option)} como correta',
                    onPressed: busy
                        ? null
                        : () {
                            entry.value.correctIndex = option;
                            _changed();
                          },
                    icon: Icon(
                      entry.value.correctIndex == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey(
                        '${identityHashCode(entry.value)}-$option-${entry.value.options.length}',
                      ),
                      initialValue: entry.value.options[option],
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText:
                            'Alternativa ${String.fromCharCode(65 + option)}',
                      ),
                      onChanged: (value) {
                        entry.value.options[option] = value;
                        _changed();
                      },
                    ),
                  ),
                  if (entry.value.options.length > 2)
                    IconButton(
                      tooltip:
                          'Remover alternativa ${String.fromCharCode(65 + option)}',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: busy
                          ? null
                          : () {
                              final correct = entry.value.correctIndex;
                              entry.value.options.removeAt(option);
                              if (correct == option) {
                                entry.value.correctIndex = null;
                              } else if (correct != null && correct > option) {
                                entry.value.correctIndex = correct - 1;
                              }
                              _changed();
                            },
                    ),
                ],
              ),
            if (entry.value.options.length < 8)
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        entry.value.options.add('');
                        _changed();
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
                  ImportedQuestion(statement: '', options: ['', '']),
                );
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
                if (await _save(pending: false) && mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prova privada salva na biblioteca local.'),
                    ),
                  );
              },
        child: const Text('Salvar só para mim'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: busy ? null : _publish,
        child: Text(busy ? 'Aguarde…' : 'Publicar para todos — requer conta'),
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
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return _header();
              if (index == questions.length + 1) return _footer();
              return _question(index - 1);
            },
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
                  color: active ? AppColors.brand : AppColors.line,
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
                  color: active ? AppColors.brandHover : AppColors.muted,
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
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.muted),
      SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          'Rascunhos ficam privados. Uma prova só aparece para a comunidade depois da revisão e publicação.',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    ],
  );
}
