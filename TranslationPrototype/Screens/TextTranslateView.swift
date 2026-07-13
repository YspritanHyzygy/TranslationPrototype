import AVFoundation
import SwiftUI
import UIKit

struct TextTranslateView: View {
    @Bindable var session: TranslationSession
    @Binding var selectedMode: AppMode
    let onSwap: () -> Void
    let onPickSource: () -> Void
    let onPickTarget: () -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    @FocusState private var sourceIsFocused: Bool
    @State private var isDictating = false
    @State private var alternativeSheet: AlternativeSheet?
    @State private var toastText: String?
    @State private var speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        VStack(spacing: 0) {
            header
            LanguagePairBar(
                source: session.sourceLanguage,
                target: session.targetLanguage,
                onSourceTap: onPickSource,
                onTargetTap: onPickTarget,
                onSwap: onSwap
            )
            .padding(.horizontal, 18)
            .padding(.top, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    sourceCard
                    resultCard
                    Button {
                        alternativeSheet = AlternativeSheet()
                    } label: {
                        Text("轻点结果可查看其他译法")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: 0xC4BBAC))
                            .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(session.translatedText.isEmpty)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }

            ModeSwitcher(selection: $selectedMode)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
        .background(AppTheme.paper.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: session.translatedText)
        .overlay(alignment: .top) {
            if let toastText {
                Text(toastText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.ink.opacity(0.9), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("translation-toast")
            }
        }
        .sheet(item: $alternativeSheet) { _ in
            AlternativeTranslationsView(session: session)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .onChange(of: session.sourceText) {
            session.refreshTranslation()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { sourceIsFocused = false }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("翻译")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(AppTheme.ink)

            Spacer()

            HStack(spacing: 10) {
                IconCircleButton(systemName: "clock", action: onHistory)
                    .accessibilityLabel("历史记录")
                    .accessibilityIdentifier("history-button")
                IconCircleButton(systemName: "slider.horizontal.3", action: onSettings)
                    .accessibilityLabel("语言设置")
                    .accessibilityIdentifier("settings-button")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: session.sourceLanguage.nativeName.uppercased())

            TextEditor(text: $session.sourceText)
                .font(.system(size: 23, weight: .regular))
                .lineSpacing(7)
                .foregroundStyle(AppTheme.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 94, maxHeight: 138)
                .focused($sourceIsFocused)
                .accessibilityLabel("原文")
                .accessibilityIdentifier("source-text-editor")

            HStack {
                Text("\(session.characterCount) 字")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.faint)

                Spacer()

                Button(action: startPrototypeDictation) {
                    Image(systemName: isDictating ? "waveform" : "mic")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel(isDictating ? "正在听写" : "开始听写")
                .accessibilityIdentifier("dictation-button")

                Button {
                    session.sourceText = ""
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("清空原文")
                .accessibilityIdentifier("clear-source-button")
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(AppTheme.muted)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .cardBackground(.white, radius: 22)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Circle()
                    .fill(AppTheme.terracotta)
                    .frame(width: 7, height: 7)
                SectionLabel(
                    text: session.targetLanguage.nativeName.uppercased(),
                    color: AppTheme.terracotta
                )
            }

            Button {
                alternativeSheet = AlternativeSheet()
            } label: {
                Text(session.translatedText.isEmpty ? "译文会显示在这里" : session.translatedText)
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(session.translatedText.isEmpty ? AppTheme.faint : Color(hex: 0x26221D))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .disabled(session.translatedText.isEmpty)
            .accessibilityLabel("译文")
            .accessibilityIdentifier("translation-result")

            HStack(spacing: 16) {
                resultAction(
                    systemName: "speaker.wave.2",
                    label: "朗读译文",
                    identifier: "speak-result-button",
                    action: speakResult
                )
                resultAction(
                    systemName: "doc.on.doc",
                    label: "复制译文",
                    identifier: "copy-result-button",
                    color: Color(hex: 0xB79A8C),
                    action: copyResult
                )
                resultAction(
                    systemName: session.isCurrentFavorite ? "star.fill" : "star",
                    label: session.isCurrentFavorite ? "取消收藏" : "收藏译文",
                    identifier: "favorite-result-button",
                    color: session.isCurrentFavorite ? AppTheme.terracotta : Color(hex: 0xB79A8C)
                ) {
                    session.toggleCurrentFavorite()
                    showToast(session.isCurrentFavorite ? "已收藏" : "已取消收藏")
                }

                Spacer()

                ShareLink(item: session.translatedText) {
                    TextActionIcon(systemName: "square.and.arrow.up", color: Color(hex: 0xB79A8C))
                        .frame(width: 36, height: 36)
                }
                .disabled(session.translatedText.isEmpty)
                .accessibilityLabel("分享译文")
                .accessibilityIdentifier("share-result-button")
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(AppTheme.terracotta.opacity(0.14))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(AppTheme.terracottaSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func resultAction(
        systemName: String,
        label: String,
        identifier: String,
        color: Color = AppTheme.terracotta.opacity(0.78),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            TextActionIcon(systemName: systemName, color: color)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(session.translatedText.isEmpty)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func startPrototypeDictation() {
        guard !isDictating else { return }
        isDictating = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        showToast("正在听写…")
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            session.sourceText = session.sourceLanguage.code == "zh-Hans" ? "你好" : "Good morning"
            isDictating = false
            sourceIsFocused = false
        }
    }

    private func speakResult() {
        guard !session.translatedText.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: session.translatedText)
        utterance.voice = AVSpeechSynthesisVoice(language: session.targetLanguage.code)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
        showToast("正在朗读")
    }

    private func copyResult() {
        UIPasteboard.general.string = session.translatedText
        session.saveCurrent()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast("译文已复制")
    }

    private func showToast(_ text: String) {
        withAnimation { toastText = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if toastText == text {
                withAnimation { toastText = nil }
            }
        }
    }
}

private struct AlternativeSheet: Identifiable {
    let id = UUID()
}

private struct AlternativeTranslationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: TranslationSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("其他译法")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                PrototypeCloseButton { dismiss() }
            }

            ForEach(Array(session.alternatives.enumerated()), id: \.offset) { index, alternative in
                Button {
                    session.translatedText = alternative
                    session.saveCurrent()
                    dismiss()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.terracotta, in: Circle())
                        Text(alternative)
                            .font(.system(size: 17, design: .serif))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("alternative-\(index + 1)")
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(AppTheme.paper.ignoresSafeArea())
    }
}

#Preview {
    TextTranslateView(
        session: TranslationSession(),
        selectedMode: .constant(.text),
        onSwap: {},
        onPickSource: {},
        onPickTarget: {},
        onHistory: {},
        onSettings: {}
    )
}
