(function () {
  const BASE = '/smanager'; // reverse proxy prefix

  function parseQuery(q) {
    q = (q || '').trim();
    const m = q.match(/^\/(.+)\/([gimsuy]*)$/);
    if (m) {
      try { return { type: 'regex', re: new RegExp(m[1], m[2]) }; }
      catch (e) { return { type: 'invalid', error: e.message || String(e) }; }
    }
    return { type: 'text', text: q.toLowerCase() };
  }

  function initPkgPicker(picker) {
    const input  = picker.querySelector('.pkg-search');
    const clear  = picker.querySelector('.pkg-clear');
    const msg    = picker.querySelector('.pkg-filter-msg');
    const select = picker.querySelector('.pkg-list');
    if (!input || !select) return;

    function setError(text) {
      if (!msg) return;
      if (text) { msg.textContent = text; msg.classList.add('show'); }
      else { msg.textContent = ''; msg.classList.remove('show'); }
    }

    function opts() {
      return Array.from(select.options).map(o => ({
        el: o,
        textLower: (o.textContent || '').toLowerCase(),
        textRaw: (o.textContent || '')
      }));
    }

    function showAll() { opts().forEach(({ el }) => (el.hidden = false)); }

    function applyFilter() {
      const o = opts();
      const qraw = input.value || '';
      const parsed = parseQuery(qraw);

      if (clear) clear.style.display = qraw.trim() ? 'block' : 'none';
      if (parsed.type === 'invalid') { setError(`Invalid regex: ${parsed.error}`); return; }
      setError('');

      if (parsed.type === 'text') {
        const q = parsed.text;
        o.forEach(({ el, textLower }) => { el.hidden = !!q && !textLower.includes(q); });
      } else {
        const re = parsed.re;
        o.forEach(({ el, textRaw }) => { el.hidden = !re.test(textRaw); });
      }
    }

    if (!picker.dataset.pkgPickerBound) {
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
      picker.dataset.pkgPickerBound = '1';
    }

    setError('');
    showAll();
    if (clear) clear.style.display = 'none';
  }

  function initAllPkgPickers(root = document) {
    root.querySelectorAll('.pkg-picker').forEach(initPkgPicker);
  }

  function selectedValues(selectEl) {
    if (!selectEl) return [];
    return Array.from(selectEl.selectedOptions).map(o => o.value);
  }

  async function refreshControls(mode) {
    const fn = mode || 'update';

    const partialUrl = new URL(`${BASE}/dnf/partial`, window.location.origin);
    partialUrl.searchParams.set('function', fn);
    partialUrl.searchParams.set('ts', Date.now());

    const r = await fetch(partialUrl.toString(), { method: 'GET' });
    if (!r.ok) {
      const text = await r.text().catch(() => '');
      throw new Error(`partial refresh failed (HTTP ${r.status}) ${text.slice(0, 120)}`);
    }

    const html = await r.text();
    const tmp = document.createElement('div');
    tmp.innerHTML = html;

    const newControls = tmp.querySelector('#dnf-controls');
    const oldControls = document.querySelector('#dnf-controls');
    if (!newControls || !oldControls) throw new Error('partial refresh failed: #dnf-controls not found');

    oldControls.replaceWith(newControls);

    initAllPkgPickers(document);
    initDnfPanel();
  }

  function currentMode() {
    const msgEl = document.getElementById('dnf-msg');
    return (msgEl && msgEl.dataset.mode) ? msgEl.dataset.mode : 'update';
  }

  function initDnfTabs(controls) {
    const tabs = Array.from(controls.querySelectorAll('button.dnf-tab'));
    if (!tabs.length) return;

    if (controls.dataset.tabsBound === '1') return;
    controls.dataset.tabsBound = '1';

    // Bind directly to buttons (more robust than delegated click)
    tabs.forEach(tab => {
      tab.addEventListener('click', (e) => {
        const mode = tab.dataset.mode;
        if (!mode) return;
        e.preventDefault();

        const u = new URL(window.location.href);
        u.pathname = u.pathname.replace(/\/dnfd$/, '/dnf'); //Sometimes is is running in the dnfd window
        u.searchParams.set('function', mode);
        window.location.href = u.toString();
      });
    });
  }

  function initDnfPanel() {
    const controls = document.getElementById('dnf-controls');
    if (!controls) return;

    initDnfTabs(controls);

    // Prevent duplicate listeners after partial replacement
    if (controls.dataset.bound === '1') return;
    controls.dataset.bound = '1';

    const startBtn = document.getElementById('dnf-start');
    const frame    = document.getElementById('dnf-frame');
    const pkgSel   = document.getElementById('SelectedPackages');
    const grpSel   = document.getElementById('SelectedGroups');

    // IMPORTANT: match your actual DOM
    const out = document.getElementById('dnf-output') || document.querySelector('.dnf-update-output');

    function updateOutputVisibility() {
      if (!out) return;
      const mode = currentMode();
      if (mode === 'configure') out.classList.add('is-hidden');
      else out.classList.remove('is-hidden');
    }

    function updateSelectedNoteAndStart() {
      const msgEl  = document.getElementById('dnf-msg');
      const noteEl = document.getElementById('dnf-selected-note');
      if (!msgEl || !startBtn) return;

      const mode = msgEl.dataset.mode || 'update';

      updateOutputVisibility();

      if (mode === 'configure') {
        startBtn.disabled = true;
        if (noteEl) noteEl.textContent = '';
        return;
      }

      const pkgTotal = Number(msgEl.dataset.pkgTotal || 0);
      const grpTotal = Number(msgEl.dataset.grpTotal || 0);

      if (dnfBusy) {
        // A run is already in progress: keep Start disabled and leave the
        // "still running" note (set by checkForRunningJob) alone rather than
        // overwriting it with selection counts.
        startBtn.disabled = true;
        return;
      }

      const pkgSelected = pkgSel ? pkgSel.selectedOptions.length : 0;
      const grpSelected = grpSel ? grpSel.selectedOptions.length : 0;

      const total    = pkgTotal + grpTotal;
      const selected = pkgSelected + grpSelected;

      if (total === 0) {
        startBtn.disabled = true;
        if (noteEl) noteEl.textContent = '';
        return;
      }

      startBtn.disabled = (selected === 0);

      if (!noteEl) return;

      const what =
        (mode === 'update')  ? 'update(s)' :
        (mode === 'install') ? 'install(s)' :
                               'remove(s)';

      if (selected === total) noteEl.textContent = `All selected (${total} ${what}).`;
      else if (selected === 0) noteEl.textContent = `None selected (0 of ${total} ${what}).`;
      else noteEl.textContent = `${selected} of ${total} selected (${what}).`;
    }

    // True while a dnf run (started here, in another tab, or by another
    // admin) is known to still be in progress. While true the Start button
    // stays disabled regardless of package/group selection.
    let dnfBusy = false;

    updateSelectedNoteAndStart();
    if (pkgSel) pkgSel.addEventListener('change', updateSelectedNoteAndStart);
    if (grpSel) grpSel.addEventListener('change', updateSelectedNoteAndStart);

    let runStarted = false;

    // On (re)entry to the panel -- initial load, tab switch, or after a
    // partial refresh -- check whether a dnf run is already in progress
    // (e.g. it was started before a page reload, or from another session).
    // If so, suppress Start and re-attach the log viewer to that run instead
    // of leaving the panel looking idle.
    async function checkForRunningJob() {
      try {
        const r = await fetch(`${BASE}/dnf/status`, { method: 'GET' });
        if (!r.ok) return;
        const data = await r.json().catch(() => ({}));
        if (!data || !data.running) return;

        dnfBusy = true;
        if (startBtn) startBtn.disabled = true;

        const noteEl = document.getElementById('dnf-selected-note');
        if (noteEl) {
          noteEl.textContent = data.function
            ? `A previous ${data.function} is still running \u2014 showing its progress below.`
            : 'A previous DNF operation is still running \u2014 showing its progress below.';
        }

        if (currentMode() !== 'configure' && frame && data.logfile) {
          if (out) out.classList.remove('is-hidden');

          const url = new URL(`${BASE}/dnf/stream/resume-${Date.now()}`, window.location.origin);
          url.searchParams.set('logfile', data.logfile);

          runStarted = true; // reuse the normal completion path (refresh + re-enable)
          frame.src = url.toString();
        }
      } catch (e) {
        // Non-fatal: if the status check fails, just leave the panel in its
        // normal (idle) state rather than blocking the user.
      }
    }

    checkForRunningJob();

    if (startBtn) {
      startBtn.addEventListener('click', async () => {
        const mode = currentMode();
        if (mode === 'configure') return;

        startBtn.disabled = true;

        try {
          const fn = encodeURIComponent(mode || 'update');

          const body = new URLSearchParams();
          selectedValues(pkgSel).forEach(v => body.append('SelectedPackages', v));
          selectedValues(grpSel).forEach(v => body.append('SelectedGroups', v));
          // The Configure tab's form is always present in the DOM (just CSS-hidden
          // on other tabs), and CSRFProtectBuiltin auto-injects a csrf_token hidden
          // field into it via the wrapped form_for helper. Reuse that token here,
          // mirroring the working pattern already used in datetime.js.
          const csrfToken = document.querySelector(
            '#dnf-config-form input[name="csrf_token"]'
          )?.value;

          const r = await fetch(`${BASE}/dnf/start/${fn}`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
              'X-CSRF-Token': csrfToken
            },
            body
          });

          const data = await r.json().catch(() => ({}));
          if (!r.ok) throw new Error((data && data.error) ? data.error : `start failed (HTTP ${r.status})`);

          const url = new URL(`${BASE}/dnf/stream/${encodeURIComponent(data.run_id)}`, window.location.origin);
          url.searchParams.set('started_i', data.started_i);
          url.searchParams.set('old_db', data.old_db || '');

          runStarted = true;
          if (out) out.classList.remove('is-hidden');
          if (frame) frame.src = url.toString() + '&ts=' + Date.now();

        } catch (e) {
          window.alert(String(e));
          startBtn.disabled = false;
          runStarted = false;
        }
      });
    }

    if (frame) {
      frame.addEventListener('load', () => {
        if (runStarted) {
          runStarted = false;
          const mode = currentMode();

          setTimeout(() => {
            refreshControls(mode)
              .catch(e => window.alert(String(e)))
              .finally(() => updateSelectedNoteAndStart());
          }, 500);

          return;
        }

        updateSelectedNoteAndStart();
      });
    }

    // Ensure correct state immediately
    updateOutputVisibility();
  }

  document.addEventListener('DOMContentLoaded', () => {
    initAllPkgPickers(document);
    initDnfPanel();
  });
})();
