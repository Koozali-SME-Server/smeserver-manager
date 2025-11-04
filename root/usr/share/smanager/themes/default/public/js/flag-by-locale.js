document.addEventListener('DOMContentLoaded', () => {
	const flagContainer = document.getElementById('flag-container');
	// Mapping of language codes to country codes and their names
	const languageToCountryMap = {
		"af": { code: "NA", name: "Namibia" },
		"agq": { code: "CM", name: "Cameroon" },
		"ak": { code: "GH", name: "Ghana" },
		"am": { code: "ET", name: "Ethiopia" },
		"ar": { code: "SA", name: "Saudi Arabia" },
		"as": { code: "IN", name: "India" },
		"asa": { code: "TZ", name: "Tanzania" },
		"ast": { code: "ES", name: "Spain" },
		"az": { code: "AZ", name: "Azerbaijan" },
		"bas": { code: "CM", name: "Cameroon" },
		"be": { code: "BY", name: "Belarus" },
		"bem": { code: "ZM", name: "Zambia" },
		"bez": { code: "TZ", name: "Tanzania" },
		"bg": { code: "BG", name: "Bulgaria" },
		"bm": { code: "ML", name: "Mali" },
		"bn": { code: "BD", name: "Bangladesh" },
		"bo": { code: "CN", name: "China" },
		"br": { code: "FR", name: "France" },
		"brx": { code: "IN", name: "India" },
		"bs": { code: "BA", name: "Bosnia and Herzegovina" },
		"ca": { code: "AD", name: "Andorra" },
		"ccp": { code: "BD", name: "Bangladesh" },
		"ce": { code: "RU", name: "Russia" },
		"cgg": { code: "UG", name: "Uganda" },
		"chr": { code: "US", name: "United States" },
		"ckb": { code: "IQ", name: "Iraq" },
		"cs": { code: "CZ", name: "Czech Republic" },
		"cy": { code: "GB", name: "United Kingdom" },
		"da": { code: "DK", name: "Denmark" },
		"dav": { code: "KE", name: "Kenya" },
		"de": { code: "DE", name: "Germany" },
		"dje": { code: "NE", name: "Niger" },
		"dsb": { code: "DE", name: "Germany" },
		"dua": { code: "CM", name: "Cameroon" },
		"dyo": { code: "SN", name: "Senegal" },
		"dz": { code: "BT", name: "Bhutan" },
		"ebu": { code: "KE", name: "Kenya" },
		"ee": { code: "GH", name: "Ghana" },
		"el": { code: "CY", name: "Cyprus" },
		"en": { code: "US", name: "United States" }, // Assume US for English if unspecified
		"es": { code: "ES", name: "Spain" },
		"et": { code: "EE", name: "Estonia" },
		"eu": { code: "ES", name: "Spain" },
		"ewo": { code: "CM", name: "Cameroon" },
		"fa": { code: "AF", name: "Afghanistan" },
		"ff": { code: "CM", name: "Cameroon" },
		"fi": { code: "FI", name: "Finland" },
		"fil": { code: "PH", name: "Philippines" },
		"fo": { code: "FO", name: "Faroe Islands" },
		"fr": { code: "FR", name: "France" },
		"fur": { code: "IT", name: "Italy" },
		"fy": { code: "NL", name: "Netherlands" },
		"ga": { code: "IE", name: "Ireland" },
		"gd": { code: "GB", name: "United Kingdom" },
		"gl": { code: "ES", name: "Spain" },
		"gsw": { code: "CH", name: "Switzerland" },
		"gu": { code: "IN", name: "India" },
		"guz": { code: "KE", name: "Kenya" },
		"gv": { code: "IM", name: "Isle of Man" },
		"ha": { code: "GH", name: "Ghana" },
		"haw": { code: "US", name: "United States" },
		"he": { code: "IL", name: "Israel" },
		"hi": { code: "IN", name: "India" },
		"hr": { code: "HR", name: "Croatia" },
		"hsb": { code: "DE", name: "Germany" },
		"hu": { code: "HU", name: "Hungary" },
		"hy": { code: "AM", name: "Armenia" },
		"id": { code: "ID", name: "Indonesia" },
		"ig": { code: "NG", name: "Nigeria" },
		"ii": { code: "CN", name: "China" },
		"is": { code: "IS", name: "Iceland" },
		"it": { code: "IT", name: "Italy" },
		"ja": { code: "JP", name: "Japan" },
		"jgo": { code: "CM", name: "Cameroon" },
		"jmc": { code: "TZ", name: "Tanzania" },
		"ka": { code: "GE", name: "Georgia" },
		"kab": { code: "DZ", name: "Algeria" },
		"kam": { code: "KE", name: "Kenya" },
		"kde": { code: "TZ", name: "Tanzania" },
		"kea": { code: "CV", name: "Cabo Verde" },
		"khq": { code: "ML", name: "Mali" },
		"ki": { code: "KE", name: "Kenya" },
		"kk": { code: "KZ", name: "Kazakhstan" },
		"kkj": { code: "CM", name: "Cameroon" },
		"kl": { code: "GL", name: "Greenland" },
		"kln": { code: "KE", name: "Kenya" },
		"km": { code: "KH", name: "Cambodia" },
		"kn": { code: "IN", name: "India" },
		"ko": { code: "KP", name: "North Korea" },
		"kok": { code: "IN", name: "India" },
		"ks": { code: "IN", name: "India" },
		"ksb": { code: "TZ", name: "Tanzania" },
		"ksf": { code: "CM", name: "Cameroon" },
		"ksh": { code: "DE", name: "Germany" },
		"kw": { code: "GB", name: "United Kingdom" },
		"ky": { code: "KG", name: "Kyrgyzstan" },
		"lag": { code: "TZ", name: "Tanzania" },
		"lb": { code: "LU", name: "Luxembourg" },
		"lg": { code: "UG", name: "Uganda" },
		"lkt": { code: "US", name: "United States" },
		"ln": { code: "AO", name: "Angola" },
		"lo": { code: "LA", name: "Laos" },
		"lrc": { code: "IQ", name: "Iraq" },
		"lt": { code: "LT", name: "Lithuania" },
		"lu": { code: "CD", name: "Democratic Republic of the Congo" },
		"luo": { code: "KE", name: "Kenya" },
		"Luo": { code: "KE", name: "Kenya" },
		"luy": { code: "KE", name: "Kenya" },
		"lv": { code: "LV", name: "Latvia" },
		"mas": { code: "KE", name: "Kenya" },
		"mer": { code: "KE", name: "Kenya" },
		"mfe": { code: "MU", name: "Mauritius" },
		"mg": { code: "MG", name: "Madagascar" },
		"mgh": { code: "MZ", name: "Mozambique" },
		"mgo": { code: "CM", name: "Cameroon" },
		"mk": { code: "MK", name: "North Macedonia" },
		"ml": { code: "IN", name: "India" },
		"mn": { code: "MN", name: "Mongolia" },
		"mr": { code: "IN", name: "India" },
		"ms": { code: "BN", name: "Brunei" },
		"mt": { code: "MT", name: "Malta" },
		"mua": { code: "CM", name: "Cameroon" },
		"my": { code: "MM", name: "Myanmar" },
		"mzn": { code: "IR", name: "Iran" },
		"naq": { code: "NA", name: "Namibia" },
		"nb": { code: "NO", name: "Norway" },
		"nd": { code: "ZW", name: "Zimbabwe" },
		"nds": { code: "DE", name: "Germany" },
		"ne": { code: "IN", name: "India" },
		"nl": { code: "NL", name: "Netherlands" },
		"nmg": { code: "CM", name: "Cameroon" },
		"nn": { code: "NO", name: "Norway" },
		"nnh": { code: "CM", name: "Cameroon" },
		"nus": { code: "SS", name: "South Sudan" },
		"nyn": { code: "UG", name: "Uganda" },
		"om": { code: "ET", name: "Ethiopia" },
		"or": { code: "IN", name: "India" },
		"os": { code: "GE", name: "Georgia" },
		"pa": { code: "PK", name: "Pakistan" },
		"pl": { code: "PL", name: "Poland" },
		"ps": { code: "AF", name: "Afghanistan" },
		"pt": { code: "PT", name: "Portugal" },
		"qu": { code: "BO", name: "Bolivia" },
		"rm": { code: "CH", name: "Switzerland" },
		"rn": { code: "BI", name: "Burundi" },
		"ro": { code: "RO", name: "Romania" },
		"rof": { code: "TZ", name: "Tanzania" },
		"ru": { code: "RU", name: "Russia" },
		"rw": { code: "RW", name: "Rwanda" },
		"rwk": { code: "TZ", name: "Tanzania" },
		"sah": { code: "RU", name: "Russia" },
		"saq": { code: "KE", name: "Kenya" },
		"sbp": { code: "TZ", name: "Tanzania" },
		"se": { code: "SE", name: "Sweden" },
		"seh": { code: "MZ", name: "Mozambique" },
		"ses": { code: "ML", name: "Mali" },
		"sg": { code: "CF", name: "Central African Republic" },
		"shi": { code: "TN", name: "Tunisia" },
		"si": { code: "LK", name: "Sri Lanka" },
		"sk": { code: "SK", name: "Slovakia" },
		"sl": { code: "SI", name: "Slovenia" },
		"smn": { code: "FI", name: "Finland" },
		"sn": { code: "ZW", name: "Zimbabwe" },
		"so": { code: "SO", name: "Somalia" },
		"sq": { code: "AL", name: "Albania" },
		"sr": { code: "RS", name: "Serbia" },
		"sv": { code: "SE", name: "Sweden" },
		"sw": { code: "CD", name: "Democratic Republic of the Congo" },
		"ta": { code: "IN", name: "India" },
		"te": { code: "IN", name: "India" },
		"teo": { code: "KE", name: "Kenya" },
		"tg": { code: "TJ", name: "Tajikistan" },
		"th": { code: "TH", name: "Thailand" },
		"ti": { code: "ER", name: "Eritrea" },
		"to": { code: "TO", name: "Tonga" },
		"tr": { code: "TR", name: "Turkey" },
		"tt": { code: "RU", name: "Russia" },
		"twq": { code: "NE", name: "Niger" },
		"tzm": { code: "MA", name: "Morocco" },
		"ug": { code: "CN", name: "China" },
		"uk": { code: "UA", name: "Ukraine" },
		"ur": { code: "IN", name: "India" },
		"uz": { code: "UZ", name: "Uzbekistan" },
		"vai": { code: "TN", name: "Tunisia" },
		"Vai": { code: "TN", name: "Tunisia" },
		"vi": { code: "VN", name: "Vietnam" },
		"vun": { code: "TZ", name: "Tanzania" },
		"wae": { code: "CH", name: "Switzerland" },
		"wo": { code: "SN", name: "Senegal" },
		"xog": { code: "UG", name: "Uganda" },
		"yav": { code: "CM", name: "Cameroon" },
		"yi": { code: "01", name: "Unknown" }, // Placeholder for unspecified region
		"yo": { code: "BJ", name: "Benin" },
		"yue": { code: "CN", name: "China" },
		"zgh": { code: "MA", name: "Morocco" },
		"zh": { code: "CN", name: "China" },
		"zu": { code: "ZA", name: "South Africa" },
	};


		//async function getCountryName(countryCode) {
			//try {
				//const response = await fetch(`https://restcountries.com/v3.1/alpha/${countryCode}`);
				//if (!response.ok) throw new Error('Country not found');
				//const data = await response.json();
				//// Return the name in the native language
				//return data[0].name.common; 
			//} catch (error) {
				//console.error(error);
				//return 'Unknown Country';
			//}
		//}

		function getCountryNameFromLanguage(language) {
			return languageToCountryMap[language] ? languageToCountryMap[language].name : null;
		}

		function getCountryCodeFromLanguage(language) {
			return languageToCountryMap[language] ? languageToCountryMap[language].code : null;
		}
		
		function getCountryNameFromCountryCode(countryCode) {
			//alert(`Country code: ${countryCode}`);
			for (const language in languageToCountryMap) {
				if (languageToCountryMap.hasOwnProperty(language)) {
					if (languageToCountryMap[language].code === countryCode) {
						return languageToCountryMap[language].name;
					}
				}
			}
			return null; // Return null if country code not found
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

function displayLocaleAndFlag() {
    // Get the browser locale
    const userLocale = navigator.languages && navigator.languages.length
    ? navigator.languages[0]
    : navigator.language;
        
    //alert(`User Locale: ${userLocale}`); // Alert the detected locale
	console.log(navigator.languages); // Log language to console

    const { flag, isUnknown, countryCode } = getFlagEmoji(userLocale);
    
    //alert(`Country Code: ${countryCode}, Is Unknown: ${isUnknown}`); // Debug country code and unknown flag status

    // Display the locale and the corresponding flag (or fallback)
    //document.getElementById('locale').textContent = `Your Locale: ${userLocale}`;

    if (isUnknown) {
        const fallbackDiv = document.createElement('div');
        fallbackDiv.className = 'fallback-box';
        fallbackDiv.textContent = `? ${userLocale.toUpperCase()}`; // Show ? and locale code inside the box
        document.getElementById('flag-container').appendChild(fallbackDiv);
        
        // Tooltip for fallback
        fallbackDiv.title = "Unknown Country"; // Tooltip for fallback
        //alert('Fallback triggered: Unknown Country'); // Debug fallback
    } else {
        const countryName = getCountryNameFromCountryCode(countryCode.toUpperCase());
        //alert(`Country Name from Country Code: ${countryName}`); // Alert the country name

        const flagSpan = document.createElement('span');
        flagSpan.textContent = flag; // Use flag emoji
        flagSpan.title = countryName; // Tooltip for the flag in country language
        document.getElementById('flag-container').appendChild(flagSpan);
        
        //alert(`Flag Emoji: ${flag}`); // Debug flag emoji display
    }
}
		displayLocaleAndFlag();
	});