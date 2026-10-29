//
// Theme.swift
// JustDrink
//

import SwiftUI
import UIKit

// App colors, each with a light and a dark version
enum Theme {
    static let ground = Color(light: 0xF2F6FA, dark: 0x0B1520)
    static let card = Color(light: 0xFFFFFF, dark: 0x15212F)
    static let ink = Color(light: 0x0E2033, dark: 0xEAF1F8)
    static let ink2 = Color(light: 0x52637A, dark: 0x9FB2C6)
    static let line = Color(light: 0xDEE6EF, dark: 0x243446)
    static let water = Color(light: 0x2A86E8, dark: 0x3D97F5)
    static let waterBack = Color(light: 0x9ACFF7, dark: 0x2C5F8F)
    static let waterInk = Color(light: 0x1463C2, dark: 0x7CC0FF)
    static let glass = Color(light: 0xE7F2FC, dark: 0x122335)
    static let ring = Color(light: 0x8DB9E6, dark: 0x2A4A6E)
    // Buttons and links; darker than water in light mode so text on white stays readable
    static let tint = Color(light: 0x1463C2, dark: 0x2F8CFF)
    static let track = Color(light: 0xDCE8F5, dark: 0x1D3550)
    static let good = Color(light: 0x13784F, dark: 0x4FD1A0)
    static let warm = Color(light: 0xA9500B, dark: 0xFFB15C)

    // Rainbow colors for containers without a photo, in the order colorIndex picks them
    static let containerColors: [Color] = [
        Color(light: 0x2A86E8, dark: 0x6CB2FF), // blue
        Color(light: 0xD9453D, dark: 0xFF8A80), // red
        Color(light: 0x1A8F61, dark: 0x4FD1A0), // green
        Color(light: 0xD46E12, dark: 0xFFB15C), // orange
        Color(light: 0x7B5BD6, dark: 0xB39DFF), // purple
        Color(light: 0xD63F8C, dark: 0xFF8CC6), // pink
        Color(light: 0xB58500, dark: 0xFFD54F), // yellow
        Color(light: 0x0E93B0, dark: 0x5FD4EE)  // cyan
    ]

    // Rounded, heavy navigation titles to match the rest of the app
    static func styleNavigationBars() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: roundedFont(.largeTitle, weight: .heavy, maximum: 52), .foregroundColor: UIColor(ink)]
        appearance.titleTextAttributes = [.font: roundedFont(.headline, weight: .heavy, maximum: 22), .foregroundColor: UIColor(ink)]
    }

    // Starts from the default-size point size and scales it once, capped so titles fit their bar
    private static func roundedFont(_ style: UIFont.TextStyle, weight: UIFont.Weight, maximum: CGFloat) -> UIFont {
        let defaultSize = UITraitCollection(preferredContentSizeCategory: .large)
        let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style, compatibleWith: defaultSize).pointSize, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: 0), maximumPointSize: maximum)
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Font {
    // Rounded system type that follows Dynamic Type
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
