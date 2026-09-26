import { test, expect, text, button, clickText, evidence, semantics, open, seed, onboard, layout, selected, draft } from './harness.mjs';
import { publicExam } from './fixtures.mjs';

test('smoke, onboarding, navegação e reload', async ({ page }, info) => {
  await open(page);
  await onboard(page, info);
  await evidence(page, info, `${info.project.name}-home`);
  for (const [destination, heading] of [
    ['Explorar', 'Busca global'], ['Publicar', 'Criar manualmente'],
    ['Biblioteca', 'Sua biblioteca'], ['Perfil', 'Você está explorando sem conta'],
    ['Início', 'Encontre sua próxima prova'],
  ]) {
    await clickText(page, destination);
    await expect(text(page, heading)).toBeVisible();
    await layout(page);
  }
  await page.reload();
  await semantics(page);
  await expect(text(page, 'Encontre sua próxima prova')).toBeVisible();
  if (info.project.name === 'desktop') {
    await page.keyboard.press('Tab');
    expect(await page.evaluate(() => {
      const focused = document.activeElement;
      return focused !== document.body &&
        Boolean(focused?.getAttribute('aria-label') || focused?.textContent?.trim());
    }), 'Tab reaches an identifiable control').toBe(true);
    await page.emulateMedia({ colorScheme: 'dark' });
    await clickText(page, 'Biblioteca');
    await expect(text(page, 'Sua biblioteca')).toBeVisible();
    await evidence(page, info, 'desktop-dark');
  }
});

test('busca com fixture, vazio e login contextual', async ({ page }, info) => {
  test.skip(info.project.name !== 'mobile', 'Full flow runs once at 390x844.');
  await open(page);
  await button(page, 'Pular').click();
  await clickText(page, 'Explorar');
  const search = page.getByRole('textbox', { name: 'Buscar provas, concursos e matérias' });
  await search.fill('matemática');
  await clickText(page, publicExam.title);
  await expect(button(page, 'Começar prova')).toBeVisible();
  await expect(text(page, 'Fonte não verificada')).toBeVisible();
  await button(page, 'Salvar na biblioteca').click();
  await button(page, 'Entrar ou criar conta').click();
  await expect(page.getByRole('textbox', { name: 'E-mail' })).toBeVisible();
  await evidence(page, info, 'login-contextual');
  await button(page, 'Fechar').click();
  // Fresh navigation, same browser storage: no credentials/session were created.
  await page.reload();
  await semantics(page);
  await clickText(page, 'Explorar');
  await search.fill('zzzz-sem-resultado-qa');
  await expect(text(page, 'Nenhum resultado encontrado.')).toBeVisible();
  await search.fill('');
  await expect(text(page, 'Pesquise no catálogo público, mesmo sem conta.')).toBeVisible();
});

test('P0 privado: persistência, reload, offline real, resultado e revisão', async ({ page, context, audit }, info) => {
  test.skip(info.project.name !== 'mobile', 'Full flow runs once at 390x844.');
  await seed(context);
  await open(page);
  await button(page, 'Pular').click();
  await clickText(page, 'Biblioteca');
  await button(page, 'Fazer prova').click();
  await button(page, 'Começar prova').click();
  await expect(text(page, 'QA: quanto é 1 + 1?')).toBeVisible();
  const first = page.getByRole('button', { name: /Alternativa A, Um/ });
  const second = page.getByRole('button', { name: /Alternativa B, Dois/ });
  await first.click();
  await second.click();
  await expect.poll(async () => (await draft(page))?.answers['0']).toBe(1);
  for (let n = 0; n < 3; n++) {
    await button(page, 'Próxima').click();
    await button(page, 'Anterior').click();
  }
  await selected(page, /Alternativa B, Dois/);
  await button(page, 'Próxima').click();
  await page.getByRole('button', { name: /Alternativa B, Quatro/ }).click();
  await button(page, 'Marcar para revisão').click();
  await expect.poll(async () => (await draft(page))?.review).toEqual([1]);
  await evidence(page, info, 'prova-em-andamento');
  await button(page, 'Sair da prova').click();
  await expect(text(page, 'Pausar esta prova?')).toBeVisible();
  await button(page, 'Continuar').click();
  await button(page, 'Sair da prova').click();
  await button(page, 'Sair').click();
  await clickText(page, 'Continuar — disponível offline');
  await expect(text(page, 'QA: quanto é 2 + 2?')).toBeVisible();
  await selected(page, /Alternativa B, Quatro/);
  const before = await draft(page);
  await page.reload();
  await semantics(page);
  await clickText(page, 'Biblioteca');
  await clickText(page, 'Continuar — disponível offline');
  await expect(text(page, 'QA: quanto é 2 + 2?')).toBeVisible();
  await selected(page, /Alternativa B, Quatro/);
  await expect(button(page, 'Remover da revisão')).toBeVisible();
  const after = await draft(page);
  expect(after.answers).toEqual(before.answers);
  expect(after.current).toBe(1);
  expect(after.review).toEqual([1]);
  expect(after.clientAttemptId).toBe(before.clientAttemptId);
  await evidence(page, info, 'retomada-apos-reload');

  audit.offline = true;
  await context.setOffline(true);
  expect(await page.evaluate(async () => {
    try { await fetch('/__qa/health', { cache: 'no-store', signal: AbortSignal.timeout(3000) }); return false; }
    catch { return true; }
  })).toBe(true);
  expect(await page.evaluate(() => navigator.onLine)).toBe(false);
  await page.getByRole('button', { name: /Alternativa A, Três/ }).click();
  await expect.poll(async () => (await draft(page))?.answers['1']).toBe(0);
  await button(page, 'Próxima').click();
  await expect(text(page, 'QA: quanto é 3 + 3?')).toBeVisible();
  await button(page, 'Revisar entrega').click();
  await expect(text(page, '2 de 3 respondidas')).toBeVisible();
  await expect(text(page, 'Não respondidas')).toBeVisible();
  await expect(text(page, 'Marcadas para revisão')).toBeVisible();
  await button(page, 'Continuar revisando').click();
  await button(page, 'Revisar entrega').click();
  const deliver = button(page, 'Entregar mesmo com questões em branco');
  await expect(deliver).toBeInViewport();
  // Two physical clicks at the same point; no forced DOM action after dismissal.
  await deliver.dblclick({ delay: 40 });
  await expect(text(page, '1 de 3 acertos')).toBeVisible();
  await expect(text(page, '33%')).toBeVisible();
  for (const label of ['Erradas: 1', 'Em branco: 1', 'Marcadas: 1']) {
    await text(page, label).scrollIntoViewIfNeeded();
    await expect(text(page, label)).toBeVisible();
  }
  for (const label of ['Fonte não verificada', 'Sua resposta: Três', 'Gabarito: Quatro', 'Sua resposta: Em branco']) {
    await text(page, label).scrollIntoViewIfNeeded();
    await expect(text(page, label)).toBeVisible();
  }
  await expect(page.getByText(/NaN|Infinity/)).toHaveCount(0);
  await evidence(page, info, 'resultado-revisao-offline');
  const counts = await page.evaluate(() => {
    const queue = JSON.parse(JSON.parse(localStorage.getItem('flutter.attempt_sync_queue_v1')));
    return { completed: Object.keys(queue.completed).length, pending: queue.pending.length };
  });
  expect(counts).toEqual({ completed: 1, pending: 0 });
  await context.setOffline(false);
  audit.offline = false;
  await page.reload();
  await semantics(page);
  await clickText(page, 'Biblioteca');
  await clickText(page, 'Salva no aparelho');
  await expect(text(page, '1 de 3 acertos')).toBeVisible();
  await evidence(page, info, 'resultado-restaurado');
});
