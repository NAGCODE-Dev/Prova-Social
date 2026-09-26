const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '..');
function setup() {
  const nodes = new Map();
  function node(id) {
    if (!nodes.has(id)) nodes.set(id, {textContent: '', dataset: {}, disabled: false,
      classList: {toggle() {}, remove() {}}, style: {setProperty(k, v) { this[k] = v; }},
      setAttribute(k, v) {this[k] = v;}, addEventListener(k, fn) {this[k] = fn;}});
    return nodes.get(id);
  }
  const answers = ['A','B','C','D'].map((a) => {const n = node(a); n.dataset.answer = a; return n;});
  const document = {querySelector: node, querySelectorAll(selector) {
    if (selector === '[data-answer]') return answers;
    if (selector === '[data-step]') return [0,1,2,3].map(i => node(`step${i}`));
    if (selector === '[data-apk]') return [node('apk')];
    return [];
  }};
  vm.runInNewContext(fs.readFileSync(path.join(root, 'app.js'), 'utf8'), {document, fetch: async () => {throw new Error('offline');}});
  return {node, answers};
}
test('simulator calculates result from the selected answer and can restart', () => {
  const {node, answers} = setup();
  answers[0].click(); assert.equal(node('[data-score]').textContent, '0/1');
  assert.match(node('[data-review]').textContent, /Uma questão errada/);
  answers[2].click(); assert.equal(node('[data-score]').textContent, '1/1');
  assert.match(node('[data-review]').textContent, /Nenhum erro/);
  assert.equal(node('.score-ring').style['--score'], '100%');
  node('[data-restart]').click(); assert.equal(node('[data-step="1"] [data-next]').disabled, true);
});
test('release failure preserves usable downloads link', async () => {
  const {node} = setup(); await new Promise(resolve => setImmediate(resolve));
  assert.equal(node('apk').href, 'https://github.com/NAGCODE-Dev/Prova-Social/releases');
});
function luminance(hex) { const rgb = hex.match(/\w\w/g).map(v => parseInt(v,16)/255).map(v => v <= .04045 ? v/12.92 : ((v+.055)/1.055)**2.4); return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722; }
test('dark palette has AA text contrast on all surfaces and keyboard/reduced-motion styles', () => {
  const css = fs.readFileSync(path.join(root, 'styles.css'), 'utf8');
  for (const surface of ['101311','181c19','202521']) for (const text of ['f3f5f3','aab2ac'])
    assert.ok((luminance(text)+.05)/(luminance(surface)+.05) >= 4.5);
  assert.match(css, /focus-visible/); assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /--bg:#101311/);
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.doesNotMatch(html, /FUVEST|01:42:18|90%|50%|80 questões/);
});
