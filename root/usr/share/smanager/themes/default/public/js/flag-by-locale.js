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

  // Function to fetch country names from a CDN
  async function fetchCountryNames() {
    const response = await fetch('https://restcountries.com/v3.1/all');
    const countries = await response.json();
    const countryNames = {};
    for (const country of countries) {
      const code = country.cca2.toLowerCase(); // Country code (ISO 3166-1 alpha-2)
      const name = country.name.common; // Common name of the country
      countryNames[code] = name;
    }
    return countryNames;
  }

  // Function to create and display the flag icon
  function displayFlagIcon(countryCode, countryName) {
    const flagIcon = document.createElement('span');
    flagIcon.className = `flag-icon flag-icon-${countryCode.toLowerCase()}`;
    flagIcon.id = 'flag-icon';
    flagIcon.title = countryName; // Set the title for the tooltip

    // If you want a custom tooltip instead (uncomment the lines below):
    /*
    const tooltip = document.createElement('span');
    tooltip.className = 'tooltip';
    tooltip.innerText = countryName;
    flagIcon.appendChild(tooltip);

    flagIcon.addEventListener('mouseenter', () => {
      tooltip.style.display = 'block';
    });

    flagIcon.addEventListener('mouseleave', () => {
      tooltip.style.display = 'none';
    });
    */

    flagContainer.appendChild(flagIcon);
  }

  // Main logic
  (async () => {
    const locale = getBrowserLocale();
    const countryCode = getCountryCodeFromLocale(locale);
    const countryNames = await fetchCountryNames(); // Fetch country names

    const countryName = countryNames[countryCode.toLowerCase()] || 'Unknown Country'; // Get the country name
    displayFlagIcon(countryCode, countryName); // Display the flag with country name
  })();
});
