/// UI copy that only exists in the app (the website has no equivalent). Kept
/// apart from the generated dictionary.g.dart so regenerating that never
/// wipes these out. Same shape, looked up by the same Translator.
const Map<String, Map<String, String>> appStrings = {
  'app.backendStatus': {'en': 'Backend connection', 'bg': 'Връзка с бекенда', 'el': 'Σύνδεση με τον server', 'es': 'Conexión con el servidor'},
  'app.backendChecking': {'en': 'Checking…', 'bg': 'Проверява се…', 'el': 'Έλεγχος…', 'es': 'Comprobando…'},
  'app.backendOk': {
    'en': '{movies} trending movies · {series} trending series',
    'bg': '{movies} филма в тренда · {series} сериала в тренда',
    'el': '{movies} ταινίες της στιγμής · {series} σειρές της στιγμής',
    'es': '{movies} películas en tendencia · {series} series en tendencia',
  },
  'app.backendDown': {
    'en': 'The server did not answer (it may be waking up) — try again.',
    'bg': 'Сървърът не отговори (може би се събужда) — опитай пак.',
    'el': 'Ο server δεν απάντησε (ίσως ξυπνάει) — δοκίμασε ξανά.',
    'es': 'El servidor no respondió (puede que esté arrancando) — inténtalo de nuevo.',
  },
  'app.retry': {'en': 'Try again', 'bg': 'Опитай пак', 'el': 'Δοκίμασε ξανά', 'es': 'Reintentar'},
  'app.updateTitle': {'en': 'New version available', 'bg': 'Има нова версия', 'el': 'Υπάρχει νέα έκδοση', 'es': 'Nueva versión disponible'},
  'app.updateDesc': {
    'en': 'AuroraFlix {version} is ready to install.',
    'bg': 'AuroraFlix {version} е готова за инсталиране.',
    'el': 'Το AuroraFlix {version} είναι έτοιμο για εγκατάσταση.',
    'es': 'AuroraFlix {version} está lista para instalar.',
  },
  'app.updateNow': {'en': 'Update', 'bg': 'Обнови', 'el': 'Ενημέρωση', 'es': 'Actualizar'},
  'app.updateLater': {'en': 'Later', 'bg': 'По-късно', 'el': 'Αργότερα', 'es': 'Más tarde'},
  'app.updateDownloading': {
    'en': 'Downloading… {percent}%',
    'bg': 'Изтегляне… {percent}%',
    'el': 'Λήψη… {percent}%',
    'es': 'Descargando… {percent}%',
  },
  'app.updateFailed': {
    'en': 'The download failed. Try again, or download it in the browser.',
    'bg': 'Изтеглянето не успя. Опитай пак или го изтегли през браузъра.',
    'el': 'Η λήψη απέτυχε. Δοκίμασε ξανά ή κατέβασέ το από τον browser.',
    'es': 'La descarga falló. Inténtalo de nuevo o descárgala desde el navegador.',
  },
  'app.updateInBrowser': {'en': 'In browser', 'bg': 'В браузъра', 'el': 'Στον browser', 'es': 'En el navegador'},
  'app.searchHint': {
    'en': 'Type to see matching titles',
    'bg': 'Пиши, за да видиш съвпадащи заглавия',
    'el': 'Γράψε για να δεις τίτλους που ταιριάζουν',
    'es': 'Escribe para ver títulos que coincidan',
  },
};
