import SwiftUI

struct DeviceRowView: View {
    let device: AudioDevice
    let isSelected: Bool
    let onSelect: () -> Void

    @EnvironmentObject var settings: UserSettings
    @State private var isRenaming = false
    @State private var editText = ""
    @FocusState private var textFocused: Bool

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

            // ── Action buttons ─────────────────────────────────────
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
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        // Set focus once TextField is in the view hierarchy
        .onChange(of: isRenaming) { renaming in
            if renaming {
                // Short delay ensures TextField is rendered before requesting focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textFocused = true
                }
            }
        }
    }

    // MARK: - Rename helpers

    private func startRenaming() {
        editText = settings.alias(for: device)
        isRenaming = true
    }

    private func commitRename() {
        settings.setAlias(editText, for: device)
        isRenaming = false
    }

    private func cancelRename() {
        isRenaming = false
    }
}
