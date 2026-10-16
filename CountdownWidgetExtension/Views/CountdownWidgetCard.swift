import CountdownShared
import SwiftUI
import WidgetKit

public struct CountdownWidgetCard: View {
    public let snapshot: CountdownSnapshot
    public let family: WidgetFamily
    public let displayPrecision: CountdownDisplayPrecision

    public init(
        snapshot: CountdownSnapshot,
        family: WidgetFamily,
        displayPrecision: CountdownDisplayPrecision = .automatic
    ) {
        self.snapshot = snapshot
        self.family = family
        self.displayPrecision = displayPrecision
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        case .systemLarge, .systemExtraLarge:
            largeLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Spacer(minLength: 4)
            liveTimeText
                .font(timeFont)
                .minimumScaleFactor(0.65)
                .lineLimit(timeLineLimit)
            finishedStatusLine
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            CountdownWidgetRing(progress: snapshot.progress, color: accentColor)
                .frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 8) {
                header
                liveTimeText
                    .font(timeFont)
                    .minimumScaleFactor(0.7)
                    .lineLimit(timeLineLimit)
                finishedStatusLine
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                header
                Spacer()
                CountdownWidgetRing(progress: snapshot.progress, color: accentColor)
                    .frame(width: 72, height: 72)
            }

            liveTimeText
                .font(timeFont)
                .minimumScaleFactor(0.6)
                .lineLimit(timeLineLimit)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                finishedStatusLine
                Text(snapshot.targetDate, style: .date)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(snapshot.targetDate, style: .time)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        Label {
            Text(snapshot.title)
                .font(.headline)
                .lineLimit(2)
        } icon: {
            Image(systemName: snapshot.symbolName)
                .foregroundStyle(accentColor)
        }
        .accessibilityLabel(snapshot.title)
    }

    @ViewBuilder
    private var liveTimeText: some View {
        Text(CountdownFormatter.string(
            remainingSeconds: snapshot.remainingSeconds,
            precision: displayPrecision
        ))
        .monospacedDigit()
    }

    @ViewBuilder
    private var finishedStatusLine: some View {
        if snapshot.status == .expired {
            Text("Finished")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(CountdownFormatter.accessibilityString(
                    remainingSeconds: snapshot.remainingSeconds,
                    status: snapshot.status
                ))
        }
    }

    private var accentColor: Color {
        switch snapshot.colorName {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        case "gray": .gray
        default: .blue
        }
    }

    private var timeFont: Font {
        if displayPrecision == .full {
            switch family {
            case .systemSmall:
                return .system(size: 15, weight: .semibold, design: .rounded)
            case .systemMedium:
                return .system(size: 20, weight: .semibold, design: .rounded)
            default:
                return .system(size: 28, weight: .semibold, design: .rounded)
            }
        }

        switch family {
        case .systemSmall:
            return .system(size: 26, weight: .semibold, design: .rounded)
        case .systemMedium:
            return .system(size: 30, weight: .semibold, design: .rounded)
        default:
            return .system(size: 44, weight: .semibold, design: .rounded)
        }
    }

    private var timeLineLimit: Int {
        displayPrecision == .full ? 4 : 1
    }
}

private struct CountdownWidgetRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.16), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption.bold())
                .monospacedDigit()
        }
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
