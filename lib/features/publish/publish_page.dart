import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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

class PdfPreparationPage extends StatelessWidget {
  const PdfPreparationPage({required this.file, super.key});
  final PlatformFile file;

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
                    const TextField(
                        decoration: InputDecoration(labelText: 'Título da prova')),
                    const SizedBox(height: AppSpacing.md),
                    const TextField(
                        decoration: InputDecoration(labelText: 'Banca ou origem')),
                    const SizedBox(height: AppSpacing.md),
                    const Row(children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Ano'),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
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
                        title: Text(file.name),
                        subtitle: const Text(
                          'O processamento mostrará etapas reais e abrirá uma revisão antes da publicação.',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _ExtractorPendingDialog(),
                      ),
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

class _ExtractorPendingDialog extends StatelessWidget {
  const _ExtractorPendingDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: const Icon(Icons.construction_rounded, color: AppColors.brand),
        title: const Text('Interface preparada'),
        content: const Text(
          'O seletor e a identificação do PDF já funcionam. O extrator de texto e imagens será conectado ao processamento na próxima etapa; nenhum resultado falso será criado.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
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
