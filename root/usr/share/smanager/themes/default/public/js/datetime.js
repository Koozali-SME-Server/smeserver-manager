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