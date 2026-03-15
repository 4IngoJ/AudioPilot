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

/// NSViewRepresentable wrapping a custom NSView that draws an NSAttributedString
/// containing SF Symbol image attachments + text.
/// NSTextField clips its content when the status item button has a constrained width;
/// a hand-drawn view with explicit intrinsicContentSize solves that reliably.
struct MenuBarLabel: NSViewRepresentable {
    @ObservedObject var audioManager: AudioManager
    @ObservedObject var settings: UserSettings

    func makeNSView(context: Context) -> StatusLabelView {
        let view = StatusLabelView()
        view.update(with: buildAttributedString())
        return view
    }

    func updateNSView(_ view: StatusLabelView, context: Context) {
        view.update(with: buildAttributedString())
    }

    // Tell SwiftUI exactly how wide this label needs to be
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: StatusLabelView,
                      context: Context) -> CGSize? {
        let s = nsView.attributedString.size()
        return CGSize(width: ceil(s.width) + 4, height: max(ceil(s.height) + 2, 18))
    }

    // MARK: - Attributed string

    private func buildAttributedString() -> NSAttributedString {
        let font     = NSFont.systemFont(ofSize: 12, weight: .medium)
        let textAttr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        let str      = NSMutableAttributedString()
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

// MARK: - Custom label view

/// Draws an NSAttributedString directly, bypassing NSTextField's internal
/// layout constraints that clip long attributed strings in status items.
final class StatusLabelView: NSView {
    private(set) var attributedString = NSAttributedString()

    func update(with str: NSAttributedString) {
        attributedString = str
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        let s = attributedString.size()
        return NSSize(width: ceil(s.width) + 4, height: ceil(s.height) + 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let s = attributedString.size()
        let y = (bounds.height - s.height) / 2
        attributedString.draw(at: NSPoint(x: 2, y: y))
    }
}
