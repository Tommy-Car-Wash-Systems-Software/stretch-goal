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

    private let green = Color(red: 0.20, green: 0.78, blue: 0.35)
    private let blue = Color(red: 0.20, green: 0.68, blue: 0.90)
    private let purple = Color(red: 0.75, green: 0.35, blue: 0.95)
    private let orange = Color(red: 1.0, green: 0.62, blue: 0.20)
    private let teal = Color(red: 0.25, green: 0.80, blue: 0.75)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 28)
                HStack(alignment: .center, spacing: 48) {
                    rings
                    tiles
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 52)
            .padding(.top, 44)
            Spacer(minLength: 0)
            footer
        }
        .frame(width: 1200, height: 630)
        .background(
            LinearGradient(colors: [Color(red: 0.09, green: 0.11, blue: 0.10), Color(red: 0.05, green: 0.17, blue: 0.14)],
                           startPoint: .top, endPoint: .bottom)
        )
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(nickname).font(.system(size: 46, weight: .bold, design: .rounded))
            Text(day.date.date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 24, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            if score.allGoalsMet { badge("PERFECT DAY", symbol: "checkmark.seal.fill", tint: green) }
            if streak > 0 { badge("\(streak) day streak", symbol: "flame.fill", tint: orange) }
        }
    }

    private var rings: some View {
        ZStack {
            RingsView(
                progress: [
                    Double(day.breaks) / Double(rules.breaks.goal),
                    Double(day.waterMl) / Double(rules.water.goalMl),
                    Double(day.mindful) / Double(rules.mindful.goal),
                ],
                colors: [green, blue, purple]
            )
            .frame(width: 320, height: 320)
            VStack(spacing: -2) {
                Text("\(score.total)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("points").font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 130)
        }
    }

    private var tiles: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                tile("figure.walk", "Breaks", "\(day.breaks)", "of \(rules.breaks.goal)", green, met: rules.breaks.goalMet(day.breaks))
                tile("drop.fill", "Water", day.waterMl >= 1000 ? String(format: "%.1f L", Double(day.waterMl) / 1000) : "\(day.waterMl) ml", "of 2 L", blue, met: rules.water.goalMet(day.waterMl))
                tile("wind", "Mindful", "\(day.mindful)", "of \(rules.mindful.goal)", purple, met: rules.mindful.goalMet(day.mindful))
            }
            HStack(spacing: 14) {
                tile("eye", "Eye rests", "\(day.eyeRests)", "of \(rules.eyeRests.goal)", orange, met: rules.eyeRests.goalMet(day.eyeRests))
                tile("shoeprints.fill", "Steps", day.steps >= 1000 ? String(format: "%.1fk", Double(day.steps) / 1000) : "\(day.steps)", "of 8k", teal, met: rules.steps.goalMet(day.steps))
                tile("clock", "Active", MenuBarView.duration(day.activeSeconds), "at the desk", .white.opacity(0.7), met: false)
            }
            Text(caption)
                .font(.system(size: 21, weight: .medium, design: .rounded).italic())
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 8)
                .padding(.leading, 4)
        }
    }

    private func tile(_ symbol: String, _ title: String, _ value: String, _ sub: String, _ tint: Color, met: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
                Text(title.uppercased()).font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.6)).tracking(1)
                Spacer(minLength: 0)
                if met { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(tint) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(sub).font(.system(size: 15)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .frame(width: 208, height: 96, alignment: .leading)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }

    private var footer: some View {
        HStack(spacing: 18) {
            if let qr {
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .padding(5)
                    .background(.white, in: .rect(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Text("Stretch Goal").font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("for macOS · touch grass, beat your coworkers").font(.system(size: 18)).foregroundStyle(.white.opacity(0.6))
                }
                Text(Quips.repoURL.replacingOccurrences(of: "https://", with: ""))
                    .font(.system(size: 17, weight: .medium, design: .monospaced)).foregroundStyle(green)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            Text("brew install --cask stretch-goal")
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 8))
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.35))
    }

    private func badge(_ text: String, symbol: String, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(tint.opacity(0.16), in: .capsule)
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
