/// UI copy that only exists in the app (the website has no equivalent). Kept
/// apart from the generated dictionary.g.dart so regenerating that never
/// wipes these out. Same shape, looked up by the same Translator.
const Map<String, Map<String, String>> appStrings = {
  'app.backendStatus': {'en': 'Backend connection', 'bg': 'Връзка с бекенда'},
  'app.backendChecking': {'en': 'Checking…', 'bg': 'Проверява се…'},
  'app.backendOk': {
    'en': '{movies} trending movies · {series} trending series',
    'bg': '{movies} филма в тренда · {series} сериала в тренда',
  },
  'app.backendDown': {
    'en': 'The server did not answer (it may be waking up) — try again.',
    'bg': 'Сървърът не отговори (може би се събужда) — опитай пак.',
  },
  'app.retry': {'en': 'Try again', 'bg': 'Опитай пак'},
  'app.updateTitle': {'en': 'New version available', 'bg': 'Има нова версия'},
  'app.updateDesc': {'en': 'AuroraFlix {version} is ready to install.', 'bg': 'AuroraFlix {version} е готова за инсталиране.'},
  'app.updateNow': {'en': 'Update', 'bg': 'Обнови'},
  'app.updateLater': {'en': 'Later', 'bg': 'По-късно'},
  'app.updateDownloading': {'en': 'Downloading… {percent}%', 'bg': 'Изтегляне… {percent}%'},
  'app.updateFailed': {
    'en': 'The download failed. Try again, or download it in the browser.',
    'bg': 'Изтеглянето не успя. Опитай пак или го изтегли през браузъра.',
  },
  'app.updateInBrowser': {'en': 'In browser', 'bg': 'В браузъра'},
  'app.searchHint': {'en': 'Type to see matching titles', 'bg': 'Пиши, за да видиш съвпадащи заглавия'},
};
