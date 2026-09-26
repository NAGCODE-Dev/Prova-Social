import { test, expect, text, button, clickText, evidence, semantics, open, seed, selected, draft } from './harness.mjs';

// Fixture-only browser storage. Never export storageState, cookies or credentials.
async function start(page, context, info) {
  await seed(context);
  await open(page);
  await button(page, 'Pular').click();
  await expect(text(page, 'Encontre sua próxima prova')).toBeVisible();
  await evidence(page, info, 'home-390x844');
  await clickText(page, 'Biblioteca');
  await button(page, 'Fazer prova').click();
  await button(page, 'Começar prova').click();
  await expect(text(page, 'QA: quanto é 1 + 1?')).toBeVisible();
}
async function resume(page) {
  await semantics(page);
  await clickText(page, 'Biblioteca');
  await clickText(page, 'Continuar — disponível offline');
}
const answer = (page, name) => page.getByRole('button', { name }).click();
async function assertDraft(page, answers, current, review, id) {
  await expect.poll(async () => {
    const value = await draft(page);
    return value && { answers: value.answers, current: value.current, review: value.review };
  }).toEqual({ answers, current, review });
  const value = await draft(page);
  expect(value.clientAttemptId).toBeTruthy();
  if (id) expect(value.clientAttemptId).toBe(id);
  expect(await page.evaluate(() => Object.keys(localStorage)
    .filter(k => k.startsWith('flutter.attempt_draft_v1_qa-local-')).length)).toBe(1);
  return value.clientAttemptId;
}

test.beforeEach(async ({}, info) => {
  test.skip(info.project.name !== 'mobile', 'Torture runs once at 390x844.');
});

for (const point of ['A-start', 'B-immediate-answer', 'C-two-answers', 'D-review', 'E-middle', 'F-confirmation']) {
  test(`torture reload ${point}`, async ({ page, context }, info) => {
    await start(page, context, info);
    let answers = {}, current = 0, review = [];
    if (point !== 'A-start') {
      await answer(page, /Alternativa B, Dois/);
      answers = { 0: 1 };
    }
    if (['C-two-answers', 'D-review', 'E-middle', 'F-confirmation'].includes(point)) {
      await button(page, 'Próxima').click();
      current = 1;
    }
    if (point === 'C-two-answers') {
      await answer(page, /Alternativa A, Três/);
      answers[1] = 0;
    }
    if (point === 'D-review') {
      for (const label of ['Marcar para revisão', 'Remover da revisão', 'Marcar para revisão']) {
        await button(page, label).click();
      }
      review = [1];
    }
    if (point === 'F-confirmation') {
      await button(page, 'Revisar entrega').click();
      await expect(text(page, '1 de 3 respondidas')).toBeVisible();
    }
    // B intentionally has no storage polling between the answer and reload.
    const before = point === 'B-immediate-answer' ? null : await draft(page);
    await page.reload();
    await resume(page);
    await expect(text(page, current ? 'QA: quanto é 2 + 2?' : 'QA: quanto é 1 + 1?')).toBeVisible();
    if (point === 'A-start') {
      // Starting persists the content snapshot; a draft is first written on an
      // answer/navigation/lifecycle event. No answer exists yet to recover.
      expect((await draft(page))?.answers ?? {}).toEqual({});
    } else {
      await assertDraft(page, answers, current, review, before?.clientAttemptId);
      if (!current) await selected(page, /Alternativa B, Dois/);
      if (point === 'C-two-answers') await selected(page, /Alternativa A, Três/);
      if (review.length) await expect(button(page, 'Remover da revisão')).toBeVisible();
    }
    const queue = await page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem('flutter.attempt_sync_queue_v1'))));
    expect(Object.keys(queue.started)).toHaveLength(1);
    expect(Object.values(queue.started)[0].questions.map(q => q.statement)).toEqual([
      'QA: quanto é 1 + 1?', 'QA: quanto é 2 + 2?', 'QA: quanto é 3 + 3?',
    ]);
    expect(queue.pending).toHaveLength(0);
    expect(Object.keys(queue.completed)).toHaveLength(0);
    await evidence(page, info, point);
  });
}

test('torture rapid answers, navigation, network flapping and snapshot', async ({ page, context, audit }, info) => {
  await start(page, context, info);
  // Two valid alternatives in this fixture: rapid A -> B -> A -> B.
  for (const name of [/Alternativa A, Um/, /Alternativa B, Dois/, /Alternativa A, Um/, /Alternativa B, Dois/]) {
    await answer(page, name);
  }
  const id = await assertDraft(page, { 0: 1 }, 0, []);
  // online -> offline -> online -> offline -> online. Final state is the oracle.
  for (const offline of [true, false, true, false]) {
    audit.offline = offline;
    await context.setOffline(offline);
    expect(await page.evaluate(() => navigator.onLine)).toBe(!offline);
    await button(page, 'Próxima').click();
    await answer(page, /Alternativa A, Três/);
    await button(page, 'Próxima').click();
    await answer(page, /Alternativa B, Seis/);
    await button(page, 'Anterior').click();
    await answer(page, /Alternativa B, Quatro/);
    await button(page, 'Próxima').click();
    await button(page, 'Anterior').click();
    await button(page, 'Anterior').click();
    await answer(page, /Alternativa B, Dois/);
  }
  for (const label of ['Marcar para revisão', 'Remover da revisão', 'Marcar para revisão']) {
    await button(page, label).click();
  }
  await assertDraft(page, { 0: 1, 1: 1, 2: 1 }, 0, [0], id);
  // Change only the QA source, never the attempt snapshot or answers.
  await page.evaluate(() => {
    const key = 'flutter.private_exams_v1';
    const exams = JSON.parse(JSON.parse(localStorage.getItem(key)));
    exams[0].questions.reverse();
    exams[0].questions[0].statement = 'QA catalog version B';
    localStorage.setItem(key, JSON.stringify(JSON.stringify(exams)));
  });
  await page.reload();
  await resume(page);
  await expect(text(page, 'QA: quanto é 1 + 1?')).toBeVisible();
  await selected(page, /Alternativa B, Dois/);
  await assertDraft(page, { 0: 1, 1: 1, 2: 1 }, 0, [0], id);
  await evidence(page, info, 'snapshot-A-after-catalog-B');
});

test('torture close page, reopen same context, finalize twice and reopen result', async ({ page, context }, info) => {
  await start(page, context, info);
  await answer(page, /Alternativa B, Dois/);
  const id = await assertDraft(page, { 0: 1 }, 0, []);
  await evidence(page, info, 'prova-390x844');
  await page.close();
  // New page, same context/profile/storage. This is not a new browser context.
  const reopened = await context.newPage();
  await open(reopened);
  await resume(reopened);
  await selected(reopened, /Alternativa B, Dois/);
  await assertDraft(reopened, { 0: 1 }, 0, [], id);
  await button(reopened, 'Revisar entrega').click();
  await button(reopened, 'Entregar mesmo com questões em branco').dblclick({ delay: 0 });
  await expect(text(reopened, '1 de 3 acertos')).toBeVisible();
  await expect.poll(async () => reopened.evaluate(() => {
    const queue = JSON.parse(JSON.parse(localStorage.getItem('flutter.attempt_sync_queue_v1')));
    return { ids: Object.keys(queue.completed), pending: queue.pending.length };
  })).toEqual({ ids: [id], pending: 0 });
  expect(await draft(reopened)).toBeNull();
  await evidence(reopened, info, 'resultado-390x844');
  await reopened.close();
  const history = await context.newPage();
  await open(history);
  await semantics(history);
  await clickText(history, 'Biblioteca');
  await clickText(history, 'Salva no aparelho');
  await expect(text(history, '1 de 3 acertos')).toBeVisible();
  await expect(text(history, 'Em branco: 2')).toBeVisible();
  await evidence(history, info, 'result-after-new-page');
});

test('post-torture smoke 390x844 home, prova, resultado', async ({ page, context }, info) => {
  await start(page, context, info);
  await answer(page, /Alternativa B, Dois/);
  await evidence(page, info, 'post-torture-prova');
  await button(page, 'Revisar entrega').click();
  await button(page, 'Entregar mesmo com questões em branco').click();
  await expect(text(page, '1 de 3 acertos')).toBeVisible();
  await evidence(page, info, 'post-torture-resultado');
});
