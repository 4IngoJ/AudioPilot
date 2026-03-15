import Foundation

class UserSettings: ObservableObject {
    @Published var deviceAliases: [String: String] = [:]
    @Published var presets: [AudioPreset] = []
    @Published var hiddenPresetIds: Set<UUID> = []
    @Published var hiddenInputDeviceNames:  Set<String> = []
    @Published var hiddenOutputDeviceNames: Set<String> = []
    @Published var inputDeviceOrder:  [String] = []
    @Published var outputDeviceOrder: [String] = []

    private let aliasesKey       = "com.audiopilot.deviceAliases"
    private let presetsKey       = "com.audiopilot.presets"
    private let hiddenInputKey   = "com.audiopilot.hiddenInputDevices"
    private let hiddenOutputKey  = "com.audiopilot.hiddenOutputDevices"
    private let hiddenPresetsKey = "com.audiopilot.hiddenPresets"
    private let inputOrderKey    = "com.audiopilot.inputDeviceOrder"
    private let outputOrderKey   = "com.audiopilot.outputDeviceOrder"

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
        if let arr = UserDefaults.standard.stringArray(forKey: hiddenPresetsKey) {
            hiddenPresetIds = Set(arr.compactMap { UUID(uuidString: $0) })
        }
        if let arr = UserDefaults.standard.stringArray(forKey: inputOrderKey) {
            inputDeviceOrder = arr
        }
        if let arr = UserDefaults.standard.stringArray(forKey: outputOrderKey) {
            outputDeviceOrder = arr
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

    // MARK: - Device display order

    /// Visible devices in the user's preferred order.
    func orderedVisible(_ devices: [AudioDevice], isInput: Bool) -> [AudioDevice] {
        let stored = isInput ? inputDeviceOrder : outputDeviceOrder
        let visible = devices.filter { !isHidden($0, isInput: isInput) }
        guard !stored.isEmpty else { return visible }
        var result = stored.compactMap { name in visible.first { $0.name == name } }
        let known = Set(result.map(\.name))
        result += visible.filter { !known.contains($0.name) }
        return result
    }

    /// Hidden devices in the user's preferred order.
    func orderedHidden(_ devices: [AudioDevice], isInput: Bool) -> [AudioDevice] {
        let stored = isInput ? inputDeviceOrder : outputDeviceOrder
        let hidden = devices.filter { isHidden($0, isInput: isInput) }
        guard !stored.isEmpty else { return hidden }
        var result = stored.compactMap { name in hidden.first { $0.name == name } }
        let known = Set(result.map(\.name))
        result += hidden.filter { !known.contains($0.name) }
        return result
    }

    func moveDevice(named name: String, before targetName: String, isInput: Bool, allDevices: [AudioDevice]) {
        var order = fullOrder(isInput: isInput, allDevices: allDevices)
        guard let from = order.firstIndex(of: name),
              let to   = order.firstIndex(of: targetName) else { return }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        if isInput {
            inputDeviceOrder = order
            UserDefaults.standard.set(order, forKey: inputOrderKey)
        } else {
            outputDeviceOrder = order
            UserDefaults.standard.set(order, forKey: outputOrderKey)
        }
    }

    private func fullOrder(isInput: Bool, allDevices: [AudioDevice]) -> [String] {
        let stored   = isInput ? inputDeviceOrder : outputDeviceOrder
        let allNames = allDevices.map(\.name)
        return stored.filter { allNames.contains($0) } + allNames.filter { !stored.contains($0) }
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
        hiddenPresetIds.remove(id)
        savePresets()
        saveHiddenPresets()
    }

    func renamePreset(id: UUID, to name: String) {
        guard let idx = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[idx].name = name
        savePresets()
    }

    func movePresets(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        savePresets()
    }

    // MARK: - Hidden presets

    func isPresetHidden(_ preset: AudioPreset) -> Bool {
        hiddenPresetIds.contains(preset.id)
    }

    func togglePresetHidden(_ preset: AudioPreset) {
        if hiddenPresetIds.contains(preset.id) { hiddenPresetIds.remove(preset.id) }
        else { hiddenPresetIds.insert(preset.id) }
        saveHiddenPresets()
    }

    // MARK: - Persistence helpers

    func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    private func saveHiddenPresets() {
        UserDefaults.standard.set(hiddenPresetIds.map(\.uuidString), forKey: hiddenPresetsKey)
    }
}

struct AudioPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var inputDeviceName: String
    var outputDeviceName: String
}
