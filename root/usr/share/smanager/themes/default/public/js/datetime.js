document.addEventListener('DOMContentLoaded', function() {
  var select = document.getElementById('time_mode_select');
  var ntpSection = document.getElementById('ntp_section');
  var manualSection = document.getElementById('manual_section');

  function toggleSections() {
    if (select.value === 'dat_manually_set') {
      ntpSection.style.display = 'none';
      manualSection.style.display = 'block';
    } else {
      ntpSection.style.display = 'block';
      manualSection.style.display = 'none';
    }
  }

  select.addEventListener('change', toggleSections);
  toggleSections(); // Set initial state
});

document.addEventListener('DOMContentLoaded', () => {
  const clock = document.getElementById('real-time-clock');
  if (!clock) return;

  const locale = document.getElementById('user-locale')?.value || 'en';

  let serverTime = new Date(clock.dataset.serverIso);
  if (isNaN(serverTime.getTime())) serverTime = new Date();

  function tick() {
    clock.value = serverTime.toLocaleString(locale, {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    });

    serverTime = new Date(serverTime.getTime() + 1000);
  }

  tick();
  setInterval(tick, 1000);
});

document.addEventListener('DOMContentLoaded', function() {
  const btn = document.getElementById('test-ntp-btn');
  const input = document.getElementById('ntpserver');
  const result = document.getElementById('ntp-test-result');

  btn.addEventListener('click', function() {
    const server = input.value.trim();
    result.className = 'ntp-test-result'; // reset

    if (!server) {
      result.textContent = "Please enter a server address.";
      result.classList.add('ntp-test-error');
      return;
    }
    result.textContent = "Testing...";
    result.classList.add('ntp-test-wait');

    fetch('/smanager/datetimet', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({ ntpserver: server })
    })
    .then(response => {
      if (!response.ok) {
        // HTTP error, e.g., 404, 500
        throw new Error(`HTTP error: ${response.status} ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      result.className = 'ntp-test-result'; // reset
      if (data.success) {
        result.textContent = `Server time: ${data.time}`;
        result.classList.add('ntp-test-success');
      } else {
        result.textContent = `Error: ${data.error}`;
        result.classList.add('ntp-test-error');
      }
    })
    .catch(error => {
      // Network error or thrown HTTP error
      result.className = 'ntp-test-result ntp-test-error';
      result.textContent = `Request failed: ${error.message}`;
    });
  });
});