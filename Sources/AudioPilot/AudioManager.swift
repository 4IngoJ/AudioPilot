import CoreAudio
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// kAudioHardwareServiceDeviceProperty_VirtualMasterVolume = 'vmvc'
private let kVirtualMasterVolume: AudioObjectPropertySelector = 0x766D7663

struct AudioDevice: Identifiable, Equatable, Hashable, Codable {
    let id: AudioObjectID
    let name: String
    let hasInput: Bool
    let hasOutput: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool { lhs.id == rhs.id }
}

class AudioManager: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var outputDevices: [AudioDevice] = []
    @Published var defaultInputDevice: AudioDevice?
    @Published var defaultOutputDevice: AudioDevice?
    @Published var outputVolume: Float = 1.0
    @Published var outputVolumeSettable: Bool = false

    init() {
        refresh()
        setupSystemListeners()
    }

    // MARK: - Public

    func refresh() {
        let devices = getAllDevices()
        DispatchQueue.main.async {
            self.inputDevices  = devices.filter { $0.hasInput }
            self.outputDevices = devices.filter { $0.hasOutput }
            self.defaultInputDevice  = self.getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
            self.defaultOutputDevice = self.getDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
            self.refreshVolume()
        }
    }

    func setDefaultInput(_ device: AudioDevice) {
        setDefault(deviceID: device.id, selector: kAudioHardwarePropertyDefaultInputDevice)
        DispatchQueue.main.async { self.defaultInputDevice = device }
    }

    func setDefaultOutput(_ device: AudioDevice) {
        setDefault(deviceID: device.id, selector: kAudioHardwarePropertyDefaultOutputDevice)
        DispatchQueue.main.async {
            self.defaultOutputDevice = device
            self.refreshVolume()
        }
    }

    func setOutputVolume(_ value: Float) {
        guard let id = defaultOutputDevice?.id else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kVirtualMasterVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        var vol = Float32(max(0, min(1, value)))
        AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
        outputVolume = Float(vol)
    }

    // MARK: - Volume helpers

    func refreshVolume() {
        guard let id = defaultOutputDevice?.id else {
            outputVolumeSettable = false
            return
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kVirtualMasterVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        guard AudioObjectHasProperty(id, &address) else {
            outputVolumeSettable = false
            return
        }
        var isSettable: DarwinBoolean = false
        AudioObjectIsPropertySettable(id, &address, &isSettable)
        outputVolumeSettable = isSettable.boolValue

        var vol: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(id, &address, 0, nil, &size, &vol) == noErr {
            outputVolume = Float(vol)
        }
        setupVolumeListener(for: id)
    }

    private func setupVolumeListener(for deviceID: AudioObjectID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kVirtualMasterVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return }
        AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main) { [weak self] _, _ in
            guard let self, self.defaultOutputDevice?.id == deviceID else { return }
            var addr = AudioObjectPropertyAddress(
                mSelector: kVirtualMasterVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 0
            )
            var vol: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol) == noErr {
                self.outputVolume = Float(vol)
            }
        }
    }

    // MARK: - CoreAudio internals

    private func getAllDevices() -> [AudioDevice] {
        let systemID = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemID, &address, 0, nil, &dataSize) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemID, &address, 0, nil, &dataSize, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            guard let name = deviceName(id) else { return nil }
            let hasIn  = hasStreams(id, scope: kAudioObjectPropertyScopeInput)
            let hasOut = hasStreams(id, scope: kAudioObjectPropertyScopeOutput)
            guard hasIn || hasOut else { return nil }
            return AudioDevice(id: id, name: name, hasInput: hasIn, hasOutput: hasOut)
        }
    }

    private func deviceName(_ id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var nameRef: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &nameRef) { ptr in
            ptr.withMemoryRebound(to: UnsafeMutableRawPointer?.self, capacity: 1) {
                AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
            }
        }
        guard status == noErr, let nameRef else { return nil }
        return nameRef.takeRetainedValue() as String
    }

    private func hasStreams(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: 0
        )
        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        return size > 0
    }

    private func getDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDevice? {
        let systemID = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var deviceID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(systemID, &address, 0, nil, &size, &deviceID) == noErr else { return nil }
        return getAllDevices().first { $0.id == deviceID }
    }

    private func setDefault(deviceID: AudioObjectID, selector: AudioObjectPropertySelector) {
        let systemID = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        var mutableID = deviceID
        AudioObjectSetPropertyData(systemID, &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &mutableID)
    }

    private func setupSystemListeners() {
        let systemID = AudioObjectID(kAudioObjectSystemObject)

        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        AudioObjectAddPropertyListenerBlock(systemID, &devicesAddr, DispatchQueue.main) { [weak self] _, _ in
            self?.refresh()
        }

        var inputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        AudioObjectAddPropertyListenerBlock(systemID, &inputAddr, DispatchQueue.main) { [weak self] _, _ in
            guard let self else { return }
            self.defaultInputDevice = self.getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        }

        var outputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        AudioObjectAddPropertyListenerBlock(systemID, &outputAddr, DispatchQueue.main) { [weak self] _, _ in
            guard let self else { return }
            self.defaultOutputDevice = self.getDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
            self.refreshVolume()
        }
    }
}

// MARK: - Transferable (for drag & drop)

extension UTType {
    static let audioDevice = UTType(exportedAs: "com.audiopilot.audiodevice")
}

extension AudioDevice: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .audioDevice)
    }
}
