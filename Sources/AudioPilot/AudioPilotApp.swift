import SwiftUI

@main
struct AudioPilotApp: App {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var settings    = UserSettings()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(audioManager)
                .environmentObject(settings)
        } label: {
            MenuBarLabel(audioManager: audioManager, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var settings: UserSettings

    var body: some View {
        labelText
            .font(.system(size: 11, weight: .medium))
    }

    private var labelText: Text {
        let inputName  = audioManager.defaultInputDevice.map  { settings.alias(for: $0) } ?? "–"
        let outputName = audioManager.defaultOutputDevice.map { settings.alias(for: $0) } ?? "–"
        return Text("🎤 \(inputName)   🎧 \(outputName)")
    }
}
