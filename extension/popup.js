const CryptoService = (() => {
  function getRandomBytes(length) {
    const buf = new Uint8Array(length);
    crypto.getRandomValues(buf);
    return buf;
  }

  function nextInt(max) {
    if (max <= 0) return 0;
    const bitsNeeded = Math.ceil(Math.log2(max + 1));
    const bytesNeeded = Math.ceil(bitsNeeded / 8);
    const mask = (1 << bitsNeeded) - 1;
    let value;
    do {
      const buf = getRandomBytes(bytesNeeded);
      value = 0;
      for (let i = 0; i < bytesNeeded; i++) value = (value << 8) | buf[i];
      value = value & mask;
    } while (value >= max);
    return value;
  }

  return { nextInt };
})();

const state = {
  length: 16,
  upper: true,
  lower: true,
  digits: true,
  symbols: true,
  avoidAmbiguous: true,
  minDigits: 1,
  minSymbols: 1,
  generated: '',
};

const LOWER   = 'abcdefghijklmnopqrstuvwxyz';
const UPPER   = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const DIGITS  = '0123456789';
const SYMBOLS = '!@#$%^&*()-_=+[]{};:,.<>?';
const AMBIGUOUS = 'O0Il1';

function buildAlphabet() {
  let s = '';
  if (state.lower)   s += LOWER;
  if (state.upper)   s += UPPER;
  if (state.digits)  s += DIGITS;
  if (state.symbols) s += SYMBOLS;
  if (state.avoidAmbiguous) {
    s = s.split('').filter(c => !AMBIGUOUS.includes(c)).join('');
  }
  return s;
}

function filteredSource(source) {
  return state.avoidAmbiguous
    ? source.split('').filter(c => !AMBIGUOUS.includes(c)).join('')
    : source;
}

function generate() {
  const alphabet = buildAlphabet();
  if (!alphabet) return '';

  const chars = [];

  if (state.digits) {
    const src = filteredSource(DIGITS);
    for (let i = 0; i < state.minDigits; i++) {
      if (src) chars.push(src[CryptoService.nextInt(src.length)]);
    }
  }
  if (state.symbols) {
    const src = filteredSource(SYMBOLS);
    for (let i = 0; i < state.minSymbols; i++) {
      if (src) chars.push(src[CryptoService.nextInt(src.length)]);
    }
  }

  while (chars.length < state.length) {
    chars.push(alphabet[CryptoService.nextInt(alphabet.length)]);
  }

  if (chars.length > state.length) chars.splice(state.length);

  for (let i = chars.length - 1; i > 0; i--) {
    const j = CryptoService.nextInt(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }

  return chars.join('');
}

function strengthScore(pw) {
  if (!pw) return 0;
  let score = 0;
  if (pw.length >= 8)  score += 15;
  if (pw.length >= 12) score += 25;
  if (pw.length >= 16) score += 25;
  if (/[a-z]/.test(pw))      score += 10;
  if (/[A-Z]/.test(pw))      score += 10;
  if (/\d/.test(pw))          score += 10;
  if (/[^A-Za-z0-9]/.test(pw)) score += 10;
  return Math.min(score, 100);
}

function strengthLabel(score) {
  if (score >= 80) return 'Muy fuerte';
  if (score >= 60) return 'Fuerte';
  if (score >= 40) return 'Media';
  return 'Débil';
}

function strengthColor(score) {
  if (score >= 80) return '#2563eb';
  if (score >= 60) return '#3b82f6';
  if (score >= 40) return '#f59e0b';
  return '#ef4444';
}

const $ = id => document.getElementById(id);

function updateUI() {
  $('sliderLen').value = state.length;
  $('lenVal').textContent = state.length;

  setToggleActive('togUpper',     state.upper);
  setToggleActive('togLower',     state.lower);
  setToggleActive('togDigits',    state.digits);
  setToggleActive('togSymbols',   state.symbols);
  setToggleActive('togAmbiguous', state.avoidAmbiguous);

  $('valMinDigits').textContent  = state.minDigits;
  $('valMinSymbols').textContent = state.minSymbols;
  $('rowMinDigits').classList.toggle('disabled',  !state.digits);
  $('rowMinSymbols').classList.toggle('disabled', !state.symbols);

  const display = $('pwDisplay');
  if (state.generated) {
    display.textContent = state.generated;
    display.classList.remove('placeholder');
  } else {
    display.textContent = 'Pulsa «Generar»';
    display.classList.add('placeholder');
  }

  const score = strengthScore(state.generated);
  const fill  = $('barFill');
  fill.style.width      = state.generated ? score + '%' : '0%';
  fill.style.background = strengthColor(score);
  $('strengthLabel').textContent = state.generated ? strengthLabel(score) : '—';
  $('strengthLabel').style.color = state.generated ? strengthColor(score) : 'var(--muted)';

  $('pwBox').classList.toggle('has-password', !!state.generated);

  $('btnCopy').disabled = !state.generated;
}

function setToggleActive(id, active) {
  $( id ).classList.toggle('active', active);
}

function showToast() {
  const t = $('toast');
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 1800);
}

function constrainMins() {
  while (state.minDigits + state.minSymbols > state.length) {
    if (state.minSymbols > 0) state.minSymbols--;
    else if (state.minDigits > 0) state.minDigits--;
    else break;
  }
}

document.addEventListener('DOMContentLoaded', () => {

  $('sliderLen').addEventListener('input', e => {
    state.length = parseInt(e.target.value, 10);
    constrainMins();
    updateUI();
  });

  $('togUpper').addEventListener('click', () => {
    state.upper = !state.upper;
    updateUI();
  });
  $('togLower').addEventListener('click', () => {
    state.lower = !state.lower;
    updateUI();
  });
  $('togDigits').addEventListener('click', () => {
    state.digits = !state.digits;
    if (!state.digits) state.minDigits = 0;
    updateUI();
  });
  $('togSymbols').addEventListener('click', () => {
    state.symbols = !state.symbols;
    if (!state.symbols) state.minSymbols = 0;
    updateUI();
  });
  $('togAmbiguous').addEventListener('click', () => {
    state.avoidAmbiguous = !state.avoidAmbiguous;
    updateUI();
  });

  $('decDigits').addEventListener('click', () => {
    if (state.minDigits > 0) { state.minDigits--; updateUI(); }
  });
  $('incDigits').addEventListener('click', () => {
    if (state.digits && (state.minDigits + state.minSymbols < state.length)) {
      state.minDigits++; updateUI();
    }
  });
  $('decSymbols').addEventListener('click', () => {
    if (state.minSymbols > 0) { state.minSymbols--; updateUI(); }
  });
  $('incSymbols').addEventListener('click', () => {
    if (state.symbols && (state.minDigits + state.minSymbols < state.length)) {
      state.minSymbols++; updateUI();
    }
  });

  $('btnGenerate').addEventListener('click', () => {
    state.generated = generate();
    updateUI();
    const d = $('pwDisplay');
    d.style.transition = 'opacity .1s';
    d.style.opacity = '0';
    requestAnimationFrame(() => {
      requestAnimationFrame(() => { d.style.opacity = '1'; });
    });
  });

  $('btnCopy').addEventListener('click', async () => {
    if (!state.generated) return;
    try {
      await navigator.clipboard.writeText(state.generated);
      showToast();
    } catch {
      const ta = document.createElement('textarea');
      ta.value = state.generated;
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      showToast();
    }
  });

  updateUI();
});
