document.addEventListener('DOMContentLoaded', () => {
  const flagContainer = document.getElementById('flag-container');

  // Function to get the browser's locale
  function getBrowserLocale() {
    return navigator.language || navigator.userLanguage;
  }

  // Function to map locale to country code
  function getCountryCodeFromLocale(locale) {
    const localeParts = locale.split('-');
    return localeParts.length > 1 ? localeParts[1] : localeParts[0];
  }

  // Function to create and display the flag icon
  function displayFlagIcon(countryCode) {
    const flagIcon = document.createElement('span');
    flagIcon.className = `flag-icon flag-icon-${countryCode.toLowerCase()}`;
    flagIcon.id = 'flag-icon';
    flagContainer.appendChild(flagIcon);
  }

  // Main logic
  const locale = getBrowserLocale();
  const countryCode = getCountryCodeFromLocale(locale);
  displayFlagIcon(countryCode);
});
