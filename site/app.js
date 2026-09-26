const steps = ['Conheça o fluxo', 'Resolva uma questão', 'Veja onde melhorar', 'Refaça seus erros'];
let currentStep = 0;
const stepElements = [...document.querySelectorAll('[data-step]')];
const title = document.querySelector('[data-step-title]');
const count = document.querySelector('[data-step-count]');
const progress = document.querySelector('[data-progress]');

function renderStep(index) {
  currentStep = Math.max(0, Math.min(index, steps.length - 1));
  stepElements.forEach((element, position) => element.classList.toggle('active', position === currentStep));
  title.textContent = steps[currentStep];
  count.textContent = `${currentStep + 1} de ${steps.length}`;
  progress.style.width = `${((currentStep + 1) / steps.length) * 100}%`;
}

document.querySelectorAll('[data-next]').forEach(button => button.addEventListener('click', () => renderStep(currentStep + 1)));
document.querySelectorAll('[data-answer]').forEach(button => {
  button.addEventListener('click', () => {
    document.querySelectorAll('[data-answer]').forEach(item => {
      item.classList.toggle('selected', item === button);
      item.setAttribute('aria-pressed', String(item === button));
    });
    const correct = button.dataset.answer === 'C';
    document.querySelector('[data-score]').textContent = correct ? '1/1' : '0/1';
    document.querySelector('.score-ring').style.setProperty('--score', correct ? '100%' : '0%');
    document.querySelector('[data-result]').textContent = correct ? 'Você acertou este exercício.' : 'Este exercício precisa de revisão.';
    document.querySelector('[data-feedback]').textContent = '6 × 4 = 24: seis grupos de quatro unidades.';
    document.querySelector('[data-review]').textContent = correct ? 'Nenhum erro nesta tentativa. Experimente com sua própria prova.' : 'Uma questão errada nesta tentativa. Revise a explicação e tente novamente.';
    document.querySelector('[data-answer-hint]').textContent = `Alternativa ${button.dataset.answer} selecionada.`;
    document.querySelector('[data-step="1"] [data-next]').disabled = false;
  });
});

document.querySelector('[data-restart]').addEventListener('click', () => {
  document.querySelectorAll('[data-answer]').forEach(item => { item.classList.remove('selected'); item.setAttribute('aria-pressed', 'false'); });
  document.querySelector('[data-answer-hint]').textContent = 'Escolha uma alternativa para continuar.';
  document.querySelector('[data-step="1"] [data-next]').disabled = true;
  renderStep(0);
});

async function loadRelease() {
  const buttons = document.querySelectorAll('[data-apk]');
  try {
    const response = await fetch('https://api.github.com/repos/NAGCODE-Dev/Prova-Social/releases/latest');
    if (!response.ok) throw new Error('Release indisponível');
    const release = await response.json();
    const asset = release.assets.find(item => /arm64-v8a.*\.apk$/i.test(item.name)) || release.assets.find(item => /prova-social.*\.apk$/i.test(item.name)) || release.assets.find(item => /\.apk$/i.test(item.name));
    if (asset) buttons.forEach(button => { button.href = asset.browser_download_url; });
    if (release.tag_name) document.querySelector('[data-version]').textContent = `Versão ${release.tag_name} · Android e Web`;
  } catch (_) {
    buttons.forEach(button => { button.href = 'https://github.com/NAGCODE-Dev/Prova-Social/releases'; });
  }
}

renderStep(0);
loadRelease();
