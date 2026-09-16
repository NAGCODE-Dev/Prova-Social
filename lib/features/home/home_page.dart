import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../data/sample_exams.dart';
import '../../domain/models/exam.dart';
import '../quiz/quiz_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentTab = 0;
  String query = '';
  String category = 'Todos';
  final saved = <String>{'pmesp-2024'};

  static const destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Início'),
    (Icons.search_rounded, Icons.search_rounded, 'Explorar'),
    (Icons.add_box_outlined, Icons.add_box_rounded, 'Publicar'),
    (Icons.bookmarks_outlined, Icons.bookmarks_rounded, 'Biblioteca'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final pages = [
          _HomeFeed(saved: saved, onSave: _toggleSave, onOpen: _openExam),
          _ExplorePage(query: query, category: category, saved: saved, onQuery: (value) => setState(() => query = value), onCategory: (value) => setState(() => category = value), onSave: _toggleSave, onOpen: _openExam),
          const _PublishPage(),
          _LibraryPage(saved: saved, onOpen: _openExam),
          const _ProfilePage(),
        ];
        return Scaffold(
          appBar: desktop ? null : AppBar(title: const BrandLockup(), actions: const [_HeaderActions()]),
          body: Row(children: [
            if (desktop)
              Container(
                width: 240,
                decoration: const BoxDecoration(color: AppColors.surface, border: Border(right: BorderSide(color: AppColors.line))),
                child: SafeArea(child: Column(children: [
                  const Padding(padding: EdgeInsets.fromLTRB(24, 22, 16, 26), child: Align(alignment: Alignment.centerLeft, child: BrandLockup())),
                  ...List.generate(destinations.length, (index) => _RailItem(data: destinations[index], selected: currentTab == index, onTap: () => setState(() => currentTab = index))),
                  const Spacer(),
                  const Padding(padding: EdgeInsets.all(16), child: _UserTile()),
                ])),
              ),
            Expanded(child: Column(children: [
              if (desktop) const _DesktopTopBar(),
              Expanded(child: IndexedStack(index: currentTab, children: pages)),
            ])),
          ]),
          bottomNavigationBar: desktop ? null : NavigationBar(
            selectedIndex: currentTab,
            onDestinationSelected: (value) => setState(() => currentTab = value),
            destinations: destinations.map((item) => NavigationDestination(icon: Icon(item.$1), selectedIcon: Icon(item.$2), label: item.$3)).toList(),
          ),
        );
      });

  void _toggleSave(String id) => setState(() => saved.contains(id) ? saved.remove(id) : saved.add(id));

  Future<void> _openExam(Exam exam) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ExamDetails(exam: exam, saved: saved.contains(exam.id), onSave: () => _toggleSave(exam.id))));
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar();
  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: const Row(children: [Expanded(child: _SearchBox()), SizedBox(width: 24), _HeaderActions()]),
      );
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: () {}, tooltip: 'Notificações', icon: const Icon(Icons.notifications_none_rounded)),
        const SizedBox(width: 4),
        const CircleAvatar(radius: 18, backgroundColor: AppColors.brandSoft, child: Text('NA', style: TextStyle(color: AppColors.brandHover, fontSize: 11, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
      ]);
}

class _SearchBox extends StatelessWidget {
  const _SearchBox();
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: TextField(readOnly: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar provas, concursos e matérias', isDense: true)),
      );
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.data, required this.selected, required this.onTap});
  final (IconData, IconData, String) data;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          selected: selected,
          selectedTileColor: AppColors.brandSoft,
          selectedColor: AppColors.brandHover,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(selected ? data.$2 : data.$1),
          title: Text(data.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: onTap,
        ),
      );
}

class _HomeFeed extends StatelessWidget {
  const _HomeFeed({required this.saved, required this.onSave, required this.onOpen});
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;
  @override
  Widget build(BuildContext context) => _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Olá, Nikolas', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text('Escolha uma prova e continue avançando.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 28),
        const _SectionTitle('Continue de onde parou'),
        const SizedBox(height: 12),
        _ContinueCard(exam: sampleExams.first, onTap: () => onOpen(sampleExams.first)),
        const SizedBox(height: 32),
        const _SectionTitle('Para você'),
        const SizedBox(height: 12),
        _ExamGrid(exams: sampleExams, saved: saved, onSave: onSave, onOpen: onOpen),
      ]));
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.exam, required this.onTap});
  final Exam exam;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SourceBadge(official: true),
          const SizedBox(height: 14),
          Text(exam.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          const Row(children: [Expanded(child: LinearProgressIndicator(value: .64, minHeight: 6, backgroundColor: AppColors.line, color: AppColors.brand, borderRadius: BorderRadius.all(Radius.circular(6)))), SizedBox(width: 12), Text('64%', style: TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          const Text('51 de 80 questões · Continuar', style: TextStyle(color: AppColors.muted)),
        ]))),
      );
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.query, required this.category, required this.saved, required this.onQuery, required this.onCategory, required this.onSave, required this.onOpen});
  final String query;
  final String category;
  final Set<String> saved;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;

  @override
  Widget build(BuildContext context) {
    const categories = ['Todos', 'Concursos', 'ENEM', 'Matemática', 'História'];
    final normalized = query.trim().toLowerCase();
    final exams = sampleExams.where((exam) => (category == 'Todos' || exam.category == category) && (normalized.isEmpty || '${exam.title} ${exam.description}'.toLowerCase().contains(normalized))).toList();
    return _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('O que você quer estudar?', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 18),
      TextField(onChanged: onQuery, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Concurso, banca, matéria ou prova')),
      const SizedBox(height: 16),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: categories.map((item) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(item), selected: category == item, selectedColor: AppColors.brandSoft, onSelected: (_) => onCategory(item)))).toList())),
      const SizedBox(height: 28),
      const _SectionTitle('Provas e questões'),
      const SizedBox(height: 12),
      if (exams.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('Nenhum resultado encontrado.', style: TextStyle(color: AppColors.muted)))) else _ExamGrid(exams: exams, saved: saved, onSave: onSave, onOpen: onOpen),
    ]));
  }
}

class _ExamGrid extends StatelessWidget {
  const _ExamGrid({required this.exams, required this.saved, required this.onSave, required this.onOpen});
  final List<Exam> exams;
  final Set<String> saved;
  final ValueChanged<String> onSave;
  final ValueChanged<Exam> onOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final count = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 620 ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exams.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, mainAxisExtent: 286, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemBuilder: (_, index) => ExamCard(exam: exams[index], saved: saved.contains(exams[index].id), onSave: () => onSave(exams[index].id), onOpen: () => onOpen(exams[index])),
    );
  });
}

class ExamCard extends StatelessWidget {
  const ExamCard({required this.exam, required this.saved, required this.onSave, required this.onOpen, super.key});
  final Exam exam;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(onTap: onOpen, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const SourceBadge(official: false), const Spacer(), IconButton(onPressed: onSave, tooltip: 'Salvar', icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: saved ? AppColors.brand : AppColors.muted))]),
    const SizedBox(height: 8),
    Text(exam.category.toUpperCase(), style: const TextStyle(color: AppColors.brandHover, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
    const SizedBox(height: 8),
    Text(exam.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    Text(exam.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
    const Spacer(),
    Text('${exam.questions.length} questões · ${exam.durationMinutes} min', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: Text('${exam.attempts} fizeram', style: const TextStyle(color: AppColors.muted, fontSize: 12))), const Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.brand)]),
  ]))));
}

class SourceBadge extends StatelessWidget {
  const SourceBadge({required this.official, super.key});
  final bool official;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: official ? AppColors.brandSoft : AppColors.surfaceHover, borderRadius: BorderRadius.circular(7)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(official ? Icons.verified_outlined : Icons.people_outline_rounded, size: 14, color: official ? AppColors.brandHover : AppColors.muted), const SizedBox(width: 5), Text(official ? 'Fonte oficial' : 'Comunidade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: official ? AppColors.brandHover : AppColors.muted))])),
  );
}

class _PublishPage extends StatelessWidget {
  const _PublishPage();
  @override
  Widget build(BuildContext context) => _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('O que você quer publicar?', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 6),
    const Text('Escolha um formato para começar.', style: TextStyle(color: AppColors.muted)),
    const SizedBox(height: 28),
    const _PublishOption(icon: Icons.description_outlined, title: 'Uma prova', subtitle: 'Importe questões, gabarito e informe a origem.'),
    const SizedBox(height: 12),
    const _PublishOption(icon: Icons.edit_note_rounded, title: 'Questões', subtitle: 'Publique questões avulsas para a comunidade.'),
    const SizedBox(height: 12),
    const _PublishOption(icon: Icons.library_books_outlined, title: 'Uma coleção', subtitle: 'Organize provas e questões por objetivo.'),
  ]));
}

class _PublishOption extends StatelessWidget {
  const _PublishOption({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.all(18), leading: DecoratedBox(decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, color: AppColors.brandHover))), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(subtitle)), trailing: const Icon(Icons.arrow_forward_rounded, color: AppColors.brand), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fluxo de publicação será conectado ao banco na próxima etapa.')))));
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({required this.saved, required this.onOpen});
  final Set<String> saved;
  final ValueChanged<Exam> onOpen;
  @override
  Widget build(BuildContext context) {
    final exams = sampleExams.where((exam) => saved.contains(exam.id)).toList();
    return _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Sua biblioteca', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 18),
      const Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text('Salvas')), Chip(label: Text('Em andamento')), Chip(label: Text('Concluídas')), Chip(label: Text('Coleções'))]),
      const SizedBox(height: 28),
      const _SectionTitle('Provas salvas'),
      const SizedBox(height: 12),
      if (exams.isEmpty) const Text('Salve uma prova para encontrá-la aqui.', style: TextStyle(color: AppColors.muted)) else _ExamGrid(exams: exams, saved: saved, onSave: (_) {}, onOpen: onOpen),
    ]));
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();
  @override
  Widget build(BuildContext context) => _PageScroll(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Row(children: [CircleAvatar(radius: 36, backgroundColor: AppColors.brandSoft, child: Text('NA', style: TextStyle(color: AppColors.brandHover, fontSize: 18, fontWeight: FontWeight.w800))), SizedBox(width: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Nikolas Ayres', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Estudando para evoluir uma questão por vez.', style: TextStyle(color: AppColors.muted))]))]),
    const SizedBox(height: 28),
    const Text('Seguindo', style: TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 10),
    const Wrap(spacing: 8, children: [Chip(label: Text('PM-SP')), Chip(label: Text('VUNESP')), Chip(label: Text('Matemática'))]),
    const SizedBox(height: 30),
    const Row(children: [Expanded(child: _ProfileStat('1.483', 'questões')), Expanded(child: _ProfileStat('74%', 'de acerto')), Expanded(child: _ProfileStat('31', 'provas'))]),
    const SizedBox(height: 30),
    const Divider(),
    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.history_rounded), title: Text('Atividade'), trailing: Icon(Icons.chevron_right_rounded)),
    const Divider(),
    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.collections_bookmark_outlined), title: Text('Coleções'), trailing: Icon(Icons.chevron_right_rounded)),
    const Divider(),
    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.logout_rounded), title: const Text('Sair da conta'), onTap: () => Supabase.instance.client.auth.signOut()),
  ]));
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12))]);
}

class _ExamDetails extends StatelessWidget {
  const _ExamDetails({required this.exam, required this.saved, required this.onSave});
  final Exam exam;
  final bool saved;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandLockup()),
    body: _PageScroll(maxWidth: 820, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SourceBadge(official: true),
      const SizedBox(height: 22),
      Text(exam.category.toUpperCase(), style: const TextStyle(color: AppColors.brandHover, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 8),
      Text(exam.title, style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 10),
      Text(exam.author, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      Wrap(spacing: 24, runSpacing: 12, children: [_Meta(Icons.quiz_outlined, '${exam.questions.length} questões'), _Meta(Icons.schedule_rounded, '${exam.durationMinutes} minutos'), _Meta(Icons.people_outline_rounded, '${exam.attempts} realizações')]),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizPage(exam: exam))), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Começar prova'))),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onSave, icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded), label: Text(saved ? 'Salva na biblioteca' : 'Salvar na biblioteca'))),
      const SizedBox(height: 32),
      const Divider(),
      const SizedBox(height: 22),
      const _SectionTitle('Sobre'),
      const SizedBox(height: 10),
      Text(exam.description, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      const _SectionTitle('Origem'),
      const SizedBox(height: 10),
      const Text('Material demonstrativo · procedência identificada', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 26),
      const _SectionTitle('Discussão · 0'),
    ])),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: AppColors.muted), const SizedBox(width: 7), Text(text, style: const TextStyle(color: AppColors.muted))]);
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.child, this.maxWidth = 1200});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 100), child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.headlineSmall);
}

class _UserTile extends StatelessWidget {
  const _UserTile();
  @override
  Widget build(BuildContext context) => const Row(children: [CircleAvatar(radius: 18, backgroundColor: AppColors.brandSoft, child: Text('NA', style: TextStyle(color: AppColors.brandHover, fontSize: 10, fontWeight: FontWeight.w800))), SizedBox(width: 10), Expanded(child: Text('Nikolas', style: TextStyle(fontWeight: FontWeight.w700))), Icon(Icons.more_horiz_rounded)]);
}
