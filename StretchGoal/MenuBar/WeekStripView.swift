import SwiftUI
import StretchGoalCore

struct WeekStripView: View {
    let statuses: [(day: DayKey, status: AppModel.DayStatus)]
    let today: DayKey

    private let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(statuses.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 4) {
                    Text(letters[index]).font(.caption2).foregroundStyle(.secondary)
                    Circle().fill(color(item.status)).frame(width: 10, height: 10)
                    Rectangle()
                        .fill(item.day == today ? Color.accentColor : .clear)
                        .frame(height: 2)
                        .frame(width: 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func color(_ status: AppModel.DayStatus) -> Color {
        switch status {
        case .complete: .green
        case .partial: .green.opacity(0.4)
        case .none: .secondary.opacity(0.3)
        case .future: .secondary.opacity(0.12)
        }
    }
}
