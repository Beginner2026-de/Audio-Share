# Audio Share for Omarchy

Combine two or more PipeWire audio outputs (e.g., Bluetooth headphones, USB DACs, 3.5 mm jack, or HDMI speakers) into a single virtual multi-output sink so multiple people can listen simultaneously while keeping **independent volume and mute controls for every device**.

## Features

- **Virtual Multi-Output Sink:** Dynamically creates `omarchy_audio_share` via PipeWire's `module-combine-sink` without restarting PipeWire and automatically moves active audio streams to it.
- **Per-Headphone Volume & Mute:** Adjust volume (`0–150 %`) and mute state individually for each output device alongside a shared master volume control.
- **Compact Dual-Headphone Bar Icon:** Renders two overlapping headphones directly in the Omarchy top bar without taking up text space.
- **Automatic Theme Sync:** Uses `qs.Commons` (`Commons.Color.*`) so the bar widget and popup match any active Omarchy theme (`Super + Ctrl + T`).
- **Automatic System Language:** Detects the active system locale (`Qt.locale().name`) and adapts automatically between English, German, French, and Spanish (fallback: English).
- **Zero-Setup Scripting:** Helper commands run directly through `bash` via `Quickshell.Io.Process` — no manual `chmod +x` required after installing via Git.

## Requirements

All dependencies are included out of the box on standard Omarchy installations:

- Omarchy (Quattro / Quickshell)
- PipeWire with `pipewire-pulse` (`pactl`)
- `python3`
- `bash`

## Installation

### Option 1: Omarchy Plugin Marketplace (`plugins.omarchy.org`)

1. Open the Omarchy Plugin Store via `Super + Space` (or browse [plugins.omarchy.org](https://plugins.omarchy.org)).
2. Search for **Audio Share** and install it.
3. Restart the shell if the widget does not appear immediately:
   ```bash
   omarchy restart shell
   ```

### Option 2: Install via CLI (GitHub URL)

```bash
omarchy plugin add https://github.com/Beginner2026-de/Omarchy-Audio-share.git --enable
omarchy restart shell
```

### Option 3: Local / Manual Installation

1. Copy or symlink the plugin folder into your local Omarchy plugins directory:
   ```bash
   mkdir -p ~/.config/omarchy/plugins
   ln -s ~/Documents/Github/Omarchy-Audio-share ~/.config/omarchy/plugins/io.github.beginner2026-de.audio-share
   ```
2. Validate and enable the plugin:
   ```bash
   omarchy plugin validate ~/.config/omarchy/plugins/io.github.beginner2026-de.audio-share
   omarchy plugin enable io.github.beginner2026-de.audio-share
   omarchy restart shell
   ```

### Placing the Widget on Your Bar

If you use a customized bar layout in `~/.config/omarchy/shell.json`, place the widget via **Settings → Appearance → Menu Bar** or via CLI:

```bash
omarchy bar move io.github.beginner2026-de.audio-share --section right --index 0
omarchy restart shell
```

## Usage

1. Click the **dual-headphones icon** in the Omarchy top bar.
2. Check **2 or more** output devices you want to combine.
3. Toggle the switch at the top right of the popup to activate the shared virtual output.
4. Use the top slider for overall master volume and each device's slider/mute button to fine-tune individual headphone levels.

## Updating

- **Installed via Marketplace / Git:**
  ```bash
  omarchy plugin update io.github.beginner2026-de.audio-share
  omarchy restart shell
  ```
- **Local development:** Edit files inside the plugin folder and run `omarchy restart shell` if QML component caching prevents hot-reload.

## Removal / Uninstallation

1. Turn off the **Audio Share** toggle in the popup (this unloads the virtual sink and restores your previous default audio output).
2. Disable and remove the plugin:
   ```bash
   omarchy plugin disable io.github.beginner2026-de.audio-share
   omarchy plugin remove io.github.beginner2026-de.audio-share
   omarchy restart shell
   ```
   *(If installed manually via symlink/copy, remove the directory from `~/.config/omarchy/plugins/` instead of `omarchy plugin remove`.)*

## License

MIT — see [LICENSE](LICENSE).
