import SwiftUI
import AppKit

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

// MARK: - Menu Bar Label

/// NSViewRepresentable using NSTextField with an NSAttributedString that embeds
/// SF Symbol image attachments. sizeThatFits + explicit frame prevents the label
/// from being clipped by the status item button's automatic width calculation.
struct MenuBarLabel: NSViewRepresentable {
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var settings: UserSettings

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.isBezeled        = false
        tf.drawsBackground  = false
        tf.isEditable       = false
        tf.isSelectable     = false
        tf.cell?.isScrollable = false
        tf.cell?.wraps        = false
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        let attr = buildAttributedString()
        tf.attributedStringValue = attr
        // Set the frame explicitly so the full string is never clipped
        let s = attr.size()
        tf.frame = CGRect(x: 0, y: 0, width: ceil(s.width) + 6, height: max(ceil(s.height), 18))
    }

    // Tell SwiftUI the exact size this view needs → prevents compression
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: NSTextField,
                      context: Context) -> CGSize? {
        let s = nsView.attributedStringValue.size()
        return CGSize(width: ceil(s.width) + 6, height: max(ceil(s.height), 18))
    }

    // MARK: - Attributed string

    private func buildAttributedString() -> NSAttributedString {
        let font     = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textAttr: [NSAttributedString.Key: Any] = [
            .font:            font,
            .foregroundColor: NSColor.labelColor
        ]

        let str        = NSMutableAttributedString()
        let inputName  = audioManager.defaultInputDevice.map  { settings.alias(for: $0) } ?? "–"
        let outputName = audioManager.defaultOutputDevice.map { settings.alias(for: $0) } ?? "–"

        str.append(symbolAttachment("mic.fill",   size: 11.5))
        str.append(NSAttributedString(string: " \(inputName)   ", attributes: textAttr))
        str.append(symbolAttachment("headphones", size: 12))
        str.append(NSAttributedString(string: " \(outputName)", attributes: textAttr))
        return str
    }

    private func symbolAttachment(_ name: String, size: CGFloat) -> NSAttributedString {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return NSAttributedString()
        }
        let cfg        = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        let attachment = NSTextAttachment()
        attachment.image  = img.withSymbolConfiguration(cfg)
        attachment.bounds = CGRect(x: 0, y: -2, width: size, height: size)
        return NSAttributedString(attachment: attachment)
    }
}
