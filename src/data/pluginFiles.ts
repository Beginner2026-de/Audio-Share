import manifestRaw from '../../omarchy-audio-share/manifest.json?raw';
import barWidgetRaw from '../../omarchy-audio-share/BarWidget.qml?raw';
import panelRaw from '../../omarchy-audio-share/Panel.qml?raw';
import i18nRaw from '../../omarchy-audio-share/i18n.js?raw';
import audioShareShRaw from '../../omarchy-audio-share/scripts/audio-share.sh?raw';
import readmeRaw from '../../omarchy-audio-share/README.md?raw';
import licenseRaw from '../../omarchy-audio-share/LICENSE?raw';

export interface PluginFile {
  id: string;
  path: string;
  language: string;
  description: string;
  executable?: boolean;
  content: string;
}

export const PLUGIN_FILES: PluginFile[] = [
  {
    id: 'manifest',
    path: 'manifest.json',
    language: 'json',
    description: 'Omarchy Quattro Plugin-Manifest (deklariert bar-widget & panel)',
    content: manifestRaw,
  },
  {
    id: 'bar-widget',
    path: 'BarWidget.qml',
    language: 'qml',
    description: 'Kompaktes Statusleisten-Widget für die Omarchy Top-Bar',
    content: barWidgetRaw,
  },
  {
    id: 'panel',
    path: 'Panel.qml',
    language: 'qml',
    description: 'Popup-Panel zur Geräteauswahl und Einzel-Lautstärkeregelung',
    content: panelRaw,
  },
  {
    id: 'i18n',
    path: 'i18n.js',
    language: 'javascript',
    description: 'Automatische Systemsprachen-Erkennung (DE/EN/FR/ES über Qt.locale().name)',
    content: i18nRaw,
  },
  {
    id: 'script',
    path: 'scripts/audio-share.sh',
    language: 'bash',
    description: 'PipeWire/pactl-Backend für module-combine-sink & Sink-Lautstärken',
    executable: true,
    content: audioShareShRaw,
  },
  {
    id: 'readme',
    path: 'README.md',
    language: 'markdown',
    description: 'Installations- und Validierungsanleitung für Omarchy',
    content: readmeRaw,
  },
  {
    id: 'license',
    path: 'LICENSE',
    language: 'text',
    description: 'MIT-Lizenz (Voraussetzung für den Omarchy Marketplace)',
    content: licenseRaw,
  },
];
