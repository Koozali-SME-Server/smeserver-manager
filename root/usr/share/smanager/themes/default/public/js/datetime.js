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

document.addEventListener('DOMContentLoaded', function() {
  // Parse the initial server time from the input value
  const clockElement = document.getElementById('real-time-clock');
  if (!clockElement) return;

  // Get the initial server time from the input's value
  let serverTime = new Date(clockElement.value.replace(' ', 'T'));

  function updateDateTime() {
    // Format the date/time string as desired
    const daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    const dayOfWeek = daysOfWeek[serverTime.getDay()];
    const month = months[serverTime.getMonth()];
    const day = serverTime.getDate();
    const year = serverTime.getFullYear();

    let hours = serverTime.getHours();
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12 || 12;

    const minutes = serverTime.getMinutes().toString().padStart(2, '0');
    const seconds = serverTime.getSeconds().toString().padStart(2, '0');

    const dateTimeString = `${dayOfWeek}, ${month} ${day}, ${year} ${hours}:${minutes}:${seconds} ${ampm}`;
    clockElement.value = dateTimeString;

    // Advance serverTime by one second
    serverTime.setSeconds(serverTime.getSeconds() + 1);
  }

  updateDateTime();
  setInterval(updateDateTime, 1000);
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