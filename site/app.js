const steps = ['Importe uma prova', 'Resolva uma questão', 'Veja onde melhorar', 'Refaça seus erros'];
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
      item.setAttribute('aria-checked', String(item === button));
    });
    document.querySelector('[data-answer-hint]').textContent = `Alternativa ${button.dataset.answer} selecionada.`;
    document.querySelector('[data-step="1"] [data-next]').disabled = false;
  });
});

document.querySelector('[data-restart]').addEventListener('click', () => {
  document.querySelectorAll('[data-answer]').forEach(item => { item.classList.remove('selected'); item.setAttribute('aria-checked', 'false'); });
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
