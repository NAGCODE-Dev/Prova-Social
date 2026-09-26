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
      'Busque provas por concurso, banca ou matéria e veja a origem antes de começar.',
      'PM-SP  •  VUNESP  •  Matemática',
    ),
    (
      Icons.task_alt_rounded,
      'Resolva sem distrações',
      'Ao iniciar uma prova, a rede desaparece. Ficam apenas questão, tempo e progresso.',
      'Questão 12 de 80  •  salvo no aparelho',
    ),
    (
      Icons.document_scanner_outlined,
      'Transforme PDF em prova',
      'Importe, revise as questões extraídas e só então publique para a comunidade.',
      'PDF → revisão → publicação',
    ),
  ];

  Future<void> _finish({bool login = false}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarding_complete', true);
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
                  Row(
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: last
                        ? () => _finish()
                        : () => controller.nextPage(
                            duration: AppMotion.of(context, AppMotion.normal),
                            curve: Curves.easeOutCubic,
                          ),
                    child: Text(last ? 'Explorar sem conta' : 'Continuar'),
                  ),
                  if (last) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _finish(login: true),
                      child: const Text('Já tenho uma conta'),
                    ),
                  ],
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
  Widget build(BuildContext context) => Padding(
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
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class _FeaturePreview extends StatelessWidget {
  const _FeaturePreview({
    required this.icon,
    required this.text,
    required this.index,
  });

  final IconData icon;
  final String text;
  final int index;

  @override
  Widget build(BuildContext context) => Container(
    height: 230,
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: AppColors.brandHover, size: 32),
          ),
        ),
        const Spacer(),
        if (index == 1) ...[
          const LinearProgressIndicator(value: .42, minHeight: 6),
          const SizedBox(height: 16),
        ],
        Text(text, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          height: 8,
          width: index == 2 ? 150 : 210,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    ),
  );
}
