import SwiftUI
import AppKit

struct DetailHeaderView: View {
    let title: String
    let subtitle: String
    let status: String
    let isRunning: Bool
    var isTransitioning = false
    var badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                                .fixedSize()
                        }
                    }

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                StatusBadge(status: status, isRunning: isRunning, isTransitioning: isTransitioning)
                    .fixedSize()
                    .layoutPriority(0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .textSelection(.enabled)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct KeyValueGrid: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                DetailRow(label: row.0, value: row.1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VerticalPanelResizeHandle: View {
    @Binding var height: CGFloat
    let maxHeight: CGFloat

    @State private var dragStartHeight: CGFloat?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.04))

            Capsule()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 52, height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartHeight == nil {
                        dragStartHeight = height
                    }
                    let base = dragStartHeight ?? height
                    let proposed = base - value.translation.height
                    height = AppSettings.clampWorkspacePanelHeight(proposed, maxHeight: maxHeight)
                }
                .onEnded { _ in
                    dragStartHeight = nil
                }
        )
        .accessibilityLabel("Resize panel")
    }
}

struct StatusBadge: View {
    let status: String
    let isRunning: Bool
    var isTransitioning = false

    var body: some View {
        Text(status.capitalized)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        if isTransitioning { return Color.yellow.opacity(0.2) }
        return isRunning ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)
    }

    private var foregroundColor: Color {
        if isTransitioning { return .yellow }
        return isRunning ? .green : .orange
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(subtitle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ToolbarRefreshButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(isLoading)
    }
}

struct InlineErrorView: View {
    let message: String
    var terminalCommand: String?

    var body: some View {
        FormErrorBanner(message: message, terminalCommand: terminalCommand)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}
