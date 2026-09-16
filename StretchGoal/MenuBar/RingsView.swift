import SwiftUI

struct RingsView: View {
    let progress: [Double]
    let colors: [Color]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let stroke = size / 9
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
