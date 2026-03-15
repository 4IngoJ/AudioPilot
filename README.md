# AudioPilot 🎙️🎧

A lightweight macOS menu bar app for switching audio input and output devices in one click — without ever opening System Settings.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Menu bar at a glance** — active mic and headphone device always visible
- **One-click switching** — instantly set any input or output device as default
- **Volume slider** — control system output volume right from the popover
- **Custom aliases** — rename long device names to something short (e.g. "Wave XLR" → "Podcast")
- **Presets** — save input + output combinations and recall them with a single click
- **Live updates** — detects newly connected or disconnected devices automatically
- **No Dock icon** — lives quietly in the menu bar, out of the way

---

## Download

**[⬇️ Download AudioPilot v1.0.0](../../releases/latest)**

Open the `.dmg`, drag **AudioPilot** into your Applications folder, then:

> **First launch:** Right-click → **Open** to bypass Gatekeeper (required for apps without an Apple Developer certificate).

---

## Usage

| Action | How |
|---|---|
| Switch input device | Click menu bar icon → click any mic in the Input list |
| Switch output device | Click menu bar icon → click any speaker in the Output list |
| Adjust volume | Drag the slider at the top of the popover |
| Rename a device | Click the ✏️ pencil icon next to any device name |
| Save a preset | Click **"Als Preset speichern"** at the bottom of the popover |
| Apply a preset | Click the ▶ play icon next to a saved preset |
| Delete a preset | Click the 🗑 trash icon next to a preset |
| Quit | Click the power icon in the header |

---

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

---

## Build from Source

You need **Xcode Command Line Tools** (`xcode-select --install`).

```bash
git clone https://github.com/4IngoJ/AudioPilot.git
cd AudioPilot
bash build.sh        # → AudioPilot.app
```

To also create a distributable DMG:

```bash
bash dist.sh         # → AudioPilot.dmg
```

The app is signed with an **ad-hoc signature** — no Apple Developer account needed for personal/local use.

---

## Project Structure

```
AudioPilot/
├── Sources/AudioPilot/
│   ├── AudioPilotApp.swift        # App entry point, menu bar label
│   ├── AudioManager.swift         # CoreAudio wrapper (devices, volume, listeners)
│   ├── MenuBarContentView.swift   # Popover UI (volume, device lists, presets)
│   ├── DeviceRowView.swift        # Single device row with inline rename
│   └── UserSettings.swift         # Aliases & presets (UserDefaults persistence)
├── Package.swift                  # Swift Package Manager config
├── build.sh                       # Compile + bundle script
└── dist.sh                        # Build + DMG packaging script
```

---

## How it works

AudioPilot talks directly to **CoreAudio** via `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData`. It registers property listeners so the UI updates instantly when:
- A device is plugged in or unplugged
- Another app changes the default input/output
- The system volume changes

No third-party dependencies. Pure Swift + SwiftUI + CoreAudio.

---

## License

MIT — do whatever you want with it.
