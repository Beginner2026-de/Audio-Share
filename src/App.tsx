import React, { useMemo, useState } from 'react';
import {
  Bluetooth,
  Check,
  Copy,
  Download,
  FileCode2,
  FolderOpen,
  Headphones,
  Monitor,
  Plus,
  RefreshCw,
  Speaker,
  Terminal,
  Usb,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { PLUGIN_FILES, type PluginFile } from './data/pluginFiles';
import { createZipBlob } from './utils/zipBuilder';

type ViewTab = 'preview' | 'architecture' | 'files';
type DeviceKind = 'bluetooth' | 'headphones' | 'usb' | 'hdmi' | 'speaker';
type SimLang = 'de' | 'en' | 'fr' | 'es';

const SIM_STRINGS: Record<
  SimLang,
  {
    widgetTitle: string;
    subtitleIdle: string;
    subtitleActive: (count: number) => string;
    masterVolume: string;
    outputsHeading: string;
    mute: string;
    hintMinTwo: string;
    refreshTitle: string;
  }
> = {
  de: {
    widgetTitle: 'Audio Share',
    subtitleIdle: 'Ausgänge auswählen & gemeinsam hören',
    subtitleActive: (c) => `Virtueller Ausgang aktiv · ${c} Geräte`,
    masterVolume: 'Gemeinsame Gesamtlautstärke',
    outputsHeading: 'Ausgangsmedien & individuelle Lautstärke',
    mute: 'Stumm',
    hintMinTwo: 'Wähle mindestens 2 Ausgabegeräte aus, um den gemeinsamen virtuellen Ausgang zu aktivieren.',
    refreshTitle: 'Audio-Ausgänge & Lautstärke neu einlesen (z. B. nach Verbinden von Bluetooth-/USB-Kopfhörern). Auswahl bleibt erhalten.',
  },
  en: {
    widgetTitle: 'Audio Share',
    subtitleIdle: 'Select outputs & listen together',
    subtitleActive: (c) => `Virtual output active · ${c} devices`,
    masterVolume: 'Shared Master Volume',
    outputsHeading: 'Output devices & individual volume',
    mute: 'Muted',
    hintMinTwo: 'Select at least 2 output devices to enable the shared virtual output.',
    refreshTitle: 'Rescan audio outputs & volumes (e.g. after connecting Bluetooth/USB headphones). Does not reset your selection.',
  },
  fr: {
    widgetTitle: 'Audio Share',
    subtitleIdle: 'Sélectionner des sorties & écouter ensemble',
    subtitleActive: (c) => `Sortie virtuelle active · ${c} appareils`,
    masterVolume: 'Volume principal partagé',
    outputsHeading: 'Périphériques de sortie & volume individuel',
    mute: 'Muet',
    hintMinTwo: 'Sélectionnez au moins 2 sorties pour activer la sortie virtuelle partagée.',
    refreshTitle: 'Actualiser les sorties audio et volumes (ex. après connexion d’un casque Bluetooth/USB). Ne réinitialise pas la sélection.',
  },
  es: {
    widgetTitle: 'Audio Share',
    subtitleIdle: 'Seleccionar salidas y escuchar juntos',
    subtitleActive: (c) => `Salida virtual activa · ${c} dispositivos`,
    masterVolume: 'Volumen maestro compartido',
    outputsHeading: 'Dispositivos de salida y volumen individual',
    mute: 'Silencio',
    hintMinTwo: 'Selecciona al menos 2 dispositivos para activar la salida virtual compartida.',
    refreshTitle: 'Actualizar salidas de audio y volumen (ej. tras conectar auriculares Bluetooth/USB). No reinicia tu selección.',
  },
};

interface AudioDevice {
  name: string;
  description: string;
  kind: DeviceKind;
  volume: number;
  mute: boolean;
  selected: boolean;
}

interface OmarchyTheme {
  id: string;
  label: string;
  barBg: string;
  surface: string;
  surfaceVariant: string;
  surfaceHigh: string;
  outline: string;
  primary: string;
  primaryContainer: string;
  onSurface: string;
  onSurfaceVariant: string;
}

const OMARCHY_THEMES: OmarchyTheme[] = [
  {
    id: 'tokyo-night',
    label: 'Tokyo Night',
    barBg: '#16161e',
    surface: '#1a1b26',
    surfaceVariant: '#24283b',
    surfaceHigh: '#292e42',
    outline: '#3b4261',
    primary: '#7aa2f7',
    primaryContainer: 'rgba(122, 162, 247, 0.14)',
    onSurface: '#c0caf5',
    onSurfaceVariant: '#787c99',
  },
  {
    id: 'catppuccin',
    label: 'Catppuccin Mocha',
    barBg: '#181825',
    surface: '#1e1e2e',
    surfaceVariant: '#262637',
    surfaceHigh: '#313244',
    outline: '#45475a',
    primary: '#89b4fa',
    primaryContainer: 'rgba(137, 180, 250, 0.14)',
    onSurface: '#cdd6f4',
    onSurfaceVariant: '#9399b2',
  },
  {
    id: 'gruvbox',
    label: 'Gruvbox Dark',
    barBg: '#1d2021',
    surface: '#282828',
    surfaceVariant: '#32302f',
    surfaceHigh: '#3c3836',
    outline: '#504945',
    primary: '#fabd2f',
    primaryContainer: 'rgba(250, 189, 47, 0.14)',
    onSurface: '#ebdbb2',
    onSurfaceVariant: '#a89984',
  },
  {
    id: 'nord',
    label: 'Nord',
    barBg: '#242933',
    surface: '#2e3440',
    surfaceVariant: '#3b4252',
    surfaceHigh: '#434c5e',
    outline: '#4c566a',
    primary: '#88c0d0',
    primaryContainer: 'rgba(136, 192, 208, 0.14)',
    onSurface: '#eceff4',
    onSurfaceVariant: '#9aa5b8',
  },
];

const INITIAL_DEVICES: AudioDevice[] = [
  {
    name: 'bluez_output.88_C9_E8_14_2B_9A.1',
    description: 'Sony WH-1000XM5 (Bluetooth)',
    kind: 'bluetooth',
    volume: 85,
    mute: false,
    selected: true,
  },
  {
    name: 'alsa_output.usb-FiiO_K7_DAC-00.analog-stereo',
    description: 'FiiO K7 USB-DAC · Kopfhörer 2',
    kind: 'usb',
    volume: 65,
    mute: false,
    selected: true,
  },
  {
    name: 'alsa_output.pci-0000_00_1f.3.analog-stereo',
    description: 'Built-in Audio · Klinke 3.5 mm',
    kind: 'headphones',
    volume: 75,
    mute: false,
    selected: false,
  },
  {
    name: 'alsa_output.pci-0000_01_00.1.hdmi-stereo',
    description: 'DisplayPort / Monitor-Lautsprecher',
    kind: 'hdmi',
    volume: 50,
    mute: true,
    selected: false,
  },
];

function DualHeadphonesIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className={className}
      aria-hidden="true"
    >
      {/* Hinterer Kopfhörer (rechts oben versetzt) */}
      <g opacity="0.55">
        <path
          d="M8.5 11.5V9.5a5.5 5.5 0 0 1 11 0v2"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
        />
        <rect x="7.5" y="10.5" width="2.6" height="4.8" rx="1.2" fill="currentColor" />
        <rect x="17.9" y="10.5" width="2.6" height="4.8" rx="1.2" fill="currentColor" />
      </g>
      {/* Vorderer Kopfhörer (links unten versetzt) */}
      <g>
        <path
          d="M4.5 15.5V13.5a5.5 5.5 0 0 1 11 0v2"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
        />
        <rect x="3.5" y="14.5" width="2.6" height="4.8" rx="1.2" fill="currentColor" />
        <rect x="13.9" y="14.5" width="2.6" height="4.8" rx="1.2" fill="currentColor" />
      </g>
    </svg>
  );
}

function DeviceIcon({ kind, className }: { kind: DeviceKind; className?: string }) {
  switch (kind) {
    case 'bluetooth':
      return <Bluetooth className={className} />;
    case 'usb':
      return <Usb className={className} />;
    case 'hdmi':
      return <Monitor className={className} />;
    case 'headphones':
      return <Headphones className={className} />;
    default:
      return <Speaker className={className} />;
  }
}

export default function App() {
  const [activeTab, setActiveTab] = useState<ViewTab>('preview');
  const [themeId, setThemeId] = useState<string>('tokyo-night');
  const [simLang, setSimLang] = useState<SimLang>('de');
  const [panelOpen, setPanelOpen] = useState<boolean>(true);
  const [devices, setDevices] = useState<AudioDevice[]>(INITIAL_DEVICES);
  const [virtualActive, setVirtualActive] = useState<boolean>(true);
  const [masterVolume, setMasterVolume] = useState<number>(90);
  const [masterMute, setMasterMute] = useState<boolean>(false);
  const [commandLog, setCommandLog] = useState<string[]>([
    'pactl load-module module-combine-sink sink_name=omarchy_audio_share sink_properties=device.description="Audio Share (Multi-Output)" slaves=bluez_output.88_C9_E8_14_2B_9A.1,alsa_output.usb-FiiO_K7_DAC-00.analog-stereo',
    'pactl set-default-sink omarchy_audio_share',
  ]);
  const [newDeviceLabel, setNewDeviceLabel] = useState<string>('');
  const [selectedFileId, setSelectedFileId] = useState<string>(PLUGIN_FILES[0].id);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState<boolean>(false);

  const theme = useMemo(
    () => OMARCHY_THEMES.find((t) => t.id === themeId) ?? OMARCHY_THEMES[0],
    [themeId]
  );
  const simT = SIM_STRINGS[simLang];

  const selectedDevices = useMemo(() => devices.filter((d) => d.selected), [devices]);
  const activeFile: PluginFile = useMemo(
    () => PLUGIN_FILES.find((f) => f.id === selectedFileId) ?? PLUGIN_FILES[0],
    [selectedFileId]
  );

  const pushCommand = (cmd: string) => {
    setCommandLog((prev) => [cmd, ...prev].slice(0, 6));
  };

  const handleToggleVirtual = () => {
    if (virtualActive) {
      setVirtualActive(false);
      pushCommand('pactl unload-module <omarchy_audio_share_id> && pactl set-default-sink <vorheriger-sink>');
      return;
    }
    if (selectedDevices.length < 2) {
      return;
    }
    const slaves = selectedDevices.map((d) => d.name).join(',');
    setVirtualActive(true);
    pushCommand(
      `pactl load-module module-combine-sink sink_name=omarchy_audio_share slaves=${slaves}`
    );
  };

  const handleToggleDevice = (sinkName: string) => {
    const toggled = devices.map((d) => (d.name === sinkName ? { ...d, selected: !d.selected } : d));
    const next = [
      ...toggled.filter((d) => d.selected),
      ...toggled.filter((d) => !d.selected),
    ];
    setDevices(next);
    const nextSelected = next.filter((d) => d.selected);
    if (virtualActive) {
      if (nextSelected.length >= 2) {
        const slaves = nextSelected.map((d) => d.name).join(',');
        pushCommand(
          `pactl unload-module <id> && pactl load-module module-combine-sink sink_name=omarchy_audio_share slaves=${slaves}`
        );
      } else {
        setVirtualActive(false);
        pushCommand('pactl unload-module <omarchy_audio_share_id>');
      }
    }
  };

  const handleRefreshOutputs = () => {
    setRefreshing(true);
    pushCommand(`pactl -f json list sinks (${devices.length} Ausgänge aktualisiert)`);
    window.setTimeout(() => setRefreshing(false), 450);
  };

  const handleDeviceVolume = (sinkName: string, vol: number) => {
    setDevices((prev) => prev.map((d) => (d.name === sinkName ? { ...d, volume: vol } : d)));
  };

  const commitDeviceVolume = (sinkName: string, vol: number) => {
    pushCommand(`pactl set-sink-volume ${sinkName} ${vol}%`);
  };

  const handleDeviceMute = (sinkName: string) => {
    setDevices((prev) =>
      prev.map((d) => {
        if (d.name !== sinkName) return d;
        pushCommand(`pactl set-sink-mute ${sinkName} toggle`);
        return { ...d, mute: !d.mute };
      })
    );
  };

  const handleMasterMute = () => {
    setMasterMute((prev) => !prev);
    pushCommand(`pactl set-sink-mute ${virtualActive ? 'omarchy_audio_share' : '@DEFAULT_SINK@'} toggle`);
  };

  const handleAddSimulatedDevice = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = newDeviceLabel.trim();
    if (!trimmed) return;
    const slug = trimmed
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_|_$/g, '');
    const sinkName = `bluez_output.${slug || 'extra'}.a2dp-sink`;
    setDevices((prev) => [
      ...prev,
      {
        name: sinkName,
        description: trimmed,
        kind: 'bluetooth',
        volume: 80,
        mute: false,
        selected: false,
      },
    ]);
    setNewDeviceLabel('');
    pushCommand(`# Neues Ausgabegerät erkannt: ${sinkName}`);
  };

  const handleCopy = async (key: string, text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedKey(key);
      window.setTimeout(() => setCopiedKey(null), 1800);
    } catch {
      // Clipboard API ggf. durch Browser eingeschränkt
    }
  };

  const handleDownloadZip = () => {
    const entries = PLUGIN_FILES.map((f) => ({
      path: f.path,
      content: f.content,
      executable: f.executable,
    }));
    const blob = createZipBlob(entries);
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = 'Audio-Share.zip';
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="min-h-screen bg-[#0b0e14] text-slate-100 flex flex-col">
      {/* Top Bar Contract: 3 Zonen (Wortmarke | Navigation | 1 Primäraktion) */}
      <header className="border-b border-slate-800/80 bg-[#0d1118]">
        <div className="max-w-[1280px] mx-auto px-6 py-4 flex items-center justify-between gap-8">
          <a
            href="#top"
            onClick={(e) => {
              e.preventDefault();
              setActiveTab('preview');
            }}
            className="text-base font-bold tracking-tight text-slate-100 whitespace-nowrap shrink-0"
          >
            Omarchy Audio Share
          </a>

          <nav className="flex items-center gap-6 text-sm font-medium text-slate-400">
            <button
              type="button"
              onClick={() => setActiveTab('preview')}
              className={`whitespace-nowrap shrink-0 py-1 transition-colors cursor-pointer ${
                activeTab === 'preview'
                  ? 'text-slate-100 border-b border-sky-400'
                  : 'hover:text-slate-200'
              }`}
            >
              Live-Vorschau
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('architecture')}
              className={`whitespace-nowrap shrink-0 py-1 transition-colors cursor-pointer ${
                activeTab === 'architecture'
                  ? 'text-slate-100 border-b border-sky-400'
                  : 'hover:text-slate-200'
              }`}
            >
              Audio-Architektur
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('files')}
              className={`whitespace-nowrap shrink-0 py-1 transition-colors cursor-pointer ${
                activeTab === 'files'
                  ? 'text-slate-100 border-b border-sky-400'
                  : 'hover:text-slate-200'
              }`}
            >
              Plugin-Dateien
            </button>
          </nav>

          <div className="shrink-0">
            <button
              type="button"
              onClick={handleDownloadZip}
              className="inline-flex items-center gap-2 px-4 py-2 text-xs font-semibold text-slate-950 bg-sky-400 hover:bg-sky-300 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              <Download className="w-4 h-4" />
              Plugin (.zip) laden
            </button>
          </div>
        </div>
      </header>

      <main className="flex-1 max-w-[1280px] w-full mx-auto px-6 py-8">
        {activeTab === 'preview' && (
          <div className="space-y-8">
            <div className="flex flex-col lg:flex-row lg:items-end justify-between gap-4">
              <div>
                <p className="text-xs text-slate-400 mb-2">
                  Quickshell Plugin · PipeWire Multi-Output · io.github.beginner2026-de.audio-share
                </p>
                <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-100 max-w-2xl">
                  Mehrere Kopfhörer zu einem virtuellen Ausgang bündeln
                </h1>
              </div>

              {/* Omarchy Theme & Sprache Umschalter */}
              <div className="flex flex-wrap items-center gap-3 self-start">
                <div className="flex items-center gap-1 p-1 bg-[#131822] border border-slate-800 rounded-lg">
                  {(['de', 'en', 'fr', 'es'] as SimLang[]).map((lang) => (
                    <button
                      key={lang}
                      type="button"
                      onClick={() => setSimLang(lang)}
                      className={`px-2.5 py-1.5 text-xs font-mono font-medium rounded-md transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        simLang === lang
                          ? 'bg-slate-800 text-slate-100'
                          : 'text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      {lang.toUpperCase()}
                    </button>
                  ))}
                </div>

                <div className="flex items-center gap-1 p-1 bg-[#131822] border border-slate-800 rounded-lg">
                  {OMARCHY_THEMES.map((t) => (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => setThemeId(t.id)}
                      className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        themeId === t.id
                          ? 'bg-slate-800 text-slate-100'
                          : 'text-slate-400 hover:text-slate-200'
                      }`}
                    >
                      {t.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
              {/* Linke Spalte: Omarchy Top Bar + Quickshell Panel.qml Simulator */}
              <div
                className="lg:col-span-7 bg-[#11151f] border border-slate-800 rounded-2xl p-5"
                onClick={() => {
                  if (panelOpen) setPanelOpen(false);
                }}
              >
                {/* Simulierte Omarchy Top Bar */}
                <div
                  className="rounded-xl px-4 py-2 flex items-center justify-between border transition-colors"
                  style={{
                    backgroundColor: theme.barBg,
                    borderColor: theme.outline,
                    color: theme.onSurface,
                  }}
                >
                  <div className="flex items-center gap-4 text-xs font-mono">
                    <span className="font-semibold">1 · 2 · 3</span>
                    <span style={{ color: theme.onSurfaceVariant }}>Hyprland</span>
                  </div>

                  <div className="flex items-center gap-3">
                    {/* BarWidget.qml Vorschau: nur Doppel-Kopfhörer-Icon ohne Text und ohne Hintergrund-Box */}
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        setPanelOpen((v) => !v);
                      }}
                      title={
                        virtualActive
                          ? simT.subtitleActive(selectedDevices.length)
                          : simT.subtitleIdle
                      }
                      aria-label={simT.widgetTitle}
                      className="inline-flex items-center justify-center w-6 h-6 cursor-pointer shrink-0 bg-transparent border-0"
                      style={{
                        color: virtualActive ? theme.primary : theme.onSurface,
                      }}
                    >
                      <DualHeadphonesIcon className="w-4 h-4" />
                    </button>
                    <span
                      className="text-xs font-mono tabular-nums"
                      style={{ color: theme.onSurfaceVariant }}
                    >
                      10:04
                    </span>
                  </div>
                </div>

                {/* Simuliertes Panel.qml Popup */}
                <div className="mt-4 flex justify-end">
                  {panelOpen ? (
                    <div
                      onClick={(e) => e.stopPropagation()}
                      className="w-full max-w-[460px] rounded-[14px] p-4 border transition-colors"
                      style={{
                        backgroundColor: theme.surface,
                        borderColor: theme.outline,
                        color: theme.onSurface,
                      }}
                    >
                      {/* Panel Kopfzeile */}
                      <div className="flex items-center justify-between gap-4 pb-3">
                        <div className="min-w-0">
                          <h2 className="text-base font-bold truncate">{simT.widgetTitle}</h2>
                          <p
                            className="text-xs truncate"
                            style={{
                              color: virtualActive
                                ? theme.primary
                                : theme.onSurfaceVariant,
                            }}
                          >
                            {virtualActive
                              ? simT.subtitleActive(selectedDevices.length)
                              : simT.subtitleIdle}
                          </p>
                        </div>

                        <div className="flex items-center gap-2 shrink-0">
                          <button
                            type="button"
                            onClick={handleRefreshOutputs}
                            title={simT.refreshTitle}
                            aria-label={simT.refreshTitle}
                            className="p-2 rounded-lg hover:opacity-80 transition-opacity cursor-pointer"
                            style={{ color: refreshing ? theme.primary : theme.onSurfaceVariant }}
                          >
                            <RefreshCw className={`w-4 h-4 transition-transform duration-300 ${refreshing ? 'rotate-180' : ''}`} />
                          </button>

                          <button
                            type="button"
                            role="switch"
                            aria-checked={virtualActive}
                            aria-label="Virtuellen Ausgang umschalten"
                            disabled={!virtualActive && selectedDevices.length < 2}
                            onClick={handleToggleVirtual}
                            className="w-11 h-6 rounded-full p-0.5 transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
                            style={{
                              backgroundColor: virtualActive
                                ? theme.primary
                                : theme.surfaceHigh,
                            }}
                          >
                            <span
                              className={`block w-5 h-5 rounded-full bg-white transition-transform ${
                                virtualActive ? 'translate-x-5' : 'translate-x-0'
                              }`}
                            />
                          </button>
                        </div>
                      </div>

                      {/* Gemeinsame Gesamtlautstärke */}
                      <div
                        className="rounded-[10px] p-3 border mb-4"
                        style={{
                          backgroundColor: theme.surfaceVariant,
                          borderColor: virtualActive ? theme.primary : theme.outline,
                        }}
                      >
                        <div className="flex items-center justify-between gap-3 mb-2">
                          <span className="text-xs font-semibold">
                            {simT.masterVolume}
                          </span>
                          <div className="flex items-center gap-2">
                            <span
                              className="text-xs font-mono tabular-nums"
                              style={{ color: theme.onSurfaceVariant }}
                            >
                              {masterMute ? simT.mute : `${masterVolume} %`}
                            </span>
                            <button
                              type="button"
                              onClick={handleMasterMute}
                              aria-label="Gesamtausgang stummschalten"
                              className="p-1.5 rounded-md hover:opacity-80 cursor-pointer"
                              style={{ color: theme.onSurface }}
                            >
                              {masterMute ? (
                                <VolumeX className="w-4 h-4" />
                              ) : (
                                <Volume2 className="w-4 h-4" />
                              )}
                            </button>
                          </div>
                        </div>

                        <input
                          type="range"
                          min={0}
                          max={150}
                          value={masterVolume}
                          disabled={masterMute}
                          onChange={(e) => setMasterVolume(Number(e.target.value))}
                          onMouseUp={(e) =>
                            pushCommand(
                              `pactl set-sink-volume ${
                                virtualActive ? 'omarchy_audio_share' : '@DEFAULT_SINK@'
                              } ${(e.target as HTMLInputElement).value}%`
                            )
                          }
                          className="w-full omarchy-slider"
                          style={
                            {
                              backgroundColor: theme.surfaceHigh,
                              '--slider-accent': theme.primary,
                            } as React.CSSProperties
                          }
                        />
                      </div>

                      {/* Liste der einzelnen Ausgangsmedien */}
                      <div className="mb-2 flex items-center justify-between">
                        <span
                          className="text-xs font-semibold"
                          style={{ color: theme.onSurfaceVariant }}
                        >
                          {simT.outputsHeading}
                        </span>
                        <span
                          className="text-xs font-mono tabular-nums"
                          style={{ color: theme.onSurfaceVariant }}
                        >
                          {selectedDevices.length}/{devices.length}
                        </span>
                      </div>

                      <div className="space-y-2 max-h-[310px] overflow-y-auto pr-0.5">
                        {devices.map((dev) => (
                          <div
                            key={dev.name}
                            className="rounded-[10px] p-3 border transition-colors"
                            style={{
                              backgroundColor: dev.selected
                                ? theme.surfaceHigh
                                : theme.surfaceVariant,
                              borderColor: dev.selected ? theme.primary : theme.outline,
                            }}
                          >
                            <div className="flex items-center gap-2.5 mb-2">
                              <input
                                type="checkbox"
                                checked={dev.selected}
                                onChange={() => handleToggleDevice(dev.name)}
                                aria-label={`${dev.description} auswählen`}
                                className="w-4 h-4 rounded cursor-pointer accent-sky-400"
                              />
                              <span
                                style={{
                                  color: dev.selected
                                    ? theme.primary
                                    : theme.onSurfaceVariant,
                                }}
                              >
                                <DeviceIcon kind={dev.kind} className="w-4 h-4" />
                              </span>
                              <span
                                className={`text-xs flex-1 truncate ${
                                  dev.selected ? 'font-semibold' : 'font-normal'
                                }`}
                              >
                                {dev.description}
                              </span>
                              <span
                                className="text-xs font-mono tabular-nums shrink-0"
                                style={{ color: theme.onSurfaceVariant }}
                              >
                                {dev.mute ? simT.mute : `${dev.volume} %`}
                              </span>
                              <button
                                type="button"
                                onClick={() => handleDeviceMute(dev.name)}
                                aria-label={`${dev.description} stummschalten`}
                                className="p-1.5 rounded-md hover:opacity-80 cursor-pointer shrink-0"
                                style={{ color: theme.onSurface }}
                              >
                                {dev.mute ? (
                                  <VolumeX className="w-3.5 h-3.5" />
                                ) : (
                                  <Volume2 className="w-3.5 h-3.5" />
                                )}
                              </button>
                            </div>

                            <input
                              type="range"
                              min={0}
                              max={150}
                              value={dev.volume}
                              disabled={dev.mute}
                              onChange={(e) =>
                                handleDeviceVolume(dev.name, Number(e.target.value))
                              }
                              onMouseUp={(e) =>
                                commitDeviceVolume(
                                  dev.name,
                                  Number((e.target as HTMLInputElement).value)
                                )
                              }
                              className="w-full omarchy-slider disabled:opacity-40"
                              style={
                                {
                                  backgroundColor: theme.barBg,
                                  '--slider-accent': theme.primary,
                                } as React.CSSProperties
                              }
                            />
                          </div>
                        ))}
                      </div>

                      {selectedDevices.length < 2 && (
                        <p
                          className="mt-3 text-xs"
                          style={{ color: theme.onSurfaceVariant }}
                        >
                          {simT.hintMinTwo}
                        </p>
                      )}
                    </div>
                  ) : (
                    <div className="w-full py-12 text-center text-sm text-slate-400">
                      Klicke oben in der Omarchy-Leiste auf das Doppel-Kopfhörer-Symbol, um das
                      Popup wieder zu öffnen.
                    </div>
                  )}
                </div>
              </div>

              {/* Rechte Spalte: Testgerät hinzufügen + Live PipeWire Befehle + Schnellinstallation */}
              <div className="lg:col-span-5 space-y-6">
                <section className="bg-[#11151f] border border-slate-800 rounded-2xl p-5 space-y-4">
                  <h3 className="text-sm font-semibold text-slate-100">
                    Weiteres Ausgabegerät in der Vorschau testen
                  </h3>
                  <form onSubmit={handleAddSimulatedDevice} className="flex gap-2">
                    <input
                      type="text"
                      value={newDeviceLabel}
                      onChange={(e) => setNewDeviceLabel(e.target.value)}
                      placeholder="z. B. AirPods Pro (Bluetooth)"
                      className="flex-1 min-w-0 bg-[#0b0e14] border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-sky-400"
                    />
                    <button
                      type="submit"
                      className="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-100 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      Hinzufügen
                    </button>
                  </form>
                </section>

                <section className="bg-[#11151f] border border-slate-800 rounded-2xl p-5 space-y-3">
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-semibold text-slate-100">
                      Ausgeführte PipeWire / pactl-Befehle
                    </h3>
                    <span className="text-xs text-slate-400">Live-Protokoll</span>
                  </div>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Jede Änderung im Plugin-Panel ruft im Hintergrund{' '}
                    <code className="text-slate-200">scripts/audio-share.sh</code> auf und steuert
                    PipeWire direkt über <code className="text-slate-200">pactl</code>:
                  </p>
                  <div className="bg-[#0b0e14] border border-slate-800 rounded-xl p-3 space-y-2 max-h-[210px] overflow-y-auto">
                    {commandLog.map((cmd, idx) => (
                      <div
                        key={`${idx}-${cmd}`}
                        className={`text-[11px] font-mono break-all leading-relaxed ${
                          idx === 0 ? 'text-sky-300' : 'text-slate-500'
                        }`}
                      >
                        $ {cmd}
                      </div>
                    ))}
                  </div>
                </section>

                <section className="bg-[#11151f] border border-slate-800 rounded-2xl p-5 space-y-3">
                  <h3 className="text-sm font-semibold text-slate-100">
                    Installation auf Omarchy (Beginner2026-de)
                  </h3>
                  <div className="bg-[#0b0e14] border border-slate-800 rounded-xl p-3 text-xs font-mono text-slate-300 space-y-1.5 overflow-x-auto">
                    <div>omarchy plugin add https://github.com/Beginner2026-de/Audio-Share.git --enable</div>
                    <div>omarchy restart shell</div>
                  </div>
                  <div className="flex items-center gap-3 pt-1">
                    <button
                      type="button"
                      onClick={() =>
                        handleCopy(
                          'install-cmd',
                          [
                            'omarchy plugin add https://github.com/Beginner2026-de/Audio-Share.git --enable',
                            'omarchy restart shell',
                          ].join('\n')
                        )
                      }
                      className="inline-flex items-center gap-1.5 px-3 py-2 text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-100 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      {copiedKey === 'install-cmd' ? (
                        <Check className="w-3.5 h-3.5 text-emerald-400" />
                      ) : (
                        <Copy className="w-3.5 h-3.5" />
                      )}
                      {copiedKey === 'install-cmd' ? 'Kopiert' : 'Befehle kopieren'}
                    </button>
                    <button
                      type="button"
                      onClick={() => setActiveTab('files')}
                      className="text-xs font-medium text-sky-400 hover:text-sky-300 whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      Alle {PLUGIN_FILES.length} Plugin-Dateien ansehen →
                    </button>
                  </div>
                </section>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'architecture' && (
          <div className="max-w-4xl space-y-8">
            <div>
              <p className="text-xs text-slate-400 mb-2">
                Systemanalyse · PipeWire · WirePlumber · Quickshell
              </p>
              <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-slate-100">
                Wie die Audiosteuerung in Omarchy funktioniert
              </h1>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-[#11151f] border border-slate-800 rounded-2xl p-6 space-y-3">
                <h2 className="text-base font-semibold text-slate-100">
                  1. PipeWire &amp; WirePlumber als Kern
                </h2>
                <p className="text-sm text-slate-400 leading-relaxed">
                  Omarchy setzt auf Arch Linux mit <strong className="text-slate-200">PipeWire</strong>{' '}
                  als Audio-Server, <strong className="text-slate-200">WirePlumber</strong> als
                  Session-Manager (Geräteerkennung, Bluetooth A2DP, Standard-Sink) sowie{' '}
                  <strong className="text-slate-200">pipewire-pulse</strong>. Standardmäßig nutzt
                  Omarchy <code className="text-slate-200">wpctl</code>,{' '}
                  <code className="text-slate-200">pactl</code> und den TUI-Mixer{' '}
                  <code className="text-slate-200">wiremix</code>.
                </p>
              </div>

              <div className="bg-[#11151f] border border-slate-800 rounded-2xl p-6 space-y-3">
                <h2 className="text-base font-semibold text-slate-100">
                  2. Warum wir pactl für Bluetooth &amp; Kombi-Ausgänge nutzen
                </h2>
                <p className="text-sm text-slate-400 leading-relaxed">
                  Bei einigen Quickshell/PipeWire-Kombinationen greifen direkte QML-Volume-Writes
                  auf Bluetooth-Kopfhörern nicht zuverlässig. Das Backend-Skript nutzt daher bewusst{' '}
                  <code className="text-slate-200">pactl</code> (inkl.{' '}
                  <code className="text-slate-200">pactl -f json list sinks</code>), was sowohl mit
                  ALSA/USB-DACs als auch mit Bluetooth-Sinks sauber funktioniert.
                </p>
              </div>

              <div className="bg-[#11151f] border border-slate-800 rounded-2xl p-6 space-y-3">
                <h2 className="text-base font-semibold text-slate-100">
                  3. Virtueller Ausgang ohne Neustart (module-combine-sink)
                </h2>
                <p className="text-sm text-slate-400 leading-relaxed">
                  Statt statischer Konfigurationsdateien mit PipeWire-Neustart lädt das Plugin zur
                  Laufzeit <code className="text-slate-200">module-combine-sink</code> mit den
                  gewählten Geräten (<code className="text-slate-200">slaves=...</code>), setzt{' '}
                  <code className="text-slate-200">omarchy_audio_share</code> als Standard-Sink und
                  verschiebt aktive Audio-Streams sofort mit{' '}
                  <code className="text-slate-200">pactl move-sink-input</code>.
                </p>
              </div>

              <div className="bg-[#11151f] border border-slate-800 rounded-2xl p-6 space-y-3">
                <h2 className="text-base font-semibold text-slate-100">
                  4. Getrennte Lautstärke pro Kopfhörer
                </h2>
                <p className="text-sm text-slate-400 leading-relaxed">
                  Der virtuelle Ausgang verteilt denselben Audiostream an alle ausgewählten
                  physischen Sinks. Jeder einzelne Kopfhörer behält dabei in PipeWire seinen eigenen
                  Hardware-/Software-Gain (<code className="text-slate-200">pactl set-sink-volume</code>)
                  und seinen eigenen Mute-Status — unabhängig von der gemeinsamen Master-Lautstärke.
                </p>
              </div>
            </div>

            <div className="bg-[#11151f] border border-slate-800 rounded-2xl p-6 space-y-4">
              <div className="flex items-center gap-2 text-slate-100">
                <Terminal className="w-4 h-4 text-sky-400" />
                <h2 className="text-base font-semibold">
                  System-Theme, Systemsprache &amp; Plugin-Updates
                </h2>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-5 text-sm text-slate-400 leading-relaxed">
                <div>
                  <h3 className="text-slate-200 font-semibold mb-1">System-Theme</h3>
                  <p>
                    Über <code className="text-slate-200">import qs.Commons as Commons</code> und{' '}
                    <code className="text-slate-200">Commons.Color.*</code> passt sich das Plugin
                    automatisch an jeden Theme-Wechsel in Omarchy an (inkl. Schutz vor Qt-6.12-Shadowing).
                  </p>
                </div>
                <div>
                  <h3 className="text-slate-200 font-semibold mb-1">Systemsprache</h3>
                  <p>
                    <code className="text-slate-200">i18n.js</code> wertet{' '}
                    <code className="text-slate-200">Qt.locale().name</code> aus und wählt
                    automatisch Deutsch, Englisch, Französisch oder Spanisch (Fallback: Englisch).
                  </p>
                </div>
                <div>
                  <h3 className="text-slate-200 font-semibold mb-1">Updates einspielen</h3>
                  <p>
                    Lokale Änderungen erkennt Omarchy per Datei-Watcher; bei QML-Cache hilft{' '}
                    <code className="text-slate-200">omarchy restart shell</code>. Bei Git-Plugins
                    genügt{' '}
                    <code className="text-slate-200">
                      omarchy plugin update io.github.beginner2026-de.audio-share
                    </code>
                    .
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'files' && (
          <div className="space-y-6">
            <div className="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
              <div>
                <p className="text-xs text-slate-400 mb-2">
                  Repo-Root · github.com/Beginner2026-de/Audio-Share
                </p>
                <h1 className="text-2xl font-bold tracking-tight text-slate-100">
                  Erzeugte Plugin-Dateien
                </h1>
              </div>

              <button
                type="button"
                onClick={() => handleCopy(activeFile.id, activeFile.content)}
                className="inline-flex items-center gap-2 px-4 py-2 text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-100 rounded-lg transition-colors whitespace-nowrap shrink-0 cursor-pointer self-start"
              >
                {copiedKey === activeFile.id ? (
                  <Check className="w-4 h-4 text-emerald-400" />
                ) : (
                  <Copy className="w-4 h-4" />
                )}
                {copiedKey === activeFile.id ? 'Datei kopiert' : `${activeFile.path} kopieren`}
              </button>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
              <aside className="lg:col-span-4 bg-[#11151f] border border-slate-800 rounded-2xl p-3 space-y-1">
                <div className="flex items-center gap-2 px-3 py-2 text-xs font-semibold text-slate-400">
                  <FolderOpen className="w-4 h-4" />
                  <span>Audio-Share/</span>
                </div>
                {PLUGIN_FILES.map((file) => (
                  <button
                    key={file.id}
                    type="button"
                    onClick={() => setSelectedFileId(file.id)}
                    className={`w-full text-left px-3 py-2.5 rounded-xl transition-colors flex items-start gap-2.5 cursor-pointer ${
                      selectedFileId === file.id
                        ? 'bg-slate-800 text-slate-100'
                        : 'text-slate-400 hover:bg-slate-800/50 hover:text-slate-200'
                    }`}
                  >
                    <FileCode2 className="w-4 h-4 mt-0.5 shrink-0 text-sky-400" />
                    <div className="min-w-0">
                      <div className="text-xs font-mono truncate">{file.path}</div>
                      <div className="text-[11px] text-slate-500 line-clamp-1 mt-0.5">
                        {file.description}
                      </div>
                    </div>
                  </button>
                ))}
              </aside>

              <div className="lg:col-span-8 bg-[#11151f] border border-slate-800 rounded-2xl overflow-hidden">
                <div className="px-4 py-3 border-b border-slate-800 flex items-center justify-between gap-4">
                  <span className="text-xs font-mono text-slate-200 truncate">
                    {activeFile.path}
                  </span>
                  <span className="text-xs text-slate-400 shrink-0">
                    {activeFile.language}
                    {activeFile.executable ? ' · chmod +x' : ''}
                  </span>
                </div>
                <pre className="p-4 text-xs font-mono text-slate-200 overflow-x-auto leading-relaxed max-h-[600px] overflow-y-auto">
                  <code>{activeFile.content}</code>
                </pre>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
