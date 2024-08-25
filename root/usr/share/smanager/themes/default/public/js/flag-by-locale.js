document.addEventListener('DOMContentLoaded', () => {
  const flagContainer = document.getElementById('flag-container');

        async function getCountryName(countryCode) {
            try {
                const response = await fetch(`https://restcountries.com/v3.1/alpha/${countryCode}`);
                if (!response.ok) throw new Error('Country not found');
                const data = await response.json();
                // Return the name in the native language
                return data[0].name.common; 
            } catch (error) {
                console.error(error);
                return 'Unknown Country';
            }
        }

        function getFlagEmoji(locale) {
            // Split the locale to get the language and country code
            const parts = locale.split('-');
            let countryCode;

            // Handle single subtag (language only) or double subtag (language-country)
            if (parts.length === 1) {
                countryCode = getCountryCodeFromLanguage(parts[0]);
            } else if (parts.length === 2) {
                countryCode = parts[1].toLowerCase(); // Use the country code
            }

            // If country code is not found, set a fallback output
            if (!countryCode) {
                const fallback = `? ${locale.toUpperCase()}`; // Just a question mark and the full locale
                return { flag: fallback, isUnknown: true, countryName: 'Unknown Country' };
            }

            // Convert the country code to a flag emoji
            return {
                flag: String.fromCodePoint(...[...countryCode.toUpperCase()].map(char => 0x1F1E6 + char.charCodeAt(0) - 'A'.charCodeAt(0))),
                isUnknown: false,
                countryCode: countryCode
            };
        }

        function getCountryCodeFromLanguage(language) {
            // Map languages to countries (this is an example, extend as needed)
            const languageToCountryMap = {
                  // Add more mappings as needed
    "af": "NA",
    "agq": "CM",
    "ak": "GH",
    "am": "ET",
    "ar": "01",
    "as": "IN",
    "asa": "TZ",
    "ast": "ES",
    "az": "rl",
    "bas": "CM",
    "be": "BY",
    "bem": "ZM",
    "bez": "TZ",
    "bg": "BG",
    "bm": "ML",
    "bn": "BD",
    "bo": "CN",
    "br": "FR",
    "brx": "IN",
    "bs": "rl",
    "ca": "AD",
    "ccp": "BD",
    "ce": "RU",
    "cgg": "UG",
    "chr": "US",
    "ckb": "IQ",
    "cs": "CZ",
    "cy": "GB",
    "da": "DK",
    "dav": "KE",
    "de": "DE",
    "dje": "NE",
    "dsb": "DE",
    "dua": "CM",
    "dyo": "SN",
    "dz": "BT",
    "ebu": "KE",
    "ee": "GH",
    "el": "CY",
    "en": "01",
    "es": "ES",
    "et": "EE",
    "eu": "ES",
    "ewo": "CM",
    "fa": "AF",
    "ff": "CM",
    "fi": "FI",
    "fil": "PH",
    "fo": "FO",
    "fr": "FR",
    "fur": "IT",
    "fy": "NL",
    "ga": "IE",
    "gd": "GB",
    "gl": "ES",
    "gsw": "CH",
    "gu": "IN",
    "guz": "KE",
    "gv": "IM",
    "ha": "GH",
    "haw": "US",
    "he": "IL",
    "hi": "IN",
    "hr": "HR",
    "hsb": "DE",
    "hu": "HU",
    "hy": "AM",
    "id": "ID",
    "ig": "NG",
    "ii": "CN",
    "is": "IS",
    "it": "IT",
    "ja": "JP",
    "jgo": "CM",
    "jmc": "TZ",
    "ka": "GE",
    "kab": "DZ",
    "kam": "KE",
    "kde": "TZ",
    "kea": "CV",
    "khq": "ML",
    "ki": "KE",
    "kk": "KZ",
    "kkj": "CM",
    "kl": "GL",
    "kln": "KE",
    "km": "KH",
    "kn": "IN",
    "ko": "KP",
    "kok": "IN",
    "ks": "IN",
    "ksb": "TZ",
    "ksf": "CM",
    "ksh": "DE",
    "kw": "GB",
    "ky": "KG",
    "lag": "TZ",
    "lb": "LU",
    "lg": "UG",
    "lkt": "US",
    "ln": "AO",
    "lo": "LA",
    "lrc": "IQ",
    "lt": "LT",
    "lu": "CD",
    "luo": "KE",
    "Luo": "KE",
    "luy": "KE",
    "lv": "LV",
    "mas": "KE",
    "mer": "KE",
    "mfe": "MU",
    "mg": "MG",
    "mgh": "MZ",
    "mgo": "CM",
    "mk": "MK",
    "ml": "IN",
    "mn": "MN",
    "mr": "IN",
    "ms": "BN",
    "mt": "MT",
    "mua": "CM",
    "my": "MM",
    "mzn": "IR",
    "naq": "NA",
    "nb": "NO",
    "nd": "ZW",
    "nds": "DE",
    "ne": "IN",
    "nl": "NL",
    "nmg": "CM",
    "nn": "NO",
    "nnh": "CM",
    "nus": "SS",
    "nyn": "UG",
    "om": "ET",
    "or": "IN",
    "os": "GE",
    "pa": "ab",
    "pl": "PL",
    "ps": "AF",
    "pt": "PT",
    "qu": "BO",
    "rm": "CH",
    "rn": "BI",
    "ro": "RO",
    "rof": "TZ",
    "ru": "RU",
    "rw": "RW",
    "rwk": "TZ",
    "sah": "RU",
    "saq": "KE",
    "sbp": "TZ",
    "se": "SE",
    "seh": "MZ",
    "ses": "ML",
    "sg": "CF",
    "shi": "tn",
    "si": "LK",
    "sk": "SK",
    "sl": "SI",
    "smn": "FI",
    "sn": "ZW",
    "so": "SO",
    "sq": "AL",
    "sr": "rl",
    "sv": "AX",
    "sw": "CD",
    "ta": "IN",
    "te": "IN",
    "teo": "KE",
    "tg": "TJ",
    "th": "TH",
    "ti": "ER",
    "to": "TO",
    "tr": "TR",
    "tt": "RU",
    "twq": "NE",
    "tzm": "MA",
    "ug": "CN",
    "uk": "UA",
    "ur": "IN",
    "uz": "ab",
    "vai": "tn",
    "Vai": "tn",
    "vi": "VN",
    "vun": "TZ",
    "wae": "CH",
    "wo": "SN",
    "xog": "UG",
    "yav": "CM",
    "yi": "01",
    "yo": "BJ",
    "yue": "ns",
    "zgh": "MA",
    "zh": "ns",
    "zu": "ZA"


            };

            return languageToCountryMap[language] || null;
        }

        async function displayLocaleAndFlag() {
            // Get the browser locale
            const userLocale = navigator.language || navigator.userLanguage;
            const { flag, isUnknown, countryCode } = getFlagEmoji(userLocale);

            // Display the locale and the corresponding flag (or fallback)
            //document.getElementById('locale').textContent = `Your Locale: ${userLocale}`;

            if (isUnknown) {
                const fallbackDiv = document.createElement('div');
                fallbackDiv.className = 'fallback-box';
                fallbackDiv.textContent = `? ${userLocale.toUpperCase()}`; // Only show ? and locale code inside the box
                //document.getElementById('flag-container').textContent = "Flag: ";
                document.getElementById('flag-container').appendChild(fallbackDiv);
                // Tooltip for fallback
                fallbackDiv.title = "Unknown Country"; // Tooltip for fallback
            } else {
                const countryName = await getCountryName(countryCode);
                const flagSpan = document.createElement('span');
                flagSpan.textContent = flag; // Use flag emoji
                flagSpan.title = countryName; // Tooltip for the flag in country language
                //document.getElementById('flag-container').textContent = "Flag: ";
                document.getElementById('flag-container').appendChild(flagSpan);
            }
        }

        displayLocaleAndFlag();
});
