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
    @State private var dropTargetDevice: AudioDevice?

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
                        .overlay(alignment: .top) {
                            if dropTargetDevice?.id == device.id {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.accentColor)
                                    .frame(height: 2)
                                    .padding(.horizontal, 6)
                            }
                        }
                        .onDrag { NSItemProvider(object: device.name as NSString) }
                        .onDrop(of: [.text],
                                isTargeted: Binding(
                                    get: { dropTargetDevice?.id == device.id },
                                    set: { dropTargetDevice = $0 ? device : nil }
                                )) { providers in
                            handleRowDrop(providers, onto: device)
                        }
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
                        .onDrop(of: [.text], isTargeted: $dropTargetedHide) { providers in
                            handleHideDrop(providers)
                        }

                        if expanded {
                            VStack(spacing: 2) {
                                ForEach(hiddenDevices) { device in
                                    HiddenDeviceRowView(
                                        device: device,
                                        onUnhide: { settings.toggleHidden(device, isInput: isInput) }
                                    )
                                    .onDrag { NSItemProvider(object: device.name as NSString) }
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

    // Drop onto a visible row → reorder (+ unhide if needed)
    private func handleRowDrop(_ providers: [NSItemProvider], onto target: AudioDevice) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let name = item as? String else { return }
            DispatchQueue.main.async {
                if let device = devices.first(where: { $0.name == name }),
                   settings.isHidden(device, isInput: isInput) {
                    settings.toggleHidden(device, isInput: isInput)
                }
                settings.moveDevice(named: name, before: target.name,
                                    isInput: isInput, allDevices: devices)
                dropTargetDevice = nil
            }
        }
        return true
    }

    // Drop onto "Weitere Geräte" header → hide
    private func handleHideDrop(_ providers: [NSItemProvider]) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let name = item as? String,
                  let device = devices.first(where: { $0.name == name }) else { return }
            DispatchQueue.main.async {
                if !settings.isHidden(device, isInput: isInput) {
                    settings.toggleHidden(device, isInput: isInput)
                }
            }
        }
        return true
    }
}

// MARK: - Presets Section

struct PresetsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var settings: UserSettings
    @State private var expandedHidden   = false
    @State private var dropTargetedHide = false
    @State private var dropTargetPreset: AudioPreset?

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
                    .overlay(alignment: .top) {
                        if dropTargetPreset?.id == preset.id {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.accentColor)
                                .frame(height: 2)
                                .padding(.horizontal, 6)
                        }
                    }
                    .onDrag { NSItemProvider(object: preset.id.uuidString as NSString) }
                    .onDrop(of: [.text],
                            isTargeted: Binding(
                                get: { dropTargetPreset?.id == preset.id },
                                set: { dropTargetPreset = $0 ? preset : nil }
                            )) { providers in
                        handlePresetRowDrop(providers, onto: preset)
                    }
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
                    .onDrop(of: [.text], isTargeted: $dropTargetedHide) { providers in
                        handlePresetHideDrop(providers)
                    }

                    if expandedHidden {
                        VStack(spacing: 2) {
                            ForEach(hiddenPresets) { preset in
                                HiddenPresetRowView(preset: preset)
                                    .onDrag { NSItemProvider(object: preset.id.uuidString as NSString) }
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

    private func handlePresetRowDrop(_ providers: [NSItemProvider], onto target: AudioPreset) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let idStr = item as? String, let id = UUID(uuidString: idStr) else { return }
            DispatchQueue.main.async {
                guard let from = settings.presets.firstIndex(where: { $0.id == id }),
                      let to   = settings.presets.firstIndex(where: { $0.id == target.id }) else { return }
                if let preset = settings.presets.first(where: { $0.id == id }),
                   settings.isPresetHidden(preset) {
                    settings.togglePresetHidden(preset)
                }
                settings.movePresets(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
                dropTargetPreset = nil
            }
        }
        return true
    }

    private func handlePresetHideDrop(_ providers: [NSItemProvider]) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let idStr = item as? String, let id = UUID(uuidString: idStr) else { return }
            DispatchQueue.main.async {
                if let preset = settings.presets.first(where: { $0.id == id }),
                   !settings.isPresetHidden(preset) {
                    settings.togglePresetHidden(preset)
                }
            }
        }
        return true
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
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(isHovered ? 0.55 : 0.18))
                    .frame(width: 14)

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
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 64)
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

            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(isHovered ? 0.55 : 0.18))
                    .frame(width: 14)

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
            .frame(width: 34)
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
