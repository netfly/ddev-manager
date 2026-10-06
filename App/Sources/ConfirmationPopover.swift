import SwiftUI

/// A small inline confirmation shown as a popover (not `.confirmationDialog`/`.alert`):
/// those render as a separate sheet-style window, which goes stuck/orphaned on screen
/// when the `MenuBarExtra(.window)` panel auto-dismisses itself on a focus change —
/// a popover anchors to the same panel the Log view already uses without that problem.
struct ConfirmationPopover: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button(confirmTitle, role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}
