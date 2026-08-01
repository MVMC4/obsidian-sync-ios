import SwiftUI
import UIKit

enum VaultPalette {
    static let parchment = Color.dynamic(light: Color(rgb: 0xF7F3DE), dark: Color(rgb: 0x16140F))
    static let parchmentRaised = Color.dynamic(light: Color(rgb: 0xFFFDF2), dark: Color(rgb: 0x211E16))
    static let ink = Color.dynamic(light: Color(rgb: 0x171717), dark: Color(rgb: 0xF4EFD9))
    static let inkPanel = Color.dynamic(light: Color(rgb: 0x171717), dark: Color(rgb: 0x0E0D0A))
    static let lilac = Color(rgb: 0xE8C8FF)
    static let orange = Color(rgb: 0xFFA33B)
    static let teal = Color(rgb: 0x006B5E)
    static let muted = Color.dynamic(light: Color(rgb: 0x6E675A), dark: Color(rgb: 0xB7AE99))
    static let hairline = Color.dynamic(light: Color(rgb: 0x171717).opacity(0.14),
                                        dark: Color(rgb: 0xF4EFD9).opacity(0.18))
    static let onInk = Color(rgb: 0xF7F3DE)
    static let onInkMuted = Color(rgb: 0xF7F3DE).opacity(0.66)
}

extension Color {
    init(rgb: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

enum VaultType {
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .serif).weight(weight)
    }

    static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style).weight(weight)
    }
}

struct VaultPanel: ViewModifier {
    var ink: Bool = false
    var radius: CGFloat = 28
    func body(content: Content) -> some View {
        content
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(ink ? VaultPalette.inkPanel : VaultPalette.parchmentRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(ink ? VaultPalette.onInk.opacity(0.16) : VaultPalette.hairline,
                            lineWidth: ink ? 0 : 1.5)
            )
    }
}

extension View {
    func vaultPanel(ink: Bool = false, radius: CGFloat = 28) -> some View {
        modifier(VaultPanel(ink: ink, radius: radius))
    }
}

enum VaultPillStyle {
    case primary, lilac, orange, teal, outline, ghost
}

struct VaultPillButton: View {
    let title: String
    var systemImage: String? = nil
    var style: VaultPillStyle = .primary
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let systemImage {
                    Image(systemName: systemImage).font(.body.weight(.semibold))
                }
                Text(title).font(.body.weight(.semibold))
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: style == .outline ? 2 : 0))
            .foregroundStyle(foreground)
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(PressablePill())
        .disabled(disabled)
        .accessibilityLabel(title)
    }

    private var background: Color {
        switch style {
        case .primary: return VaultPalette.ink
        case .lilac: return VaultPalette.lilac
        case .orange: return VaultPalette.orange
        case .teal: return VaultPalette.teal
        case .outline, .ghost: return .clear
        }
    }

    private var foreground: Color {
        switch style {
        case .primary, .teal: return VaultPalette.onInk
        case .lilac, .orange: return VaultPalette.ink
        case .outline, .ghost: return VaultPalette.ink
        }
    }

    private var border: Color {
        style == .outline ? VaultPalette.ink : .clear
    }
}

private struct PressablePill: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct VaultBadge: View {
    let text: String
    var tint: Color = VaultPalette.teal
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.18)))
        .overlay(Capsule().stroke(tint.opacity(0.55), lineWidth: 1))
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }
}

struct SyncMark: View {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false
    var body: some View {
        ZStack {
            Circle().stroke(VaultPalette.ink.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(VaultPalette.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(spin ? 360 : 0))
            Circle().fill(VaultPalette.orange).frame(width: 9, height: 9)
                .offset(y: -16)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(active ? 1 : 0.4)
        }
        .frame(width: 40, height: 40)
        .onAppear {
            guard active, !reduceMotion else { return }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
        .onChange(of: active) { _, now in
            guard !reduceMotion else { return }
            if now {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct DottedFlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0
    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let count = 26
                for i in 0..<count {
                    let p = CGFloat(i) / CGFloat(count)
                    let x = p * size.width
                    let y = size.height / 2 + sin((p * .pi * 2) + CGFloat(t).truncatingRemainder(dividingBy: 6)) * 6
                    let dot = Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                    ctx.fill(dot, with: .color(VaultPalette.ink.opacity(0.22)))
                }
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }
}

struct EditorialHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vault Sync")
                .font(VaultType.body(.subheadline, weight: .semibold))
                .foregroundStyle(VaultPalette.muted)
                .textCase(.uppercase)
                .tracking(2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Your notes,")
                    .font(VaultType.display(size: 40, weight: .regular))
                    .foregroundStyle(VaultPalette.muted)
                Text("in motion.")
                    .font(VaultType.display(size: 40, weight: .black))
                    .foregroundStyle(VaultPalette.ink)
            }
            .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func vaultReveal(_ id: AnyHashable) -> some View {
        modifier(RevealModifier(id: id))
    }
}

private struct RevealModifier: ViewModifier {
    let id: AnyHashable
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !reduceMotion else { shown = true; return }
                withAnimation(.easeOut(duration: 0.5)) { shown = true }
            }
            .accessibilityElement(children: .contain)
    }
}
