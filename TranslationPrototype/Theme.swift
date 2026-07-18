import SwiftUI

enum AppTheme {
    static let paper = Color(hex: 0xF7F4EF)
    static let page = Color(hex: 0xE8E4DD)
    static let ink = Color(hex: 0x1C1A17)
    static let secondaryInk = Color(hex: 0x5C564D)
    static let muted = Color(hex: 0x8A8276)
    static let faint = Color(hex: 0xB9B0A2)
    static let terracotta = Color(hex: 0xC2603F)
    static let terracottaSoft = Color(hex: 0xF7ECE6)
    static let divider = Color.black.opacity(0.06)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

extension View {
    func softShadow(radius: CGFloat = 10, y: CGFloat = 4, opacity: Double = 0.06) -> some View {
        shadow(color: .black.opacity(opacity), radius: radius, x: 0, y: y)
    }

    func cardBackground(_ color: Color = .white, radius: CGFloat = 22) -> some View {
        background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .softShadow(radius: 8, y: 2, opacity: 0.045)
    }
}

// MARK: - Liquid Glass (iOS 26+)，iOS 17-25 回退

extension View {
    /// iOS 26+：交互式液体玻璃，裁剪到 shape，可选着色。
    /// iOS 17-25：执行 fallback 闭包，原样保留改造前的背景/阴影链。
    /// 像 background 一样，在 frame/padding 之后调用。
    /// interactive 的拖拽形变只带动玻璃和它内部的内容，静态的同心装饰
    /// （光晕、描边覆盖层）不会跟随——这类按钮要传 interactive: false。
    @ViewBuilder
    func liquidGlass<S: Shape, Fallback: View>(
        tint: Color? = nil,
        interactive: Bool = true,
        in shape: S,
        @ViewBuilder fallback: (Self) -> Fallback
    ) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            fallback(self)
        }
    }

    /// iOS 26+ 用 GlassEffectContainer 包裹，让邻近/重叠的玻璃形状统一采样融合；早期系统为 no-op。
    @ViewBuilder
    func liquidGlassContainer(spacing: CGFloat? = nil) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}
