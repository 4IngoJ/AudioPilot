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
    @State private var dropTargetedHide   = false
    @State private var dropTargetedUnhide = false

    private var visibleDevices: [AudioDevice] {
        devices.filter { !settings.isHidden($0, isInput: isInput) }
    }
    private var hiddenDevices: [AudioDevice] {
        devices.filter { settings.isHidden($0, isInput: isInput) }
    }

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
                // ── Visible devices (drop zone: unhide) ───────────
                VStack(spacing: 2) {
                    ForEach(visibleDevices) { device in
                        DeviceRowView(
                            device: device,
                            isSelected: selectedDevice?.id == device.id,
                            onSelect: { onSelect(device) },
                            onHide: { settings.toggleHidden(device, isInput: isInput) }
                        )
                        .onDrag { NSItemProvider(object: device.name as NSString) }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            dropTargetedUnhide ? Color.accentColor.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )
                .onDrop(of: [.text], isTargeted: $dropTargetedUnhide) { providers in
                    handleDrop(providers, hide: false)
                }

                // ── "Weitere Geräte" expandable section ───────────
                if !hiddenDevices.isEmpty || dropTargetedHide {
                    VStack(alignment: .leading, spacing: 4) {
                        // Header / drop zone for hiding
                        HStack(spacing: 4) {
                            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                                .foregroundColor(dropTargetedHide ? .accentColor : .secondary)
                            Text("Weitere Geräte (\(hiddenDevices.count))")
                                .font(.caption)
                                .foregroundStyle(dropTargetedHide ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
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
                            handleDrop(providers, hide: true)
                        }

                        // Hidden device rows
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

    private func handleDrop(_ providers: [NSItemProvider], hide: Bool) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let name = item as? String,
                  let device = devices.first(where: { $0.name == name }) else { return }
            let currentlyHidden = settings.isHidden(device, isInput: isInput)
            DispatchQueue.main.async {
                if hide && !currentlyHidden { settings.toggleHidden(device, isInput: isInput) }
                else if !hide && currentlyHidden { settings.toggleHidden(device, isInput: isInput) }
            }
        }
        return true
    }
}

// MARK: - Presets Section

struct PresetsView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Presets", systemImage: "bookmark.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(settings.presets) { preset in
                HStack {
                    Button { applyPreset(preset) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle")
                                .foregroundStyle(.tint)
                            Text(preset.name)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    Button { settings.removePreset(id: preset.id) } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
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
