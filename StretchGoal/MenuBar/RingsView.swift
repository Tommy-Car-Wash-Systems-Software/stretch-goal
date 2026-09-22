import SwiftUI

struct RingsView: View {
    let progress: [Double]
    let colors: [Color]
    /// Ring thickness as a fraction of the diameter. 1/9 in the popover; thinner on the share card.
    var strokeFraction: CGFloat = 1 / 9

    /// Diameter of the empty centre, for placing a label inside the rings.
    static func innerDiameter(size: CGFloat, rings: Int, strokeFraction: CGFloat = 1 / 9) -> CGFloat {
        let stroke = size * strokeFraction
        let innermostInset = CGFloat(rings - 1) * (stroke + 3) + stroke / 2
        return size - 2 * (innermostInset + stroke / 2)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let stroke = size * strokeFraction
            ZStack {
                ForEach(progress.indices, id: \.self) { i in
                    let inset = CGFloat(i) * (stroke + 3) + stroke / 2
                    Circle()
                        .stroke(colors[i].opacity(0.2), lineWidth: stroke)
                        .padding(inset)
                    Circle()
                        .trim(from: 0, to: min(1, max(0, progress[i])))
                        .stroke(colors[i], style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(inset)
                        .animation(.snappy, value: progress[i])
                }
            }
            .frame(width: size, height: size)
        }
    }
}
