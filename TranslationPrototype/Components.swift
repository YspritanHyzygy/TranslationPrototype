import SwiftUI

struct IconCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.muted)
                .frame(width: 38, height: 38)
                .background(.white, in: Circle())
                .softShadow(radius: 5, y: 1, opacity: 0.06)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(systemName))
    }
}

struct LanguagePairBar: View {
    let source: Language
    let target: Language
    let onSourceTap: () -> Void
    let onTargetTap: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSourceTap) {
                Text(source.nativeName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.plain)

            Button(action: onSwap) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.terracotta, in: Circle())
                    .softShadow(radius: 10, y: 5, opacity: 0.22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("交换语言"))

            Button(action: onTargetTap) {
                Text(target.nativeName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .softShadow(radius: 7, y: 2, opacity: 0.05)
    }
}

struct LanguagePairPill: View {
    let source: Language
    let target: Language
    let onSourceTap: () -> Void
    let onTargetTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(source.nativeName, action: onSourceTap)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.terracotta)
            Button(target.nativeName, action: onTargetTap)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 17)
        .padding(.vertical, 10)
        .background(.white, in: Capsule())
        .softShadow(radius: 6, y: 2, opacity: 0.05)
    }
}

struct ModeSwitcher: View {
    @Binding var selection: AppMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 19, weight: .semibold))
                        Text(mode.title)
                            .font(.system(size: 11, weight: selection == mode ? .semibold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selection == mode ? .white : AppTheme.muted)
                    .background(
                        Group {
                            if selection == mode {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppTheme.terracotta)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(mode.title))
            }
        }
        .padding(5)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .softShadow(radius: 14, y: 4, opacity: 0.075)
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = AppTheme.faint

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(1)
            .foregroundStyle(color)
    }
}

struct WaveBars: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: 4, height: CGFloat([18, 30, 24, 34, 20][index]))
                    .scaleEffect(y: animate ? CGFloat([0.45, 1, 0.62, 0.92, 0.52][index]) : 0.32, anchor: .center)
                    .animation(
                        .easeInOut(duration: 0.86)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.12),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

struct TextActionIcon: View {
    let systemName: String
    var color: Color = AppTheme.terracotta.opacity(0.78)

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 24, height: 24)
    }
}

struct PrototypeCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.muted)
                .frame(width: 36, height: 36)
                .background(Color(hex: 0xEDE8DF), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("关闭"))
    }
}
