# Omarchy Audio Share Plugin (`local.audio-share`)

Dieses Omarchy-Quickshell-Plugin bündelt zwei oder mehr PipeWire-Audioausgänge (z. B. Bluetooth-Kopfhörer + USB-DAC oder zwei Kopfhörer gleichzeitig) zu einem **virtuellen gemeinsamen Ausgang** (`omarchy_audio_share`) und erlaubt die **individuelle Lautstärkeregelung und Stummschaltung pro Gerät**.

## So funktioniert die Audio-Steuerung unter Omarchy

- **Audio-Server:** Omarchy nutzt standardmäßig **PipeWire** mit **WirePlumber** sowie `pipewire-pulse` (`pactl`) als kompatible Steuerungsschicht.
- **Virtueller Kombi-Ausgang:** Über `pactl load-module module-combine-sink` legt das Backend-Skript (`scripts/audio-share.sh`) dynamisch einen virtuellen Sink (`omarchy_audio_share`) an, setzt ihn als Standard-Ausgang (`pactl set-default-sink`) und verschiebt laufende Audio-Streams (`pactl move-sink-input`) automatisch dorthin – ganz ohne Neustart von PipeWire.
- **Einzel-Lautstärke pro Kopfhörer:** Da der Combine-Sink den Ton an jeden ausgewählten physischen Sink weiterleitet, behält jedes Ausgabegerät in PipeWire seine eigene Lautstärke (`pactl set-sink-volume <sink> <prozent>%`). So kannst du Kopfhörer A und Kopfhörer B unabhängig voneinander regeln.

## Installation auf Omarchy

### Per GitHub-URL (empfohlen)
```bash
omarchy plugin add https://github.com/<dein-username>/Omarchy-Audio-share.git --enable
```

### Lokal aus einem Ordner
1. Plugin-Ordner nach `~/.config/omarchy/plugins/local.audio-share/` kopieren oder verlinken.
2. Plugin validieren und aktivieren:
   ```bash
   omarchy plugin validate ~/.config/omarchy/plugins/local.audio-share
   omarchy plugin enable local.audio-share
   omarchy-restart-shell
   ```
3. In der oberen Omarchy-Leiste auf **Audio Share** klicken, mindestens zwei Ausgabegeräte anhaken, den Schalter aktivieren und die Lautstärke pro Gerät individuell anpassen.

## System-Theme & Systemsprache

- **System-Theme:** Das Plugin nutzt `qs.Commons as Commons` (`Commons.Color.*`) ohne feste Farbwerte. Sobald du das Omarchy-Theme wechselst (`Super + Ctrl + T` oder `omarchy theme set ...`), übernehmen Widget und Popup automatisch die neuen Farben.
- **Systemsprache:** `i18n.js` liest automatisch die aktuelle System-Locale (`Qt.locale().name`, z. B. `de_DE`, `en_US`, `fr_FR`, `es_ES`; Fallback: Englisch).

## Plugin aktualisieren (wenn du etwas Neues hinzufügst)

- **Lokal bearbeiten:** Änderungen unter `~/.config/omarchy/plugins/local.audio-share/` werden per Datei-Watcher erkannt. Falls UI-Änderungen im QML-Cache hängen bleiben, einmal `omarchy restart shell` (bzw. `omarchy-restart-shell`) ausführen.
- **Über Git / GitHub verteilen:** Version in `manifest.json` erhöhen, pushen und auf Zielsystemen mit `omarchy plugin update local.audio-share` + `omarchy restart shell` aktualisieren.

