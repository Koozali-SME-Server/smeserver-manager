document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.pkg-picker').forEach(picker => {
    const input  = picker.querySelector('.pkg-search');
    const select = picker.querySelector('.pkg-list');
    if (!input || !select) return;

    const opts = Array.from(select.options).map(o => ({
      opt: o,
      text: (o.textContent || '').toLowerCase()
    }));

    input.addEventListener('input', () => {
      const q = input.value.trim().toLowerCase();
      opts.forEach(({opt, text}) => {
        opt.hidden = q && !text.includes(q);
      });
    });
  });
});

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.pkg-picker').forEach(picker => {
    const input  = picker.querySelector('.pkg-search');
    const clear  = picker.querySelector('.pkg-clear');
    const msg    = picker.querySelector('.pkg-filter-msg');
    const select = picker.querySelector('.pkg-list');
    if (!input || !select) return;

    const options = Array.from(select.options).map(o => ({
      el: o,
      textLower: (o.textContent || '').toLowerCase(),
      textRaw: (o.textContent || '')
    }));

    function parseQuery(q) {
      q = (q || '').trim();

      // Regex form: /pattern/flags  e.g. /maria.*client/i
      const m = q.match(/^\/(.+)\/([gimsuy]*)$/);
      if (m) {
        try {
          return { type: 'regex', re: new RegExp(m[1], m[2]) };
        } catch (e) {
          return { type: 'invalid', error: e.message || String(e) };
        }
      }

      // Normal substring search (case-insensitive)
      return { type: 'text', text: q.toLowerCase() };
    }

    function setError(text) {
      if (!msg) return;
      if (text) {
        msg.textContent = text;
        msg.classList.add('show');   // .show { display:block; }
      } else {
        msg.textContent = '';
        msg.classList.remove('show');
      }
    }

    function setVisibility(predicate) {
      options.forEach(({el, textLower, textRaw}) => {
        el.hidden = !predicate(textLower, textRaw);
      });
    }

    function showAll() {
      options.forEach(({el}) => (el.hidden = false));
    }

    function applyFilter() {
      const qraw = input.value || '';
      const parsed = parseQuery(qraw);

      if (clear) clear.style.display = qraw.trim() ? 'block' : 'none';

      // Invalid regex: show error and KEEP previous list state
      if (parsed.type === 'invalid') {
        setError(`Invalid regex: ${parsed.error}`);
        return;
      }

      // Valid query => clear any prior error
      setError('');

      if (parsed.type === 'text') {
        const q = parsed.text;
        setVisibility((textLower) => !q || textLower.includes(q));
      } else if (parsed.type === 'regex') {
        const re = parsed.re;
        setVisibility((_textLower, textRaw) => re.test(textRaw));
      }
    }

    input.addEventListener('input', applyFilter);

    if (clear) {
      clear.addEventListener('click', () => {
        input.value = '';
        input.focus();
        setError('');
        showAll();
        clear.style.display = 'none';
      });
    }

    // Initial state
    setError('');
    showAll();
    if (clear) clear.style.display = 'none';
  });
});
