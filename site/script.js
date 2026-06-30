const LANGUAGE_STORAGE_KEY = "kkachi-site-language";
const SUPPORTED_LANGUAGES = new Set(["en", "ko"]);

const languageOptions = Array.from(document.querySelectorAll("[data-language-option]"));
const localizedCopy = Array.from(document.querySelectorAll("[data-i18n-lang]"));
const localizedAria = Array.from(document.querySelectorAll("[data-aria-en][data-aria-ko]"));
const localizedMetadata = Array.from(document.querySelectorAll("[data-meta-en][data-meta-ko]"));

function localizedValue(element, language, prefix) {
  const suffix = language === "ko" ? "Ko" : "En";
  return element.dataset[`${prefix}${suffix}`];
}

function savedLanguage() {
  try {
    const language = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
    return SUPPORTED_LANGUAGES.has(language) ? language : null;
  } catch {
    return null;
  }
}

function preferredLanguage() {
  const saved = savedLanguage();

  if (saved) {
    return saved;
  }

  return window.navigator.language?.toLowerCase().startsWith("ko") ? "ko" : "en";
}

function persistLanguage(language) {
  try {
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
  } catch {
    // Private browsing or locked-down storage should not block the language toggle.
  }
}

function updateMetadata(language) {
  localizedMetadata.forEach((element) => {
    const value = localizedValue(element, language, "meta");

    if (!value) {
      return;
    }

    if (element.tagName === "TITLE") {
      document.title = value;
      element.textContent = value;
      return;
    }

    element.setAttribute("content", value);
  });
}

function setLanguage(language, { persist = false } = {}) {
  const nextLanguage = SUPPORTED_LANGUAGES.has(language) ? language : "en";

  document.documentElement.lang = nextLanguage;
  document.documentElement.dataset.lang = nextLanguage;

  localizedCopy.forEach((element) => {
    element.hidden = element.dataset.i18nLang !== nextLanguage;
  });

  localizedAria.forEach((element) => {
    const value = localizedValue(element, nextLanguage, "aria");

    if (value) {
      element.setAttribute("aria-label", value);
    }
  });

  languageOptions.forEach((option) => {
    option.setAttribute("aria-pressed", String(option.dataset.languageOption === nextLanguage));
  });

  updateMetadata(nextLanguage);

  if (persist) {
    persistLanguage(nextLanguage);
  }
}

languageOptions.forEach((option) => {
  option.addEventListener("click", () => {
    setLanguage(option.dataset.languageOption, { persist: true });
  });
});

setLanguage(preferredLanguage());

// Tracks decorative tab chips so the hero can imply pruning without modeling real browser data.
const tabs = Array.from(document.querySelectorAll(".tab"));
// Keeps the restore rail animation synchronized with the decorative tab cycle.
const rail = document.querySelector(".restore-rail");

// Alternates a few chips into a tucked state; reduced-motion users skip this entirely below.
function cycleScene() {
  tabs.forEach((tab, index) => {
    // Offsets each chip so the motion reads as a rotating queue instead of one synchronized flash.
    const tucked = (Date.now() / 1800 + index) % tabs.length < 2;
    tab.classList.toggle("is-tucked", tucked);
  });
  rail?.classList.toggle("is-active");
}

if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  cycleScene();
  window.setInterval(cycleScene, 2600);
}
