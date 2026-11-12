(function () {
  "use strict";
  function initialise() {
    var container = document.getElementById('status-container');
    if (!container) return;

    var statusUrl = container.getAttribute('data-status-url') || '';
    var jobId = container.getAttribute('data-job-id') || '';
    var stage = document.getElementById('stage');
    var inner = document.getElementById('progress-bar-inner');
    var progressLabel = document.getElementById('restore-progress-label');
    var bar = document.getElementById('progress-bar');
    var message = document.getElementById('message-log');
    var completion = document.getElementById('completion-status');
    var reboot = document.getElementById('restore-reboot-button');
    var output = document.getElementById('restore-output');
    var currentFile = document.getElementById('restore-current-file');
    var rebootNotice = document.getElementById('reboot-required-notice');
    var restoreOutputOffset = 0;
    var outputStarted = false;
    var pendingLine = '';
    var displayedLines = [];
    var summaryLines = [];
    var summaryPanel = document.getElementById('restore-summary-panel');
    var summaryNode = document.getElementById('restore-summary');
    var summaryState = document.getElementById('restore-summary-state');
    var rawLimit = container.getAttribute('data-output-limit') || 'all';
    var requestedLimit = parseInt(rawLimit, 10);
    var maxDisplayedLines = rawLimit === 'all' ? 0 :
      ((Number.isInteger(requestedLimit) && [2000, 10000, 100000].indexOf(requestedLimit) !== -1)
        ? requestedLimit : 2000);
    var finished = false;
    var startedAt = Date.now();

    function setButton(label, enabled) {
      if (!reboot) return;
      reboot.disabled = !enabled;
      if ('value' in reboot) reboot.value = label;
      reboot.textContent = label;
      reboot.setAttribute('aria-label', label);
    }
    function keepWaiting() { setButton('Please wait…', false); }
    function renderNewestFirst() {
      if (!output) return;
      output.textContent = displayedLines.join('\n');
      output.scrollTop = 0;
    }
    function addOutputChunk(chunk, flushPartial) {
      if (typeof chunk !== 'string' || !chunk.length) return;
      if (!outputStarted) {
        output.textContent = '';
        outputStarted = true;
      }
      summaryLines = summaryLines.concat(chunk.split(/\r?\n/)).slice(-20000);
      var combined = pendingLine + chunk;
      var lines = combined.split(/\r?\n/);
      pendingLine = lines.pop();
      if (flushPartial && pendingLine) {
        lines.push(pendingLine);
        pendingLine = '';
      }
      // The newest complete DAR lines are placed first. Reverse within each
      // received chunk so the displayed order is newest-to-oldest.
      var fresh = lines.filter(function (line) { return line.length > 0; }).reverse();
      if (fresh.length) {
        displayedLines = fresh.concat(displayedLines);
        if (maxDisplayedLines > 0) displayedLines = displayedLines.slice(0, maxDisplayedLines);
        renderNewestFirst();
        if (currentFile) currentFile.textContent = fresh[0];
      }
    }

    function renderRestoreSummary(state) {
      if (!summaryNode) return;
      var text = summaryLines.join('\n');
      var specs = [
        ['Inodes restored', /([0-9,]+) inode\(s\) restored/i],
        ['Hard links included', /including ([0-9,]+) hard link\(s\)/i],
        ['Not saved in archive', /([0-9,]+) inode\(s\) not restored \(not saved in archive\)/i],
        ['Skipped by overwrite policy', /([0-9,]+) inode\(s\) not restored \(overwriting policy decision\)/i],
        ['Excluded by filters', /([0-9,]+) inode\(s\) ignored \(excluded by filters\)/i],
        ['Filesystem errors', /([0-9,]+) inode\(s\) failed to restore \(filesystem error\)/i],
        ['Deleted', /([0-9,]+) inode\(s\) deleted/i],
        ['Total inodes considered', /Total number of inode\(s\) considered:\s*([0-9,]+)/i],
        ['EA restored', /EA restored for ([0-9,]+) inode\(s\)/i],
        ['FSA restored', /FSA restored for ([0-9,]+) inode\(s\)/i]
      ];
      var elapsed = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
      var rows = [
        ['Restore result', state === 'complete' ? 'Completed successfully' : 'Failed'],
        ['Elapsed time', elapsed + ' seconds'],
        ['Activity lines retained', String(summaryLines.length)]
      ];
      specs.forEach(function (spec) { var m=text.match(spec[1]); if (m) rows.push([spec[0], m[1]]); });
      if (rows.length === 3) rows.push(['DAR statistics', 'No recognised summary lines were reported by DAR']);
      summaryNode.textContent = '';
      var table = document.createElement('table');
      table.className = 'job-summary-grid';
      for (var i = 0; i < rows.length; i += 2) {
        var tr = document.createElement('tr');
        [rows[i], rows[i + 1] || null].forEach(function (row) {
          if (!row) {
            var emptyTh = document.createElement('th');
            var emptyTd = document.createElement('td');
            emptyTh.className = 'job-summary-empty';
            emptyTd.className = 'job-summary-empty';
            tr.appendChild(emptyTh);
            tr.appendChild(emptyTd);
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
      if (summaryState) summaryState.textContent = state === 'complete' ? ' — Complete' : ' — Failed';
      // Keep collapsed by default to preserve room for restore activity. The operator may expand it.
    }

    keepWaiting();
    if (!jobId || !statusUrl) {
      if (stage) stage.textContent = 'Restore not started';
      if (progressLabel) progressLabel.textContent = 'Not running';
      if (bar) bar.classList.add('job-progress-failed');
      if (message) message.textContent = 'No restore job was started. Reboot is disabled.';
      if (completion) completion.textContent = 'Reboot remains disabled.';
      if (rebootNotice) rebootNotice.textContent = 'No restore job was started. Do not reboot from this page.';
      return;
    }

    function poll() {
      if (finished) return;
      var requestUrl = statusUrl + (statusUrl.indexOf('?') === -1 ? '?' : '&') +
        'offset=' + encodeURIComponent(String(restoreOutputOffset));
      fetch(requestUrl, {credentials: 'same-origin', cache: 'no-store'})
        .then(function (response) {
          if (!response.ok) throw new Error('Status request failed (HTTP ' + response.status + ')');
          return response.json();
        })
        .then(function (data) {
          if (data.job_id !== jobId) throw new Error('Restore job ID did not match');
          var state = data.state || 'unknown';
          addOutputChunk(data.output, state === 'complete' || state === 'failed' ? !data.more_output : false);
          if (typeof data.next_offset === 'number' && data.next_offset >= restoreOutputOffset) {
            restoreOutputOffset = data.next_offset;
          }
          if (message) message.textContent = data.message || 'Waiting for restore status.';

          if ((state === 'complete' || state === 'failed') && data.more_output) {
            keepWaiting();
            if (stage) stage.textContent = state === 'complete'
              ? 'Completed — retrieving final output' : 'Failed — retrieving final output';
            if (completion) completion.textContent = 'Retrieving remaining restore output. Reboot remains disabled.';
            window.setTimeout(poll, 100);
            return;
          }
          if (state === 'queued' || state === 'running') {
            keepWaiting();
            if (stage) stage.textContent = state === 'queued' ? 'Queued' : 'Running';
            if (progressLabel) progressLabel.textContent = state === 'queued'
              ? 'Queued…' : 'Restore running…';
            if (bar) {
              bar.classList.remove('job-progress-complete', 'job-progress-failed');
              bar.classList.add('job-progress-indeterminate');
              if (inner) { inner.style.width = ''; inner.style.animation = ''; }
              bar.removeAttribute('aria-valuenow');
              bar.setAttribute('aria-valuetext', state === 'queued' ? 'Restore queued' : 'Restore running');
            }
            if (completion) completion.textContent = 'Elapsed time: ' +
              Math.floor((Date.now() - startedAt) / 1000) + ' seconds. Do not reboot.';
            if (rebootNotice) rebootNotice.textContent = 'Restore is still running. DO NOT REBOOT.';
            window.setTimeout(poll, 2000);
            return;
          }
          if (state === 'complete') {
            if (pendingLine) addOutputChunk('\n', true);
            finished = true;
            renderRestoreSummary('complete');
            if (stage) stage.textContent = 'Completed successfully';
            if (progressLabel) progressLabel.textContent = 'Restore complete';
            if (bar) {
              bar.classList.remove('job-progress-indeterminate', 'job-progress-failed');
              bar.classList.add('job-progress-complete');
              bar.setAttribute('aria-valuenow', '100');
            }
            if (inner) { inner.style.width = '100%'; inner.style.animation = 'none'; }
            if (completion) completion.textContent = 'RESTORE COMPLETED SUCCESSFULLY. A REBOOT IS REQUIRED to complete the restore. Click Reboot now.';
            if (rebootNotice) rebootNotice.textContent = 'REBOOT REQUIRED: the restore is complete. Click Reboot to restart the server.';
            setButton('Reboot', true);
            return;
          }
          if (state === 'failed') {
            if (pendingLine) addOutputChunk('\n', true);
            finished = true;
            renderRestoreSummary('failed');
            keepWaiting();
            if (stage) stage.textContent = 'Failed';
            if (progressLabel) progressLabel.textContent = 'Restore failed';
            if (bar) {
              bar.classList.remove('job-progress-indeterminate', 'job-progress-complete');
              bar.classList.add('job-progress-failed');
              bar.setAttribute('aria-valuetext', 'Restore failed');
            }
            if (inner) { inner.style.width = '100%'; inner.style.animation = 'none'; }
            if (completion) completion.textContent = 'Restore failed. Reboot remains disabled. Check the message above and the Server Manager log.';
            if (rebootNotice) rebootNotice.textContent = 'Restore failed. DO NOT REBOOT using this workflow.';
            return;
          }
          keepWaiting();
          if (stage) stage.textContent = 'Status unknown';
          if (completion) completion.textContent = 'Restore status is unknown; reboot remains disabled.';
          if (rebootNotice) rebootNotice.textContent = 'Restore status cannot be confirmed. DO NOT REBOOT.';
          window.setTimeout(poll, 3000);
        })
        .catch(function (error) {
          keepWaiting();
          if (stage) stage.textContent = 'Checking restore status';
          if (completion) completion.textContent = 'Unable to confirm success (' + error.message + '). Reboot remains disabled while status is unavailable.';
          if (rebootNotice) rebootNotice.textContent = 'Unable to confirm restore completion. DO NOT REBOOT.';
          window.setTimeout(poll, 5000);
        });
    }
    poll();
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialise, {once: true});
  } else {
    initialise();
  }
}());
