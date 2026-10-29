//
// Components.swift
// JustDrink
//

import SwiftUI

// A container's picture: its photo if it has one, otherwise a tinted bottle
struct ContainerIcon: View {
    let imageData: Data?
    let color: Color
    let side: CGFloat

    init(imageData: Data?, color: Color, side: CGFloat) {
        self.imageData = imageData
        self.color = color
        self.side = side
    }

    init(container: Container, side: CGFloat) {
        self.init(imageData: container.imageData,
                  color: DataManager.shared.getContainerColor(index: container.colorIndex),
                  side: side)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(shape)
        } else {
            shape
                .fill(color.opacity(0.16))
                .frame(width: side, height: side)
                .overlay {
                    Image(systemName: "waterbottle.fill")
                        .font(.system(size: side * 0.5))
                        .foregroundStyle(color)
                }
        }
    }
}

// The main button: a round glass whose water level shows progress toward today's goal
struct WaterGlass: View {
    let level: Double
    let amountText: String?
    // False while something covers the glass; the waves and the tilt pause
    var live: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var tilt = WaterTilt()

    private var moving: Bool {
        live && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        GeometryReader { proxy in
            let d = proxy.size.width
            let calm = d * 0.028
            // Room above the waterline for the biggest sloshing waves
            let headroom = calm * 2.6
            ZStack {
                Circle().fill(Theme.glass)
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !moving)) { timeline in
                    let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let amplitude = calm * (1 + 1.6 * tilt.swing)
                    ZStack(alignment: .top) {
                        WaveShape(phase: t * 1.3 + 1.6, amplitude: amplitude, baseline: headroom)
                            .fill(Theme.waterBack)
                            .offset(y: -calm * 0.9)
                        WaveShape(phase: t * 1.8, amplitude: amplitude, baseline: headroom)
                            .fill(Theme.water)
                    }
                    .frame(width: d, height: d + headroom * 2)
                    // Waterline fully hidden below the rim at 0, brimming at 1
                    .offset(y: (1 - min(max(level, 0), 1)) * (d + headroom * 2) - headroom)
                    .animation(.spring(duration: 1.0, bounce: 0.2), value: level)
                    // Turned about the glass's center, which keeps the same amount of water inside the circle;
                    // outside the level animation so a new drink doesn't animate the tilt too
                    .frame(width: d, height: d)
                    .rotationEffect(.radians(tilt.angle))
                }
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.ring, lineWidth: d * 0.028))
            .overlay {
                VStack(spacing: 2) {
                    if let amountText {
                        Image(systemName: "plus")
                            .font(.rounded(.title2, weight: .heavy))
                            .foregroundStyle(Theme.waterInk)
                        Text(amountText)
                            .font(.rounded(.title2, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    } else {
                        Image(systemName: "waterbottle")
                            .font(.rounded(.title, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                }
                // The disc doesn't grow with text size, so its label stops growing too
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(d * 0.04)
                .frame(width: d * 0.42, height: d * 0.42)
                .background(
                    Circle()
                        .fill(Theme.card.opacity(0.94))
                        .shadow(color: .black.opacity(0.14), radius: 9, y: 4)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: Theme.water.opacity(0.18), radius: 20, y: 10)
        .onAppear { updateTilt() }
        .onDisappear { tilt.stop() }
        .onChange(of: moving) { _, _ in updateTilt() }
    }

    private func updateTilt() {
        if moving {
            tilt.start()
        } else {
            tilt.stop()
        }
    }
}

// A band of water whose top edge is a sine wave around `baseline` (measured down from the top);
// the band fills everything below the wave
struct WaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var baseline: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func y(at x: CGFloat) -> CGFloat {
            rect.minY + baseline + amplitude * CGFloat(sin(Double(x / rect.width) * 2 * .pi + phase))
        }
        path.move(to: CGPoint(x: rect.minX, y: y(at: 0)))
        var x: CGFloat = 4
        while x < rect.width {
            path.addLine(to: CGPoint(x: rect.minX + x, y: y(at: x)))
            x += 4
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: y(at: rect.width)))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// A thin bar showing progress toward a goal
struct ProgressCapsule: View {
    let progress: Double

    var body: some View {
        Capsule()
            .fill(Theme.track)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.water)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
    }
}

// Shrinks a little while pressed
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.95

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

// Section heading in small capitals
struct Eyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .textCase(.uppercase)
            .font(.rounded(.footnote, weight: .heavy))
            .tracking(1)
            .foregroundStyle(Theme.ink2)
    }
}

// A number for an editable text field: "500" rather than "500.0"; always uses a period so Double() can read it back
func editableNumber(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", value)
    } else {
        return String(value)
    }
}
