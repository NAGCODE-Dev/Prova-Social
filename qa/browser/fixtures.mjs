// Synthetic content used only by the loopback QA server and isolated contexts.
export const localExam = {
  id: 'qa-local', title: 'QA — Prova privada', category: 'Matemática',
  source: 'Fixture sintética de QA — não é prova oficial', durationMinutes: 30,
  year: null, pendingPublication: false,
  questions: [
    { statement: 'QA: quanto é 1 + 1?', options: ['Um', 'Dois'], correctIndex: 1 },
    { statement: 'QA: quanto é 2 + 2?', options: ['Três', 'Quatro'], correctIndex: 1 },
    { statement: 'QA: quanto é 3 + 3?', options: ['Cinco', 'Seis'], correctIndex: 1 },
  ],
};
export const publicExam = {
  id: 'qa-public', title: 'QA — Catálogo de matemática', category: 'Matemática',
  description: 'Fixture local para descoberta; não publicada.',
  source_name: localExam.source, source_type: 'unverified', source_url: null,
  duration_minutes: 30, attempts_count: 0,
};
export const questions = localExam.questions.map((q, position) => ({
  id: `qa-question-${position}`, exam_id: publicExam.id, position,
  topic: 'Matemática', statement: q.statement, options: q.options,
}));

export function apiResponse(url) {
  if (url.pathname === '/rest/v1/exams') {
    const filter = [...url.searchParams].find(([, value]) => value.startsWith('ilike.'));
    if (!filter) return [publicExam];
    const [field, pattern] = filter;
    const query = pattern.slice(6).replaceAll('%', '').toLocaleLowerCase();
    return String(publicExam[field] ?? '').toLocaleLowerCase().includes(query) ? [publicExam] : [];
  }
  if (url.pathname === '/rest/v1/questions') {
    if (url.searchParams.has('topic')) {
      const query = url.searchParams.get('topic').slice(6).replaceAll('%', '').toLocaleLowerCase();
      return 'matemática'.includes(query) ? [{ exams: publicExam }] : [];
    }
    return url.searchParams.get('exam_id') === 'eq.qa-public' ? questions : [];
  }
  return null;
}
