#!/usr/bin/env bash
set -euo pipefail

VIRTUAL_SINK_NAME="omarchy_audio_share"
VIRTUAL_SINK_DESC="Audio Share (Multi-Output)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-audio-share"
PREV_SINK_FILE="$STATE_DIR/prev-sink"
SLAVES_FILE="$STATE_DIR/slaves"

mkdir -p "$STATE_DIR"

require_cmds() {
  for cmd in pactl python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "{\"error\": \"Fehlendes Kommando: $cmd\"}" >&2
      exit 1
    fi
  done
}

cmd_status() {
  python3 - "$VIRTUAL_SINK_NAME" "$SLAVES_FILE" <<'PY'
import json, subprocess, sys, os

virtual_name = sys.argv[1]
slaves_file = sys.argv[2]

def run(cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)

try:
    sinks_raw = json.loads(run(["pactl", "-f", "json", "list", "sinks"]))
except Exception:
    sinks_raw = []

try:
    modules_raw = json.loads(run(["pactl", "-f", "json", "list", "modules"]))
except Exception:
    modules_raw = []

try:
    default_sink = run(["pactl", "get-default-sink"]).strip()
except Exception:
    default_sink = ""

saved_slaves = []
if os.path.exists(slaves_file):
    with open(slaves_file, "r", encoding="utf-8") as f:
        saved_slaves = [s.strip() for s in f.read().split(",") if s.strip()]

def extract_vol(vol_obj):
    if not isinstance(vol_obj, dict) or not vol_obj:
        return 100
    vals = []
    for ch in vol_obj.values():
        vp = str(ch.get("value_percent", "100%")).rstrip("%").strip()
        try:
            vals.append(int(vp))
        except ValueError:
            pass
    return round(sum(vals) / len(vals)) if vals else 100

def classify_icon(name, props):
    n = (name or "").lower()
    icon = str(props.get("device.icon_name", "")).lower()
    bus = str(props.get("device.bus", "")).lower()
    form = str(props.get("device.form_factor", "")).lower()
    if "bluez" in n or "bluetooth" in icon or bus == "bluetooth":
        return "bluetooth"
    if "headphone" in icon or "headset" in icon or form in ("headphone", "headset"):
        return "headphones"
    if "hdmi" in n or "displayport" in n:
        return "hdmi"
    if "usb" in n or bus == "usb":
        return "usb"
    return "speaker"

virtual_active = False
virtual_volume = 100
virtual_mute = False
module_id = None
active_slaves = []

for mod in modules_raw:
    if mod.get("name") == "module-combine-sink":
        arg = str(mod.get("argument", ""))
        if f"sink_name={virtual_name}" in arg:
            module_id = mod.get("index")
            for part in arg.split():
                if part.startswith("slaves="):
                    active_slaves = [s.strip() for s in part[7:].split(",") if s.strip()]

selected_set = set(active_slaves if active_slaves else saved_slaves)

physical_sinks = []
for s in sinks_raw:
    name = s.get("name", "")
    props = s.get("properties", {}) or {}
    if name == virtual_name or s.get("driver") == "module-combine-sink":
        if name == virtual_name:
            virtual_active = True
            virtual_volume = extract_vol(s.get("volume"))
            virtual_mute = bool(s.get("mute", False))
        continue
    physical_sinks.append({
        "name": name,
        "description": s.get("description") or props.get("node.description") or name,
        "icon": classify_icon(name, props),
        "volume": extract_vol(s.get("volume")),
        "mute": bool(s.get("mute", False)),
        "selected": name in selected_set,
        "state": s.get("state", "IDLE"),
        "isDefault": name == default_sink
    })

print(json.dumps({
    "virtualActive": virtual_active,
    "moduleId": module_id,
    "virtualSinkName": virtual_name,
    "virtualVolume": virtual_volume,
    "virtualMute": virtual_mute,
    "defaultSink": default_sink,
    "sinks": physical_sinks
}))
PY
}

unload_existing() {
  python3 - "$VIRTUAL_SINK_NAME" <<'PY' | while read -r mod_id; do
import json, subprocess, sys
target = sys.argv[1]
mods = json.loads(subprocess.check_output(["pactl", "-f", "json", "list", "modules"], text=True))
for m in mods:
    if m.get("name") == "module-combine-sink" and f"sink_name={target}" in str(m.get("argument", "")):
        print(m["index"])
PY
    pactl unload-module "$mod_id" >/dev/null 2>&1 || true
  done
}

move_streams_to() {
  local target_sink="$1"
  pactl list short sink-inputs 2>/dev/null | awk '{print $1}' | while read -r input_id; do
    [ -n "$input_id" ] && pactl move-sink-input "$input_id" "$target_sink" >/dev/null 2>&1 || true
  done
}

cmd_enable() {
  local slaves="${1:-}"
  if [ -z "$slaves" ]; then
    echo '{"error": "Mindestens zwei Ausgänge auswählen"}' >&2
    exit 1
  fi

  local current_default
  current_default="$(pactl get-default-sink 2>/dev/null || true)"
  if [ -n "$current_default" ] && [ "$current_default" != "$VIRTUAL_SINK_NAME" ]; then
    printf '%s\n' "$current_default" > "$PREV_SINK_FILE"
  fi

  printf '%s\n' "$slaves" > "$SLAVES_FILE"
  unload_existing

  pactl load-module module-combine-sink \
    "sink_name=$VIRTUAL_SINK_NAME" \
    "sink_properties=device.description=\"$VIRTUAL_SINK_DESC\"" \
    "slaves=$slaves" >/dev/null

  pactl set-default-sink "$VIRTUAL_SINK_NAME"
  move_streams_to "$VIRTUAL_SINK_NAME"
  cmd_status
}

cmd_disable() {
  unload_existing
  if [ -f "$PREV_SINK_FILE" ]; then
    local prev
    prev="$(cat "$PREV_SINK_FILE")"
    if [ -n "$prev" ] && pactl list short sinks | awk '{print $2}' | grep -Fxq "$prev"; then
      pactl set-default-sink "$prev" || true
      move_streams_to "$prev"
    fi
  fi
  cmd_status
}

cmd_set_volume() {
  local sink="$1"
  local pct="$2"
  pct="$(python3 -c "print(max(0, min(150, int(float('$pct')))))")"
  pactl set-sink-volume "$sink" "${pct}%"
  cmd_status
}

cmd_toggle_mute() {
  local sink="$1"
  pactl set-sink-mute "$sink" toggle
  cmd_status
}

cmd_set_master_volume() {
  local pct="$1"
  pct="$(python3 -c "print(max(0, min(150, int(float('$pct')))))")"
  local target="$VIRTUAL_SINK_NAME"
  if ! pactl list short sinks | awk '{print $2}' | grep -Fxq "$VIRTUAL_SINK_NAME"; then
    target="@DEFAULT_SINK@"
  fi
  pactl set-sink-volume "$target" "${pct}%"
  cmd_status
}

cmd_toggle_master_mute() {
  local target="$VIRTUAL_SINK_NAME"
  if ! pactl list short sinks | awk '{print $2}' | grep -Fxq "$VIRTUAL_SINK_NAME"; then
    target="@DEFAULT_SINK@"
  fi
  pactl set-sink-mute "$target" toggle
  cmd_status
}

require_cmds

action="${1:-status}"
shift || true

case "$action" in
  status) cmd_status ;;
  enable) cmd_enable "${1:-}" ;;
  disable) cmd_disable ;;
  set-volume) cmd_set_volume "${1:-@DEFAULT_SINK@}" "${2:-100}" ;;
  toggle-mute) cmd_toggle_mute "${1:-@DEFAULT_SINK@}" ;;
  set-master-volume) cmd_set_master_volume "${1:-100}" ;;
  toggle-master-mute) cmd_toggle_master_mute ;;
  *)
    echo "{\"error\": \"Unbekannte Aktion: $action\"}" >&2
    exit 1
    ;;
esac
