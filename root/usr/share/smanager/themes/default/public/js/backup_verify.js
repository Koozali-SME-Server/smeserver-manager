(function () {
  "use strict";
  var stateNode = document.getElementById('verify-state');
  if (!stateNode) return;
  var statusUrl = stateNode.getAttribute('data-status-url') || '';
  var progressNode = document.getElementById('verify-progress');
  var progressBar = document.getElementById('verify-progress-bar');
  var progressFill = document.getElementById('verify-progress-fill');
  var progressLabel = document.getElementById('verify-progress-label');
  var currentNode = document.getElementById('verify-current');
  var archivesNode = document.getElementById('verify-archives');
  var outputNode = document.getElementById('verify-output');
  var finished = false;
  var summaryPanel = document.getElementById('verify-summary-panel');
  var summaryNode = document.getElementById('verify-summary');
  var summaryState = document.getElementById('verify-summary-state');

  function newestFirst(value) {
    if (!Array.isArray(value)) return '';
    return value.slice().reverse().map(function (item) {
      if (typeof item === 'string') return item;
      if (item && typeof item === 'object') {
        if (item.archive !== undefined) {
          return item.archive + ' — ' + (item.mode || '') + ' — exit ' +
            (item.exit_code === undefined ? 'unknown' : item.exit_code);
        }
        return JSON.stringify(item);
      }
      return String(item);
    }).join('\n');
  }

  function renderSummary(data, finalState) {
    if (!summaryNode) return;
    var archives = Array.isArray(data.archives) ? data.archives : [];
    var passed = archives.filter(function (a) { return Number(a.exit_code) === 0; }).length;
    var failed = archives.length - passed;
    var output = Array.isArray(data.output) ? data.output.join('\n') : '';
    var warnings = (output.match(/\bwarn(?:ing)?\b/gi) || []).length;
    var errors = (output.match(/\berror\b|\bfatal\b/gi) || []).length;
    var elapsed = (Number(data.finished || Date.now()/1000) - Number(data.started || Date.now()/1000));
    var rows = [
      ['Verification result', data.state === 'succeeded' ? 'Passed' : (data.state === 'failed' ? 'Failed' : 'In progress')],
      ['Archives checked', String(archives.length)],
      ['Archive checks passed', String(passed)],
      ['Archive checks failed', String(failed)],
      ['Warnings in retained output', String(warnings)],
      ['Errors in retained output', String(errors)],
      ['Elapsed time', Math.max(0, Math.round(elapsed)) + ' seconds'],
      ['Current archive', data.current || '—'],
      ['Activity lines retained', String(Array.isArray(data.output) ? data.output.length : 0)]
    ];
    summaryNode.textContent = '';
    var table = document.createElement('table');
    table.className = 'job-summary-grid';
    for (var i = 0; i < rows.length; i += 2) {
      var tr = document.createElement('tr');
      [rows[i], rows[i + 1] || null].forEach(function (row) {
        if (!row) {
          var emptyLabel = document.createElement('th');
          var emptyValue = document.createElement('td');
          emptyLabel.className = 'job-summary-empty';
          emptyValue.className = 'job-summary-empty';
          tr.appendChild(emptyLabel);
          tr.appendChild(emptyValue);
          return;
        }
        var th = document.createElement('th');
        var td = document.createElement('td');
        th.textContent = row[0];
        td.textContent = row[1];
        tr.appendChild(th);
        tr.appendChild(td);
      });
      table.appendChild(tr);
    }
    summaryNode.appendChild(table);
    if (summaryState) summaryState.textContent = data.state === 'succeeded' ? ' — Passed' : (data.state === 'failed' ? ' — Failed' : ' — Running');
    // Keep the summary collapsed by default; the operator can expand it when needed.
    // Do not automatically open it at completion: preserve screen space for activity.
  }

  function poll() {
    if (finished || !statusUrl) return;
    fetch(statusUrl, {credentials: 'same-origin', cache: 'no-store'})
      .then(function (response) {
        if (!response.ok) throw new Error('Status request failed (HTTP ' + response.status + ')');
        return response.json();
      })
      .then(function (data) {
        stateNode.textContent = 'Status: ' + (data.state || 'unknown') +
          (data.message ? ' — ' + data.message : '');
        var completed = Number(data.completed || 0);
        var total = Number(data.total || 0);
        progressNode.textContent = 'Archives completed: ' + completed +
          (total > 0 ? ' of ' + total : '');
        if (progressBar && progressFill) {
          progressBar.classList.remove('job-progress-complete', 'job-progress-failed');
          var terminal = data.state === 'succeeded' || data.state === 'failed';
          if (total > 0 && !terminal && completed < total) {
            // Archive-level progress cannot show DAR's internal read percentage.
            // Animate while the current archive is being tested instead of
            // displaying a misleading stationary 0% bar.
            progressBar.classList.add('job-progress-indeterminate');
            progressFill.style.width = '';
            progressFill.style.animation = '';
            progressBar.removeAttribute('aria-valuenow');
            progressBar.setAttribute('aria-valuetext',
              'Testing archive; ' + completed + ' of ' + total + ' archives completed');
            if (progressLabel) progressLabel.textContent = 'Testing…';
          } else if (total > 0) {
            var percent = Math.max(0, Math.min(100, Math.round(completed * 100 / total)));
            progressBar.classList.remove('job-progress-indeterminate');
            progressFill.style.width = percent + '%';
            progressFill.style.animation = 'none';
            progressBar.setAttribute('aria-valuenow', String(percent));
            progressBar.setAttribute('aria-valuetext', percent + '% complete');
            if (progressLabel) progressLabel.textContent = percent + '%';
          } else {
            progressBar.classList.add('job-progress-indeterminate');
            progressFill.style.width = '';
            progressFill.style.animation = '';
            progressBar.removeAttribute('aria-valuenow');
            progressBar.setAttribute('aria-valuetext', 'Verification in progress');
            if (progressLabel) progressLabel.textContent = 'Verification running…';
          }
        }
        currentNode.textContent = data.current ? 'Current archive: ' + data.current : '';
        archivesNode.textContent = newestFirst(data.archives);
        renderSummary(data, data.state === 'succeeded' || data.state === 'failed');
        outputNode.textContent = newestFirst(data.output);
        outputNode.scrollTop = 0;
        archivesNode.scrollTop = 0;

        if (data.state === 'succeeded' || data.state === 'failed') {
          finished = true;
          if (progressBar && progressFill) {
            progressBar.classList.remove('job-progress-indeterminate');
            progressBar.classList.add(data.state === 'succeeded' ? 'job-progress-complete' : 'job-progress-failed');
            progressFill.style.width = '100%';
            progressFill.style.animation = 'none';
            progressBar.setAttribute('aria-valuenow', '100');
            progressBar.setAttribute('aria-valuetext', data.state === 'succeeded' ? 'Verification complete' : 'Verification failed');
            if (progressLabel) progressLabel.textContent = data.state === 'succeeded' ? 'Complete' : 'Failed';
          }
          stateNode.textContent = (data.state === 'succeeded' ? 'SUCCESS: ' : 'FAILURE: ') +
            (data.message || data.state);
          return;
        }
        window.setTimeout(poll, 2000);
      })
      .catch(function (error) {
        stateNode.textContent = 'Unable to read verification status: ' + error.message;
        window.setTimeout(poll, 5000);
      });
  }
  poll();
}());
