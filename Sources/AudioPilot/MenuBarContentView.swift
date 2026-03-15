import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var settings: UserSettings
    @State private var showPresetSheet = false
    @State private var newPresetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("AudioPilot")
                    .font(.headline)
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("AudioPilot beenden")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // ── Volume slider (pinned at top, always visible) ─────
            if audioManager.outputVolumeSettable {
                VolumeSliderView()
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                Divider()
            }

            // ── Sections ──────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    // Input
                    DeviceSectionView(
                        title: "Input",
                        systemImage: "mic.fill",
                        devices: audioManager.inputDevices,
                        selectedDevice: audioManager.defaultInputDevice,
                        isInput: true,
                        onSelect: audioManager.setDefaultInput
                    )

                    Divider()

                    // Output
                    DeviceSectionView(
                        title: "Output",
                        systemImage: "speaker.wave.2.fill",
                        devices: audioManager.outputDevices,
                        selectedDevice: audioManager.defaultOutputDevice,
                        isInput: false,
                        onSelect: audioManager.setDefaultOutput
                    )

                    // Presets
                    if !settings.presets.isEmpty {
                        Divider()
                        PresetsView()
                    }
                }
                .padding(14)
            }

            Divider()

            // ── Footer ────────────────────────────────────────────
            HStack {
                Button {
                    newPresetName = ""
                    showPresetSheet = true
                } label: {
                    Label("Als Preset speichern", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                Spacer()
                Text("AudioPilot · by 4IngoJ")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 290)
        .sheet(isPresented: $showPresetSheet) {
            SavePresetSheet(presetName: $newPresetName, isPresented: $showPresetSheet)
                .environmentObject(audioManager)
                .environmentObject(settings)
        }
    }
}

// MARK: - Volume Slider

struct VolumeSliderView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .foregroundColor(.secondary)
                .imageScale(.small)
                .frame(width: 14)

            Slider(
                value: Binding(
                    get: { audioManager.outputVolume },
                    set: { audioManager.setOutputVolume($0) }
                ),
                in: 0...1
            )
            .tint(.primary)

            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.secondary)
                .imageScale(.small)
                .frame(width: 18)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }
}

// MARK: - Device Section

struct DeviceSectionView: View {
    let title: String
    let systemImage: String
    let devices: [AudioDevice]
    let selectedDevice: AudioDevice?
    let isInput: Bool
    let onSelect: (AudioDevice) -> Void

    @EnvironmentObject var settings: UserSettings
    @State private var expanded = false
    @State private var dropTargetedHide  = false

    private var visibleDevices: [AudioDevice] { settings.orderedVisible(devices, isInput: isInput) }
    private var hiddenDevices:  [AudioDevice] { settings.orderedHidden(devices,  isInput: isInput) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if devices.isEmpty {
                Text("Keine Geräte gefunden")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                // ── Visible devices ───────────────────────────────
                VStack(spacing: 2) {
                    ForEach(visibleDevices) { device in
                        DeviceRowView(
                            device: device,
                            isSelected: selectedDevice?.id == device.id,
                            onSelect: { onSelect(device) },
                            onHide: { settings.toggleHidden(device, isInput: isInput) }
                        )
                    }
                }

                // ── "Weitere Geräte" collapsible section ──────────
                if !hiddenDevices.isEmpty || dropTargetedHide {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                                .foregroundColor(dropTargetedHide ? .accentColor : .secondary)
                            Text("Weitere Geräte (\(hiddenDevices.count))")
                                .font(.caption)
                                .foregroundStyle(dropTargetedHide
                                                 ? AnyShapeStyle(.tint)
                                                 : AnyShapeStyle(.secondary))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(dropTargetedHide
                                      ? Color.accentColor.opacity(0.1)
                                      : Color.primary.opacity(0.04))
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }
                        .dropDestination(for: AudioDevice.self) { items, _ in
                            guard let dropped = items.first,
                                  !settings.isHidden(dropped, isInput: isInput) else { return false }
                            settings.toggleHidden(dropped, isInput: isInput)
                            return true
                        } isTargeted: { dropTargetedHide = $0 }

                        if expanded {
                            VStack(spacing: 2) {
                                ForEach(hiddenDevices) { device in
                                    HiddenDeviceRowView(
                                        device: device,
                                        onUnhide: { settings.toggleHidden(device, isInput: isInput) }
                                    )
                                    .draggable(device)
                                }
                            }
                            .padding(.leading, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - Presets Section

struct PresetsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var settings: UserSettings
    @State private var expandedHidden   = false
    @State private var dropTargetedHide = false

    private var visiblePresets: [AudioPreset] { settings.presets.filter { !settings.isPresetHidden($0) } }
    private var hiddenPresets:  [AudioPreset] { settings.presets.filter {  settings.isPresetHidden($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Presets", systemImage: "bookmark.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // ── Visible presets ────────────────────────────────────
            ForEach(visiblePresets) { preset in
                PresetRowView(preset: preset, onApply: { applyPreset(preset) })
            }

            // ── "Weitere Presets" section ──────────────────────────
            if !hiddenPresets.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: expandedHidden ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(dropTargetedHide ? .accentColor : .secondary)
                        Text("Weitere Presets (\(hiddenPresets.count))")
                            .font(.caption)
                            .foregroundStyle(dropTargetedHide
                                             ? AnyShapeStyle(.tint)
                                             : AnyShapeStyle(.secondary))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(dropTargetedHide
                                  ? Color.accentColor.opacity(0.1)
                                  : Color.primary.opacity(0.04))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expandedHidden.toggle() } }
                    .dropDestination(for: AudioPreset.self) { items, _ in
                        guard let dropped = items.first,
                              !settings.isPresetHidden(dropped) else { return false }
                        settings.togglePresetHidden(dropped)
                        return true
                    } isTargeted: { dropTargetedHide = $0 }

                    if expandedHidden {
                        VStack(spacing: 2) {
                            ForEach(hiddenPresets) { preset in
                                HiddenPresetRowView(preset: preset)
                            }
                        }
                        .padding(.leading, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func applyPreset(_ preset: AudioPreset) {
        if let input = audioManager.inputDevices.first(where: { $0.name == preset.inputDeviceName }) {
            audioManager.setDefaultInput(input)
        }
        if let output = audioManager.outputDevices.first(where: { $0.name == preset.outputDeviceName }) {
            audioManager.setDefaultOutput(output)
        }
    }
}

// MARK: - Preset Row (visible)

struct PresetRowView: View {
    let preset: AudioPreset
    let onApply: () -> Void

    @EnvironmentObject var settings: UserSettings
    @State private var isRenaming = false
    @State private var editText = ""
    @FocusState private var focused: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { if !isRenaming { onApply() } }) {
                Image(systemName: "play.circle")
                    .foregroundStyle(.tint)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            Group {
                if isRenaming {
                    TextField("Name", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($focused)
                        .onSubmit { commitRename() }
                        .onExitCommand { cancelRename() }
                } else {
                    Text(preset.name)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 4) {
                if isRenaming {
                    Button(action: commitRename) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)

                    Button(action: cancelRename) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { settings.togglePresetHidden(preset) }) {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Unter 'Weitere Presets' verschieben")
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)

                    Button(action: startRenaming) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Preset umbenennen")
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)

                    Button(action: { settings.removePreset(id: preset.id) }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)
                }
            }
            .frame(width: 50)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onChange(of: isRenaming) { renaming in
            if renaming {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true }
            }
        }
    }

    private func startRenaming() { editText = preset.name; isRenaming = true }
    private func commitRename() {
        let name = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { settings.renamePreset(id: preset.id, to: name) }
        isRenaming = false
    }
    private func cancelRename() { isRenaming = false }
}

// MARK: - Preset Row (hidden)

struct HiddenPresetRowView: View {
    let preset: AudioPreset
    @EnvironmentObject var settings: UserSettings
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.circle")
                .foregroundColor(.secondary.opacity(0.3))
                .font(.system(size: 14))

            Text(preset.name)
                .font(.system(size: 13))
                .foregroundColor(.primary.opacity(0.45))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { settings.togglePresetHidden(preset) }) {
                Image(systemName: "eye")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Zurück in die Hauptliste")
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .frame(width: 16)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Save Preset Sheet

struct SavePresetSheet: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var settings: UserSettings
    @Binding var presetName: String
    @Binding var isPresented: Bool
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preset speichern")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("z.B. Studio, Podcast, Calls …", text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
            }

            if let input = audioManager.defaultInputDevice,
               let output = audioManager.defaultOutputDevice {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Input:  \(input.name)", systemImage: "mic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("Output: \(output.name)", systemImage: "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Abbrechen") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Speichern") { savePreset() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear { focused = true }
    }

    private func savePreset() {
        guard let input  = audioManager.defaultInputDevice,
              let output = audioManager.defaultOutputDevice else { return }
        let preset = AudioPreset(
            name: presetName.trimmingCharacters(in: .whitespacesAndNewlines),
            inputDeviceName: input.name,
            outputDeviceName: output.name
        )
        settings.addPreset(preset)
        isPresented = false
    }
}
