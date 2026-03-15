import SwiftUI

// MARK: - Visible device row

struct DeviceRowView: View {
    let device: AudioDevice
    let isSelected: Bool
    let onSelect: () -> Void
    let onHide: () -> Void

    @EnvironmentObject var settings: UserSettings
    @State private var isRenaming = false
    @State private var editText = ""
    @FocusState private var textFocused: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // ── Selection indicator ────────────────────────────────
            Button(action: { if !isRenaming { onSelect() } }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            // ── Name / rename field ────────────────────────────────
            Group {
                if isRenaming {
                    TextField("Name", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($textFocused)
                        .onSubmit { commitRename() }
                        .onExitCommand { cancelRename() }
                } else {
                    Text(settings.alias(for: device))
                        .font(.system(size: 13))
                        .foregroundColor(.primary.opacity(0.9))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect() }
                }
            }
            .frame(maxWidth: .infinity)

            // ── Right action group (fixed width, no layout jumps) ──
            HStack(spacing: 4) {
                // Drag handle: only visible on hover
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(width: 14)
                    .opacity(isHovered ? 1 : 0)

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
                    Button(action: startRenaming) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Gerät umbenennen")
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)

                    Button(action: onHide) {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Unter 'Weitere Geräte' verschieben")
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)
                }
            }
            .frame(width: 52)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.12)
                        : isHovered ? Color.primary.opacity(0.06) : Color.clear
                )
        )
        .contentShape(Rectangle())   // full-line hover detection
        .onHover { isHovered = $0 }
        .onChange(of: isRenaming) { renaming in
            if renaming {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { textFocused = true }
            }
        }
    }

    private func startRenaming() { editText = settings.alias(for: device); isRenaming = true }
    private func commitRename()  { settings.setAlias(editText, for: device); isRenaming = false }
    private func cancelRename()  { isRenaming = false }
}

// MARK: - Hidden device row

struct HiddenDeviceRowView: View {
    let device: AudioDevice
    let onUnhide: () -> Void

    @EnvironmentObject var settings: UserSettings
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle")
                .foregroundColor(.secondary.opacity(0.3))
                .frame(width: 16)

            Text(settings.alias(for: device))
                .font(.system(size: 13))
                .foregroundColor(.primary.opacity(0.45))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(isHovered ? 0.55 : 0.18))
                    .frame(width: 14)

                Button(action: onUnhide) {
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
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
