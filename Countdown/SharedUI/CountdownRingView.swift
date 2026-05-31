import SwiftUI

struct CountdownRingView: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var accentColor: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.35), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Countdown progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

extension String {
    var countdownColor: Color {
        switch self {
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
}
