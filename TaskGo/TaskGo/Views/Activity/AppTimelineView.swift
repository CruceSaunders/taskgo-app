import SwiftUI

struct AppTimelineView: View {
    let segments: [TimelineSegment]

    @State private var hoveredSegment: TimelineSegment?
    @State private var hoverLocation: CGPoint = .zero

    private let timelineHeight: CGFloat = 32
    private let totalMinutes: CGFloat = 1440

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("App Timeline")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)

            if segments.isEmpty {
                emptyState
            } else {
                timelineBar
                timeLabels
            }
        }
    }

    private var timelineBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.06))

                ForEach(segments) { seg in
                    let startX = CGFloat(seg.startMinute) / totalMinutes * width
                    let segWidth = max(1, CGFloat(seg.endMinute - seg.startMinute) / totalMinutes * width)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForScore(seg.productivityScore))
                        .frame(width: segWidth, height: timelineHeight - 4)
                        .offset(x: startX)
                        .onHover { isHovering in
                            if isHovering {
                                hoveredSegment = seg
                            } else if hoveredSegment?.id == seg.id {
                                hoveredSegment = nil
                            }
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if let seg = hoveredSegment {
                    tooltipView(for: seg)
                        .offset(y: timelineHeight + 4)
                }
            }
        }
        .frame(height: timelineHeight)
    }

    private var timeLabels: some View {
        HStack {
            Text("12 AM")
            Spacer()
            Text("6 AM")
            Spacer()
            Text("12 PM")
            Spacer()
            Text("6 PM")
            Spacer()
            Text("12 AM")
        }
        .font(.system(size: 7))
        .foregroundStyle(.secondary.opacity(0.6))
    }

    private func tooltipView(for seg: TimelineSegment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(seg.appName)
                .font(.system(size: 10, weight: .semibold))
            if !seg.windowTitle.isEmpty {
                Text(seg.windowTitle)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                Text(seg.category)
                    .font(.system(size: 8))
                    .foregroundStyle(colorForScore(seg.productivityScore))
                Text("·")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text(formatDuration(seg.endMinute - seg.startMinute))
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .cornerRadius(6)
        .shadow(radius: 2)
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.06))
            .frame(height: timelineHeight)
            .overlay(
                Text("No app data yet")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary.opacity(0.4))
            )
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

func colorForScore(_ score: Int) -> Color {
    switch score {
    case -2: return .red
    case -1: return .orange
    case 0: return .gray
    case 1: return .blue
    case 2: return .green
    default: return .gray
    }
}
