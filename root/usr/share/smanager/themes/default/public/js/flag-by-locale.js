document.addEventListener('DOMContentLoaded', () => { 
	const flagContainer = document.getElementById('flag-container');
	const languageToCountryMap = {
	  af: { countryCode: "NA", countryName: "Namibia", nativeName: "Afrikaans" },
	  agq: { countryCode: "CM", countryName: "Cameroon", nativeName: "Aghem" },
	  ak: { countryCode: "GH", countryName: "Ghana", nativeName: "Akan" },
	  am: { countryCode: "ET", countryName: "Ethiopia", nativeName: "አማርኛ" },
	  ar: { countryCode: "SA", countryName: "Saudi Arabia", nativeName: "العربية" },
	  as: { countryCode: "IN", countryName: "India", nativeName: "অসমীয়া" },
	  asa: { countryCode: "TZ", countryName: "Tanzania", nativeName: "Asu" },
	  ast: { countryCode: "ES", countryName: "Spain", nativeName: "Asturianu" },
	  az: { countryCode: "AZ", countryName: "Azerbaijan", nativeName: "Azərbaycan dili" },
	  bas: { countryCode: "CM", countryName: "Cameroon", nativeName: "Basa" },
	  be: { countryCode: "BY", countryName: "Belarus", nativeName: "Беларуская" },
	  bem: { countryCode: "ZM", countryName: "Zambia", nativeName: "Bemba" },
	  bez: { countryCode: "TZ", countryName: "Tanzania", nativeName: "Bena" },
	  bg: { countryCode: "BG", countryName: "Bulgaria", nativeName: "български език" },
	  bm: { countryCode: "ML", countryName: "Mali", nativeName: "Bamanankan" },
	  bn: { countryCode: "BD", countryName: "Bangladesh", nativeName: "বাংলা" },
	  bo: { countryCode: "CN", countryName: "China", nativeName: "བོད་སྐད་" },
	  br: { countryCode: "FR", countryName: "France", nativeName: "brezhoneg" },
	  bs: { countryCode: "BA", countryName: "Bosnia and Herzegovina", nativeName: "Bosanski" },
	  ca: { countryCode: "AD", countryName: "Andorra", nativeName: "català" },
	  cs: { countryCode: "CZ", countryName: "Czech Republic", nativeName: "čeština" },
	  cy: { countryCode: "GB", countryName: "United Kingdom", nativeName: "Cymraeg" },
	  da: { countryCode: "DK", countryName: "Denmark", nativeName: "dansk" },
	  de: { countryCode: "DE", countryName: "Germany", nativeName: "Deutsch" },
	  dz: { countryCode: "BT", countryName: "Bhutan", nativeName: "རྫོང་ཁ" },
	  ee: { countryCode: "GH", countryName: "Ghana", nativeName: "Eʋegbe" },
	  el: { countryCode: "CY", countryName: "Cyprus", nativeName: "Ελληνικά" },
	  en: { countryCode: "US", countryName: "United States", nativeName: "English" },
	  es: { countryCode: "ES", countryName: "Spain", nativeName: "Español" },
	  et: { countryCode: "EE", countryName: "Estonia", nativeName: "eesti" },
	  eu: { countryCode: "ES", countryName: "Spain", nativeName: "euskara" },
	  fa: { countryCode: "AF", countryName: "Afghanistan", nativeName: "فارسی" },
	  fi: { countryCode: "FI", countryName: "Finland", nativeName: "suomi" },
	  fr: { countryCode: "FR", countryName: "France", nativeName: "français" },
	  ga: { countryCode: "IE", countryName: "Ireland", nativeName: "Gaeilge" },
	  gl: { countryCode: "ES", countryName: "Spain", nativeName: "galego" },
	  gu: { countryCode: "IN", countryName: "India", nativeName: "ગુજરાતી" },
	  he: { countryCode: "IL", countryName: "Israel", nativeName: "עברית" },
	  hi: { countryCode: "IN", countryName: "India", nativeName: "हिंदी" },
	  hr: { countryCode: "HR", countryName: "Croatia", nativeName: "hrvatski" },
	  hu: { countryCode: "HU", countryName: "Hungary", nativeName: "magyar" },
	  id: { countryCode: "ID", countryName: "Indonesia", nativeName: "bahasa Indonesia" },
	  is: { countryCode: "IS", countryName: "Iceland", nativeName: "íslenska" },
	  it: { countryCode: "IT", countryName: "Italy", nativeName: "italiano" },
	  ja: { countryCode: "JP", countryName: "Japan", nativeName: "日本語" },
	  ka: { countryCode: "GE", countryName: "Georgia", nativeName: "ქართული" },
	  kk: { countryCode: "KZ", countryName: "Kazakhstan", nativeName: "қазақ тілі" },
	  km: { countryCode: "KH", countryName: "Cambodia", nativeName: "ខ្មែរ" },
	  kn: { countryCode: "IN", countryName: "India", nativeName: "ಕನ್ನಡ" },
	  ko: { countryCode: "KP", countryName: "North Korea", nativeName: "한국어" },
	  lt: { countryCode: "LT", countryName: "Lithuania", nativeName: "lietuvių" },
	  lv: { countryCode: "LV", countryName: "Latvia", nativeName: "latviešu" },
	  mk: { countryCode: "MK", countryName: "North Macedonia", nativeName: "македонски" },
	  ml: { countryCode: "IN", countryName: "India", nativeName: "മലയാളം" },
	  mn: { countryCode: "MN", countryName: "Mongolia", nativeName: "Монгол хэл" },
	  mr: { countryCode: "IN", countryName: "India", nativeName: "मराठी" },
	  ms: { countryCode: "BN", countryName: "Brunei", nativeName: "Bahasa Melayu" },
	  mt: { countryCode: "MT", countryName: "Malta", nativeName: "Malti" },
	  ne: { countryCode: "IN", countryName: "India", nativeName: "नेपाली" },
	  nl: { countryCode: "NL", countryName: "Netherlands", nativeName: "Nederlands" },
	  no: { countryCode: "NO", countryName: "Norway", nativeName: "Norsk" },
	  or: { countryCode: "IN", countryName: "India", nativeName: "ଓଡ଼ିଆ" },
	  pa: { countryCode: "PK", countryName: "Pakistan", nativeName: "ਪੰਜਾਬੀ" },
	  pl: { countryCode: "PL", countryName: "Poland", nativeName: "polski" },
	  ps: { countryCode: "AF", countryName: "Afghanistan", nativeName: "پښتو" },
	  pt: { countryCode: "PT", countryName: "Portugal", nativeName: "português" },
	  ro: { countryCode: "RO", countryName: "Romania", nativeName: "română" },
	  ru: { countryCode: "RU", countryName: "Russia", nativeName: "русский" },
	  rw: { countryCode: "RW", countryName: "Rwanda", nativeName: "Kinyarwanda" },
	  se: { countryCode: "SE", countryName: "Sweden", nativeName: "Davvisámegiella" },
	  si: { countryCode: "LK", countryName: "Sri Lanka", nativeName: "සිංහල" },
	  sk: { countryCode: "SK", countryName: "Slovakia", nativeName: "slovenčina" },
	  sl: { countryCode: "SI", countryName: "Slovenia", nativeName: "slovenščina" },
	  so: { countryCode: "SO", countryName: "Somalia", nativeName: "Soomaali" },
	  sq: { countryCode: "AL", countryName: "Albania", nativeName: "shqip" },
	  sr: { countryCode: "RS", countryName: "Serbia", nativeName: "српски" },
	  sv: { countryCode: "SE", countryName: "Sweden", nativeName: "svenska" },
	  sw: { countryCode: "CD", countryName: "Democratic Republic of the Congo", nativeName: "Kiswahili" },
	  ta: { countryCode: "IN", countryName: "India", nativeName: "தமிழ்" },
	  te: { countryCode: "IN", countryName: "India", nativeName: "తెలుగు" },
	  th: { countryCode: "TH", countryName: "Thailand", nativeName: "ไทย" },
	  tl: { countryCode: "PH", countryName: "Philippines", nativeName: "Tagalog" },
	  tr: { countryCode: "TR", countryName: "Turkey", nativeName: "Türkçe" },
	  uk: { countryCode: "UA", countryName: "Ukraine", nativeName: "українська" },
	  ur: { countryCode: "IN", countryName: "India", nativeName: "اردو" },
	  uz: { countryCode: "UZ", countryName: "Uzbekistan", nativeName: "oʻzbek" },
	  vi: { countryCode: "VN", countryName: "Vietnam", nativeName: "Tiếng Việt" },
	  yo: { countryCode: "BJ", countryName: "Benin", nativeName: "Yorùbá" },
	  zh: { countryCode: "CN", countryName: "China", nativeName: "中文" },
	  zu: { countryCode: "ZA", countryName: "South Africa", nativeName: "isiZulu" }
	};

	function canRenderFlagEmoji(flagEmoji) {
	  const canvas = document.createElement("canvas");
	  canvas.width = 16;
	  canvas.height = 16;
	  const ctx = canvas.getContext("2d");

	  ctx.fillStyle = "white";
	  ctx.fillRect(0, 0, canvas.width, canvas.height);
	  ctx.textBaseline = "top";
	  ctx.font = "16px Arial, sans-serif, Apple Color Emoji,Segoe UI Emoji,NotoColorEmoji";
	  ctx.fillStyle = "black";
	  ctx.fillText(flagEmoji, 0, 0);
	  //return false; //testing!!
	  const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
	  for (let i = 0; i < pixels.length; i += 4) {
		const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
		if (r !== g || g !== b) {
		  return true;
		}
	  }
	  return false;
	}

	function extractLocaleParts(locale) {
		const parts = locale.split('-');
		const language = parts[0].toLowerCase();
		const countryCode = (parts.length === 2)
			? parts[1].toUpperCase()
			: (languageToCountryMap[language]
				? languageToCountryMap[language].countryCode
				: null);
		return { language, countryCode };
	}

	function getNativeNameFromLanguage(language) {
		return languageToCountryMap[language]
			? languageToCountryMap[language].nativeName
			: language;
	}

	function getFlagEmoji(countryCode) {
		if (!countryCode) return null;
		return String.fromCodePoint(
			...[...countryCode].map(char => 0x1F1E6 + char.charCodeAt(0) - 'A'.charCodeAt(0))
		);
	}
	
	// Function to simple validate a locale string like "en-CA" or "FR"
	function isValidLocale(loc) {
	  return /^[a-z]{2}(-[A-Za-z]{2})?$/.test(loc);
	}

	function displayLocaleAndFlag(canDecode) {
	//console.log(`locale:${locale}`);
	const userLocale = (locale && isValidLocale(locale))
	  ? locale
	  : (navigator.languages && navigator.languages.length)
		? navigator.languages[0]
		: navigator.language;

		const { language, countryCode } = extractLocaleParts(userLocale);

		//console.log(`Language: ${language}, Country Code: ${countryCode}, Locale: ${userLocale}`);

		const flag = countryCode ? getFlagEmoji(countryCode) : null;

		if (!countryCode || !canDecode) {
			const fallbackDiv = document.createElement('div');
			fallbackDiv.className = 'fallback-box';
			fallbackDiv.textContent = countryCode || userLocale.toUpperCase(); // fallback is country code upper case
			fallbackDiv.title = getNativeNameFromLanguage(language); // tooltip is native language name or language code
			flagContainer.appendChild(fallbackDiv);
		} else {
			const nativeName = getNativeNameFromLanguage(language);
			const flagSpan = document.createElement('span');
			flagSpan.textContent = flag;
			flagSpan.title = nativeName;
			flagContainer.appendChild(flagSpan);
		}
	}

	const result = canRenderFlagEmoji("🇺🇸");
	//console.log(result ? "flag decode yes" : "flag decode no");
	displayLocaleAndFlag(result);
});