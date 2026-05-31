import CountdownShared
import SwiftUI
import WidgetKit
import XCTest

@MainActor
final class CountdownWidgetSnapshotTests: XCTestCase {
    func testSmallMediumAndLargeWidgetCardsRender() throws {
        for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge] {
            let renderer = ImageRenderer(content: CountdownWidgetCard(snapshot: sampleSnapshot, family: family)
                .padding()
                .frame(width: width(for: family), height: height(for: family)))
            renderer.scale = 2
            let image = renderer.nsImage

            XCTAssertNotNil(image)
            XCTAssertGreaterThan(image?.size.width ?? 0, 0)
            XCTAssertGreaterThan(image?.size.height ?? 0, 0)
        }
    }

    private var sampleSnapshot: CountdownSnapshot {
        let now = Date(timeIntervalSinceReferenceDate: 40_000)
        let target = now.addingTimeInterval(3_600)
        return CountdownSnapshot(
            id: UUID(),
            title: "Snapshot",
            createdAt: now,
            updatedAt: now,
            targetDate: target,
            originalTargetDate: target,
            quickDurationSeconds: nil,
            pausedRemainingSeconds: nil,
            completedAt: nil,
            notificationIdentifier: nil,
            colorName: "purple",
            symbolName: "timer",
            remainingSeconds: 3_600,
            originalDurationSeconds: 7_200,
            progress: 0.5,
            status: .running
        )
    }

    private func width(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: 170
        case .systemMedium: 360
        default: 360
        }
    }

    private func height(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall: 170
        case .systemMedium: 170
        default: 380
        }
    }
}
