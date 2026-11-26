.pragma library

var TRANSLATIONS = {
  de: {
    widgetTitle: "Audio Share",
    widgetSubtitleIdle: "Ausgänge auswählen & gemeinsam hören",
    widgetSubtitleActive: "Virtueller Ausgang aktiv · {count} Geräte",
    refresh: "Aktualisieren",
    masterVolume: "Gemeinsame Gesamtlautstärke",
    outputsHeading: "Ausgangsmedien & individuelle Lautstärke",
    mute: "Stumm",
    needTwoDevices: "Bitte mindestens 2 Ausgabegeräte auswählen.",
    hintMinTwo: "Wähle mindestens 2 Ausgabegeräte aus, um den gemeinsamen virtuellen Ausgang zu aktivieren.",
    statusReadError: "Audio-Status konnte nicht gelesen werden."
  },
  en: {
    widgetTitle: "Audio Share",
    widgetSubtitleIdle: "Select outputs & listen together",
    widgetSubtitleActive: "Virtual output active · {count} devices",
    refresh: "Refresh",
    masterVolume: "Shared Master Volume",
    outputsHeading: "Output devices & individual volume",
    mute: "Muted",
    needTwoDevices: "Please select at least 2 output devices.",
    hintMinTwo: "Select at least 2 output devices to enable the shared virtual output.",
    statusReadError: "Could not read audio status."
  },
  fr: {
    widgetTitle: "Audio Share",
    widgetSubtitleIdle: "Sélectionner des sorties & écouter ensemble",
    widgetSubtitleActive: "Sortie virtuelle active · {count} appareils",
    refresh: "Actualiser",
    masterVolume: "Volume principal partagé",
    outputsHeading: "Périphériques de sortie & volume individuel",
    mute: "Muet",
    needTwoDevices: "Veuillez sélectionner au moins 2 périphériques de sortie.",
    hintMinTwo: "Sélectionnez au moins 2 sorties pour activer la sortie virtuelle partagée.",
    statusReadError: "Impossible de lire l'état audio."
  },
  es: {
    widgetTitle: "Audio Share",
    widgetSubtitleIdle: "Seleccionar salidas y escuchar juntos",
    widgetSubtitleActive: "Salida virtual activa · {count} dispositivos",
    refresh: "Actualizar",
    masterVolume: "Volumen maestro compartido",
    outputsHeading: "Dispositivos de salida y volumen individual",
    mute: "Silencio",
    needTwoDevices: "Selecciona al menos 2 dispositivos de salida.",
    hintMinTwo: "Selecciona al menos 2 dispositivos para activar la salida virtual compartida.",
    statusReadError: "No se pudo leer el estado de audio."
  }
};

function resolveLang(localeName) {
  if (!localeName) return "en";
  var code = String(localeName).split(/[_-]/)[0].toLowerCase();
  return TRANSLATIONS[code] ? code : "en";
}

function tr(localeName, key, vars) {
  var lang = resolveLang(localeName);
  var dict = TRANSLATIONS[lang] || TRANSLATIONS.en;
  var text = dict[key] || TRANSLATIONS.en[key] || key;
  if (vars) {
    for (var k in vars) {
      if (Object.prototype.hasOwnProperty.call(vars, k)) {
        text = text.replace("{" + k + "}", String(vars[k]));
      }
    }
  }
  return text;
}
