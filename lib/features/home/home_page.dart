import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/sample_exams.dart';
import '../../domain/models/exam.dart';
import '../quiz/quiz_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const categories = ['Todos', 'Concursos', 'ENEM', 'Matemática', 'História'];
  String category = 'Todos';
  String query = '';
  int currentTab = 0;
  final saved = <String>{};

  List<Exam> get visibleExams => sampleExams.where((exam) {
        final matchesCategory = category == 'Todos' || exam.category == category;
        final search = query.trim().toLowerCase();
        final matchesSearch = search.isEmpty || '${exam.title} ${exam.description}'.toLowerCase().contains(search);
        return matchesCategory && matchesSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(backgroundColor: AppColors.amber, child: Text('NA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          ),
        ],
      ),
      body: IndexedStack(
        index: currentTab,
        children: [
          _Feed(
            category: category,
            query: query,
            exams: visibleExams,
            saved: saved,
            onCategoryChanged: (value) => setState(() => category = value),
            onQueryChanged: (value) => setState(() => query = value),
            onSave: (id) => setState(() => saved.contains(id) ? saved.remove(id) : saved.add(id)),
            onStart: _startExam,
          ),
          _placeholder('Explorar provas', 'Descubra materiais publicados pela comunidade.'),
          _placeholder('Publicar uma prova', 'A importação por JSON e PDF entra na próxima etapa.'),
          _placeholder('Sua atividade', 'Seus simulados e resultados aparecerão aqui.'),
          _placeholder('Seu perfil', 'Estatísticas, publicações e itens salvos ficarão reunidos aqui.'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (value) => setState(() => currentTab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.add_box_outlined), label: 'Publicar'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Atividade'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _placeholder(String title, String body) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_stories_outlined, size: 52, color: AppColors.blue),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      );

  Future<void> _startExam(Exam exam) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizPage(exam: exam)));
  }
}

class _Feed extends StatelessWidget {
  const _Feed({required this.category, required this.query, required this.exams, required this.saved, required this.onCategoryChanged, required this.onQueryChanged, required this.onSave, required this.onStart});
  final String category;
  final String query;
  final List<Exam> exams;
  final Set<String> saved;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final columns = constraints.maxWidth >= 1050 ? 3 : wide ? 2 : 1;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('APRENDA RESOLVENDO', style: TextStyle(color: AppColors.blue, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Encontre sua próxima prova.', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.4)),
              const SizedBox(height: 8),
              const Text('Pratique no seu ritmo, acompanhe seus erros e compartilhe bons materiais com outros estudantes.', style: TextStyle(color: AppColors.muted, height: 1.45)),
              const SizedBox(height: 22),
              TextField(onChanged: onQueryChanged, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Busque por concurso, matéria ou prova')),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _HomePageState.categories.map((item) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(item), selected: category == item, onSelected: (_) => onCategoryChanged(item)),
                )).toList()),
              ),
              const SizedBox(height: 26),
              Text('Em destaque', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              if (exams.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(36), child: Center(child: Text('Nenhuma prova encontrada.'))))
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: exams.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 260, crossAxisSpacing: 14, mainAxisSpacing: 14),
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    return _ExamCard(exam: exam, saved: saved.contains(exam.id), onSave: () => onSave(exam.id), onStart: () => onStart(exam));
                  },
                ),
            ]),
          ),
        ),
      );
    });
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.saved, required this.onSave, required this.onStart});
  final Exam exam;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          DecoratedBox(decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(8)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), child: Text(exam.category.toUpperCase(), style: const TextStyle(color: AppColors.blue, fontSize: 10, fontWeight: FontWeight.w900)))),
          const Spacer(),
          IconButton(onPressed: onSave, icon: Icon(saved ? Icons.star_rounded : Icons.star_border_rounded, color: saved ? AppColors.amber : AppColors.muted)),
        ]),
        const SizedBox(height: 8),
        Text(exam.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(exam.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
        const Spacer(),
        Text('${exam.questions.length} questões  ·  ${exam.durationMinutes} min  ·  ${exam.attempts} tentativas', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: Text(exam.author, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))), FilledButton(onPressed: onStart, style: FilledButton.styleFrom(backgroundColor: AppColors.navy), child: const Text('Resolver'))]),
      ]),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(mainAxisSize: MainAxisSize.min, children: [
    CircleAvatar(radius: 17, backgroundColor: AppColors.navy, child: Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
    SizedBox(width: 9),
    Text.rich(TextSpan(children: [TextSpan(text: 'Prova', style: TextStyle(fontWeight: FontWeight.w900)), TextSpan(text: 'Social', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w900))])),
  ]);
}
