import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../auth/auth_page.dart';
import '../home/home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  var page = 0;

  static const slides = [
    (
      Icons.travel_explore_rounded,
      'Encontre o que estudar',
      'Busque provas por concurso, banca ou matéria e confira a origem antes de começar.',
      'Banca  •  concurso  •  matéria',
    ),
    (
      Icons.task_alt_rounded,
      'Resolva sem distrações',
      'Questões, tempo e progresso em uma experiência focada na sua preparação.',
      'Questão  •  progresso  •  salvo no aparelho',
    ),
    (
      Icons.document_scanner_outlined,
      'Transforme PDF em prova',
      'Importe, revise as questões extraídas e só então publique para a comunidade.',
      'PDF → revisão → publicação',
    ),
  ];

  Future<void> _finish({bool login = false}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('onboarding_complete', true);
    } catch (error, stackTrace) {
      debugPrint(
        '[ONBOARDING_STATE] não foi possível salvar: ${error.runtimeType}',
      );
      debugPrint('[ONBOARDING_STATE] stack: $stackTrace');
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            login ? const AuthPage(closeAfterAuth: true) : const HomePage(),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = page == slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  const BrandLockup(),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _finish(),
                    child: const Text('Pular'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: slides.length,
                onPageChanged: (value) => setState(() => page = value),
                itemBuilder: (context, index) =>
                    _OnboardingSlide(data: slides[index], index: index),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    label: 'Etapa ${page + 1} de ${slides.length}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (index) => AnimatedContainer(
                          duration: AppMotion.of(context, AppMotion.fast),
                          width: index == page ? 24 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == page
                                ? AppColors.brand
                                : Theme.of(context).colorScheme.outline,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (page == 0)
                    FilledButton(
                      onPressed: () => controller.nextPage(
                        duration: AppMotion.of(context, AppMotion.normal),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Continuar'),
                    )
                  else if (last) ...[
                    FilledButton(
                      onPressed: () => _finish(),
                      child: const Text('Explorar sem conta'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _finish(login: true),
                      child: const Text('Já tenho uma conta'),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.previousPage(
                              duration: AppMotion.of(context, AppMotion.normal),
                              curve: Curves.easeOutCubic,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Voltar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => controller.nextPage(
                              duration: AppMotion.of(context, AppMotion.normal),
                              curve: Curves.easeOutCubic,
                            ),
                            child: const Text('Continuar'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data, required this.index});

  final (IconData, String, String, String) data;
  final int index;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxHeight < 420) {
        final previewWidth = (constraints.maxWidth * .25).clamp(80.0, 112.0);
        final previewHeight = (constraints.maxHeight - 16).clamp(0.0, 128.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: previewWidth,
                child: Center(
                  child: _FeaturePreview(
                    icon: data.$1,
                    text: data.$4,
                    index: index,
                    compact: true,
                    compactHeight: previewHeight,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.$2,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.$3,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FeaturePreview(icon: data.$1, text: data.$4, index: index),
            const SizedBox(height: 36),
            Text(data.$2, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              data.$3,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FeaturePreview extends StatelessWidget {
  const _FeaturePreview({
    required this.icon,
    required this.text,
    required this.index,
    this.compact = false,
    this.compactHeight = 120,
  });

  final IconData icon;
  final String text;
  final int index;
  final bool compact;
  final double compactHeight;

  @override
  Widget build(BuildContext context) => Container(
    height: compact ? compactHeight : 230,
    width: double.infinity,
    padding: EdgeInsets.all(compact ? 8 : 24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(
        compact ? AppRadius.md : AppRadius.xl,
      ),
    ),
    child: compact
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: AppColors.brandHover, size: 24),
                ),
              ),
              if (compactHeight >= 112) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          )
        : _OnboardingIllustration(icon: icon, text: text, index: index),
  );
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({
    required this.icon,
    required this.text,
    required this.index,
  });

  final IconData icon;
  final String text;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final surface = theme.colorScheme.surfaceContainerHighest;
    final brand = theme.colorScheme.primary;
    return switch (index) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            enabled: false,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Concurso, banca ou matéria',
              prefixIcon: Icon(icon),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prova de exemplo',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Banca · ano · questões',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified_outlined, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: brand),
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    value: .42,
                    minHeight: 7,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.timer_outlined, size: 18, color: brand),
              const SizedBox(width: 4),
              Text('12:40', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 14),
          Text('Questão de exemplo', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var option = 0; option < 2; option++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    option == 0
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: option == 0 ? brand : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        color: option == 0
                            ? brand.withValues(alpha: .5)
                            : outline,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: brand),
          ),
        ],
      ),
      _ => Row(
        children: [
          for (final (stepIcon, title) in [
            (Icons.picture_as_pdf_outlined, 'PDF'),
            (Icons.fact_check_outlined, 'Revisão'),
            (Icons.public_outlined, 'Publicação'),
          ]) ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(stepIcon, size: 30, color: brand),
                  const SizedBox(height: 8),
                  Text(title, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
            if (title != 'Publicação')
              Icon(Icons.arrow_forward_rounded, size: 18, color: outline),
          ],
        ],
      ),
    };
  }
}
