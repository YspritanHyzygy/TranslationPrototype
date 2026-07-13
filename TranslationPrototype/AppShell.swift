import SwiftUI
import UIKit

struct AppShell: View {
    @State private var selectedMode: AppMode
    @State private var session = TranslationSession()
    @State private var sheetDestination: SheetDestination?

    init() {
        let configuration = PrototypeLaunchConfiguration.current
        _selectedMode = State(initialValue: configuration.mode)
        _sheetDestination = State(initialValue: configuration.sheet)
    }

    var body: some View {
        ZStack {
            activeScreen
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.paper.ignoresSafeArea())
        .tint(AppTheme.terracotta)
        .gesture(modeSwipeGesture)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: selectedMode)
        .sheet(item: $sheetDestination) { destination in
            sheetView(for: destination)
        }
    }

    @ViewBuilder
    private var activeScreen: some View {
        switch selectedMode {
        case .text:
            TextTranslateView(
                session: session,
                selectedMode: $selectedMode,
                onSwap: swapLanguages,
                onPickSource: { sheetDestination = .language(.source) },
                onPickTarget: { sheetDestination = .language(.target) },
                onHistory: { sheetDestination = .history },
                onSettings: { sheetDestination = .language(.target) }
            )
        case .voice:
            VoiceConversationView(
                sourceLanguage: session.targetLanguage,
                targetLanguage: session.sourceLanguage,
                onPickSource: { sheetDestination = .language(.target) },
                onPickTarget: { sheetDestination = .language(.source) }
            )
        case .camera:
            CameraTranslateView(
                sourceLanguage: session.sourceLanguage,
                targetLanguage: session.targetLanguage,
                onPickLanguage: { sheetDestination = .language(.target) }
            )
        }
    }

    @ViewBuilder
    private func sheetView(for destination: SheetDestination) -> some View {
        switch destination {
        case .language(let role):
            LanguagePickerView(
                role: role,
                sourceSelection: languageBinding(for: .source),
                targetSelection: languageBinding(for: .target)
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
        case .history:
            HistoryView(session: session) { item in
                session.load(item)
                selectedMode = .text
            }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
        }
    }

    private func languageBinding(for role: LanguageSelectionRole) -> Binding<Language> {
        Binding {
            role == .source ? session.sourceLanguage : session.targetLanguage
        } set: { newValue in
            session.select(newValue, for: role)
        }
    }

    private var modeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 44)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -40 {
                    selectedMode = selectedMode.next
                } else if value.translation.width > 40 {
                    selectedMode = selectedMode.previous
                }
            }
    }

    private func swapLanguages() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        session.swapLanguages()
    }
}

#Preview {
    AppShell()
}

private struct PrototypeLaunchConfiguration {
    let mode: AppMode
    let sheet: SheetDestination?

    static var current: PrototypeLaunchConfiguration {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let mode = value(after: "--prototype-mode", in: arguments)
            .flatMap(AppMode.init(rawValue:)) ?? .text
        let sheetValue = value(after: "--prototype-sheet", in: arguments)
        let sheet: SheetDestination?
        switch sheetValue {
        case "history": sheet = .history
        case "language-source": sheet = .language(.source)
        case "language-target": sheet = .language(.target)
        default: sheet = nil
        }
        return PrototypeLaunchConfiguration(mode: mode, sheet: sheet)
#else
        return PrototypeLaunchConfiguration(mode: .text, sheet: nil)
#endif
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
