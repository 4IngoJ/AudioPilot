import Foundation

class UserSettings: ObservableObject {
    @Published var deviceAliases: [String: String] = [:]
    @Published var presets: [AudioPreset] = []
    @Published var hiddenInputDeviceNames:  Set<String> = []
    @Published var hiddenOutputDeviceNames: Set<String> = []

    private let aliasesKey      = "com.audiopilot.deviceAliases"
    private let presetsKey      = "com.audiopilot.presets"
    private let hiddenInputKey  = "com.audiopilot.hiddenInputDevices"
    private let hiddenOutputKey = "com.audiopilot.hiddenOutputDevices"

    init() {
        if let stored = UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String] {
            deviceAliases = stored
        }
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([AudioPreset].self, from: data) {
            presets = decoded
        }
        if let arr = UserDefaults.standard.stringArray(forKey: hiddenInputKey) {
            hiddenInputDeviceNames = Set(arr)
        }
        if let arr = UserDefaults.standard.stringArray(forKey: hiddenOutputKey) {
            hiddenOutputDeviceNames = Set(arr)
        }
    }

    // MARK: - Hidden devices

    func isHidden(_ device: AudioDevice, isInput: Bool) -> Bool {
        isInput ? hiddenInputDeviceNames.contains(device.name)
                : hiddenOutputDeviceNames.contains(device.name)
    }

    func toggleHidden(_ device: AudioDevice, isInput: Bool) {
        if isInput {
            if hiddenInputDeviceNames.contains(device.name) { hiddenInputDeviceNames.remove(device.name) }
            else { hiddenInputDeviceNames.insert(device.name) }
            UserDefaults.standard.set(Array(hiddenInputDeviceNames), forKey: hiddenInputKey)
        } else {
            if hiddenOutputDeviceNames.contains(device.name) { hiddenOutputDeviceNames.remove(device.name) }
            else { hiddenOutputDeviceNames.insert(device.name) }
            UserDefaults.standard.set(Array(hiddenOutputDeviceNames), forKey: hiddenOutputKey)
        }
    }

    // MARK: - Aliases

    func alias(for device: AudioDevice) -> String {
        deviceAliases[device.name] ?? device.name
    }

    func setAlias(_ alias: String, for device: AudioDevice) {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == device.name {
            deviceAliases.removeValue(forKey: device.name)
        } else {
            deviceAliases[device.name] = trimmed
        }
        UserDefaults.standard.set(deviceAliases, forKey: aliasesKey)
    }

    // MARK: - Presets

    func addPreset(_ preset: AudioPreset) {
        presets.append(preset)
        savePresets()
    }

    func removePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        savePresets()
    }

    func removePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        savePresets()
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }
}

struct AudioPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var inputDeviceName: String
    var outputDeviceName: String
}
