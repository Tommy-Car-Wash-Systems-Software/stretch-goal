import AppKit
import CoreImage.CIFilterBuiltins
import SwiftUI
import StretchGoalCore

/// The 1200×630 card people paste into Teams. Rendered off-screen with ImageRenderer.
struct ShareCardView: View {
    let nickname: String
    let day: DaySummary
    let score: DayScore
    let streak: Int
    let rules: ScoringRules
    let caption: String
    let qr: NSImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.30, green: 0.88, blue: 0.54), Color(red: 0.08, green: 0.63, blue: 0.48), Color(red: 0.04, green: 0.50, blue: 0.47)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.18), .clear], center: .init(x: 0.25, y: 0.2), startRadius: 0, endRadius: 500)

            HStack(spacing: 56) {
                ZStack {
                    RingsView(
                        progress: [
                            Double(day.breaks) / Double(rules.breaks.goal),
                            Double(day.waterMl) / Double(rules.water.goalMl),
                            Double(day.mindful) / Double(rules.mindful.goal),
                        ],
                        colors: [.white, Color(red: 0.55, green: 0.85, blue: 1.0), Color(red: 0.85, green: 0.65, blue: 1.0)]
                    )
                    .frame(width: 380, height: 380)
                    VStack(spacing: -6) {
                        Text("\(score.total)")
                            .font(.system(size: 96, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                        Text("pts").font(.system(size: 28, weight: .semibold, design: .rounded)).opacity(0.85)
                    }
                }
                .padding(.leading, 64)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(nickname).font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("· \(day.date.date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                            .font(.system(size: 26, weight: .medium)).opacity(0.8)
                    }
                    HStack(spacing: 14) {
                        if score.allGoalsMet {
                            badge("PERFECT DAY", symbol: "checkmark.seal.fill")
                        }
                        if streak > 0 {
                            badge("\(streak) day streak", symbol: "flame.fill")
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 10) {
                        GridRow {
                            stat("figure.walk", "Breaks", "\(day.breaks)/\(rules.breaks.goal)")
                            stat("drop.fill", "Water", "\(day.waterMl.formatted()) ml")
                        }
                        GridRow {
                            stat("wind", "Mindful", "\(day.mindful)/\(rules.mindful.goal)")
                            stat("eye", "Eye rests", "\(day.eyeRests)/\(rules.eyeRests.goal)")
                        }
                        GridRow {
                            stat("shoeprints.fill", "Steps", day.steps.formatted())
                            stat("clock", "Active", MenuBarView.duration(day.activeSeconds))
                        }
                    }
                    Text(caption)
                        .font(.system(size: 24, weight: .medium, design: .rounded).italic())
                        .opacity(0.9)
                        .padding(.top, 4)
                    Spacer(minLength: 0)
                    HStack(spacing: 16) {
                        if let qr {
                            Image(nsImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 96, height: 96)
                                .padding(6)
                                .background(.white, in: .rect(cornerRadius: 10))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stretch Goal for macOS").font(.system(size: 22, weight: .bold, design: .rounded))
                            Text(Quips.repoURL.replacingOccurrences(of: "https://", with: ""))
                                .font(.system(size: 15, weight: .medium, design: .monospaced)).opacity(0.9)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text("touch grass. beat your coworkers.").font(.system(size: 18)).opacity(0.75)
                        }
                    }
                }
                .padding(.vertical, 56)
                .padding(.trailing, 64)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 1200, height: 630)
    }

    private func badge(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(.white.opacity(0.2), in: .capsule)
    }

    private func stat(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 22)).frame(width: 30)
            Text(title).font(.system(size: 22)).opacity(0.85)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .frame(minWidth: 260, alignment: .leading)
    }
}

@MainActor
enum ShareCard {
    static func render(model: AppModel) -> NSImage? {
        let day = model.day.summary
        let score = model.score
        let seed = day.date.year * 400 + day.date.month * 31 + day.date.day + score.total
        let view = ShareCardView(
            nickname: model.profile.nickname,
            day: day,
            score: score,
            streak: model.streak,
            rules: model.rules,
            caption: Quips.shareCaption(points: score.total, allGoals: score.allGoalsMet, seed: seed),
            qr: qrImage(Quips.repoURL, size: 192)
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.nsImage
    }

    static func caption(model: AppModel) -> String {
        let d = model.day.summary
        let s = model.score
        var parts = ["\(s.total) pts", "\(d.breaks) breaks", "\(d.waterMl.formatted()) ml", "\(d.mindful) mindful", "\(d.eyeRests) eye rests"]
        if d.steps > 0 { parts.append("\(d.steps.formatted()) steps") }
        if model.streak > 0 { parts.append("\(model.streak)-day streak") }
        let head = "Stretch Goal · \(d.date.date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · " + parts.joined(separator: " · ")
        return head + (s.allGoalsMet ? " · PERFECT DAY" : "") + "\nget it: \(Quips.repoURL)"
    }

    static func qrImage(_ string: String, size: CGFloat) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
