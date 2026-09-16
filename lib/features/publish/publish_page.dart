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
                  Text('Criar e compartilhar',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Escolha como o material entra. Você revisa tudo antes de publicar.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LayoutBuilder(builder: (context, constraints) {
                    final horizontal = constraints.maxWidth >= 680;
                    final options = [
                      _PublishChoice(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Importar PDF',
                        description:
                            'Extraia texto e figuras, confira as questões e publique.',
                        action: 'Selecionar PDF',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PdfImportPage(),
                          ),
                        ),
                      ),
                      _PublishChoice(
                        icon: Icons.data_object_rounded,
                        title: 'Importar JSON',
                        description:
                            'Use um arquivo já estruturado no formato Prova Social.',
                        action: 'Selecionar JSON',
                        onTap: () => _notReady(context),
                      ),
                      _PublishChoice(
                        icon: Icons.edit_note_rounded,
                        title: 'Criar manualmente',
                        description:
                            'Monte questões e alternativas usando o editor.',
                        action: 'Abrir editor',
                        onTap: () => _notReady(context),
                      ),
                    ];
                    if (!horizontal) {
                      return Column(
                        children: options
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: item,
                                ))
                            .toList(),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: options
                          .map((item) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.md,
                                  ),
                                  child: item,
                                ),
                              ))
                          .toList(),
                    );
                  }),
                  const SizedBox(height: AppSpacing.xl),
                  const _PrivacyNote(),
                ],
              ),
            ),
          ),
        ],
      );

  static void _notReady(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este editor será conectado na próxima integração.'),
        ),
      );
}

class _PublishChoice extends StatelessWidget {
  const _PublishChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: AppColors.brandHover),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(action,
                    style: const TextStyle(
                      color: AppColors.brandHover,
                      fontWeight: FontWeight.w700,
                    )),
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
        if (mounted) {
          setState(() {
            file = selected;
            fileSize = selectedSize;
          });
        }
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
                    Text('Escolha o arquivo',
                        style: Theme.of(context).textTheme.headlineSmall),
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
                          constraints: const BoxConstraints(minHeight: 220),
                          padding: const EdgeInsets.all(AppSpacing.xl),
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.upload_file_rounded,
                                              size: 48,
                                              color: AppColors.brand),
                                          SizedBox(height: AppSpacing.md),
                                          Text('Toque para selecionar o PDF',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              )),
                                          SizedBox(height: AppSpacing.sm),
                                          Text('Limite inicial: 25 MB'),
                                        ],
                                      )
                                    : Column(
                                        key: const ValueKey('selected'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              size: 48,
                                              color: AppColors.brand),
                                          const SizedBox(height: AppSpacing.md),
                                          Text(file!.name,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              )),
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
  final year = TextEditingController();
  final duration = TextEditingController(text: '120');

  @override
  void dispose() {
    title.dispose();
    source.dispose();
    year.dispose();
    duration.dispose();
    super.dispose();
  }

  void start() {
    if (title.text.trim().isEmpty || source.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o título e a origem da prova.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PdfProcessingPage(
        file: widget.file,
        title: title.text.trim(),
        source: source.text.trim(),
        year: int.tryParse(year.text),
        durationMinutes: int.tryParse(duration.text) ?? 120,
      ),
    ));
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
                    Text('Informações da prova',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                        controller: title,
                        decoration: const InputDecoration(labelText: 'Título da prova')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                        controller: source,
                        decoration: const InputDecoration(labelText: 'Banca ou origem')),
                    const SizedBox(height: AppSpacing.md),
                    const Row(children: [
                      Expanded(
                        child: TextField(
                          controller: year,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Ano'),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: duration,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(labelText: 'Duração em minutos'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf_outlined,
                            color: AppColors.brand),
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
    required this.source,
    required this.durationMinutes,
    this.year,
    super.key,
  });

  final PlatformFile file;
  final String title;
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
              text: '${result.extraction.pageCount} páginas analisadas, ${result.extraction.ocrPages} por OCR. Revise enunciados, alternativas e gabarito antes de publicar.',
              action: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => ImportReviewPage(
                    title: widget.title,
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (loading) const CircularProgressIndicator() else Icon(icon, size: 56, color: AppColors.brand),
              const SizedBox(height: AppSpacing.lg),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton(onPressed: action, child: Text(actionLabel!)),
              ],
            ]),
          ),
        ),
      );
}

class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({
    required this.title,
    required this.source,
    required this.durationMinutes,
    required this.questions,
    this.year,
    super.key,
  });
  final String title;
  final String source;
  final int? year;
  final int durationMinutes;
  final List<ImportedQuestion> questions;

  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  bool publishing = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Revisar importação')),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          itemCount: widget.questions.length,
          itemBuilder: (context, index) {
            final question = widget.questions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                child: ExpansionTile(
                  initiallyExpanded: index == 0,
                  title: Text('Questão ${index + 1}'),
                  subtitle: Text(question.statement, maxLines: 2, overflow: TextOverflow.ellipsis),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    TextFormField(
                      initialValue: question.statement,
                      minLines: 3,
                      maxLines: null,
                      decoration: const InputDecoration(labelText: 'Enunciado'),
                      onChanged: (value) => question.statement = value,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var option = 0; option < question.options.length; option++)
                      RadioListTile<int>(
                        value: option,
                        groupValue: question.correctIndex,
                        onChanged: (value) => setState(() => question.correctIndex = value),
                        title: TextFormField(
                          initialValue: question.options[option],
                          decoration: InputDecoration(labelText: 'Alternativa ${String.fromCharCode(65 + option)}'),
                          onChanged: (value) => question.options[option] = value,
                        ),
                        subtitle: option == question.correctIndex ? const Text('Resposta correta') : null,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton.icon(
              onPressed: publishing ? null : _publish,
              icon: publishing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_rounded),
              label: Text(publishing ? 'Publicando…' : 'Publicar prova'),
            ),
          ),
        ),
      );

  Future<void> _publish() async {
    final missing = widget.questions.where((q) => q.correctIndex == null).length;
    if (missing > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Defina o gabarito de $missing questões antes de publicar.'),
      ));
      return;
    }
    setState(() => publishing = true);
    try {
      await ExamPublicationService().publish(
        title: widget.title,
        source: widget.source,
        year: widget.year,
        durationMinutes: widget.durationMinutes,
        questions: widget.questions,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.verified_rounded, color: AppColors.brand),
          title: const Text('Prova publicada'),
          content: Text('${widget.questions.length} questões foram compactadas e publicadas com sucesso.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Concluir'))],
        ),
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao publicar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }
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
                margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 4),
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(labels[index],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.brandHover : AppColors.muted,
                  )),
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
