import SwiftUI
import UIKit

struct VoiceConversationView: View {
    let sourceLanguage: Language
    let targetLanguage: Language
    let onPickSource: () -> Void
    let onPickTarget: () -> Void

    @State private var turns = ConversationTurn.samples
    @State private var activeSpeaker: ConversationTurn.Speaker = .source
    @State private var isListening = true
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        ForEach(turns) { turn in
                            ConversationBubble(turn: turn)
                                .id(turn.id)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
                .onChange(of: turns.count) {
                    guard let lastID = turns.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
            listeningDock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.paper.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("对话翻译")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.ink)

            LanguagePairPill(
                source: sourceLanguage,
                target: targetLanguage,
                onSourceTap: onPickSource,
                onTargetTap: onPickTarget
            )
            .accessibilityIdentifier("conversation-language-pair")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 1)
        }
    }

    private var listeningDock: some View {
        VStack(spacing: 14) {
            Text(listeningStatus)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isListening ? AppTheme.terracotta : AppTheme.muted)
                .contentTransition(.numericText())
                .accessibilityIdentifier("conversation-listening-status")

            HStack(spacing: 24) {
                languageCircle(
                    sourceLanguage.code == "en" ? "EN" : String(sourceLanguage.nativeName.prefix(1)),
                    speaker: .source,
                    label: "使用\(sourceLanguage.nativeName)讲话"
                )

                Button(action: toggleListening) {
                    ZStack {
                        if isListening {
                            Circle()
                                .fill(AppTheme.terracotta.opacity(0.16))
                                .frame(width: 100, height: 100)
                        }
                        Group {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                                    .controlSize(.large)
                            } else if isListening {
                                WaveBars()
                            } else {
                                Image(systemName: "mic")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 84, height: 84)
                        .liquidGlass(
                            tint: isListening ? AppTheme.terracotta : AppTheme.muted,
                            in: Circle()
                        ) { content in
                            content
                                .background(isListening ? AppTheme.terracotta : AppTheme.muted, in: Circle())
                                .softShadow(radius: 18, y: 8, opacity: 0.24)
                        }
                    }
                    .frame(width: 100, height: 100)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .accessibilityLabel(isListening ? "暂停聆听" : "开始聆听")
                .accessibilityHint("再次开始后会加入一条示例对话")
                .accessibilityIdentifier("conversation-microphone-button")

                languageCircle(
                    targetLanguage.code == "zh-Hans" ? "中" : String(targetLanguage.nativeName.prefix(2)),
                    speaker: .target,
                    label: "使用\(targetLanguage.nativeName)讲话"
                )
            }
            .liquidGlassContainer(spacing: 8)
        }
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(AppTheme.paper.ignoresSafeArea(edges: .bottom))
    }

    private var listeningStatus: String {
        if isProcessing { return "正在翻译…" }
        if !isListening { return "已暂停 · 轻点继续" }
        let language = activeSpeaker == .source ? sourceLanguage.nativeName : targetLanguage.nativeName
        return "正在聆听 · \(language)"
    }

    private func languageCircle(
        _ text: String,
        speaker: ConversationTurn.Speaker,
        label: String
    ) -> some View {
        Button {
            activeSpeaker = speaker
            isListening = true
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(activeSpeaker == speaker ? AppTheme.terracotta : AppTheme.muted)
                .frame(width: 54, height: 54)
                .liquidGlass(in: Circle()) { content in
                    content
                        .background(.white, in: Circle())
                        .softShadow(radius: 7, y: 2, opacity: 0.07)
                }
                .overlay {
                    Circle()
                        .stroke(
                            activeSpeaker == speaker ? AppTheme.terracotta.opacity(0.35) : .clear,
                            lineWidth: 1.5
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(speaker == .source ? "conversation-source-speaker" : "conversation-target-speaker")
    }

    private func toggleListening() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isListening {
            isListening = false
            return
        }

        isListening = true
        isProcessing = true
        Task {
            try? await Task.sleep(nanoseconds: 850_000_000)
            turns.append(prototypeTurn())
            isProcessing = false
        }
    }

    private func prototypeTurn() -> ConversationTurn {
        if activeSpeaker == .source {
            return ConversationTurn(
                speaker: .source,
                language: sourceLanguage.nativeName,
                original: sourceLanguage.code == "en" ? "Could you recommend a good local restaurant?" : "可以推荐一家附近的餐厅吗？",
                translation: targetLanguage.code == "zh-Hans" ? "可以推荐一家不错的本地餐厅吗？" : "Could you recommend a good restaurant nearby?"
            )
        }

        return ConversationTurn(
            speaker: .target,
            language: targetLanguage.nativeName,
            original: targetLanguage.code == "zh-Hans" ? "当然，前面转角就有一家。" : "Of course, there's one just around the corner.",
            translation: sourceLanguage.code == "en" ? "Of course, there's one just around the corner." : "当然，转角处就有一家。"
        )
    }
}

private struct ConversationBubble: View {
    let turn: ConversationTurn

    var body: some View {
        VStack(alignment: turn.speaker == .source ? .leading : .trailing, spacing: 5) {
            Text(turn.language)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(turn.speaker == .source ? AppTheme.faint : Color(hex: 0xC99A85))
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 7) {
                Text(turn.original)
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(turn.speaker == .source ? AppTheme.ink : .white)
                Text(turn.translation)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(turn.speaker == .source ? AppTheme.muted : .white.opacity(0.74))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: 310, alignment: .leading)
            .background(
                turn.speaker == .source ? .white : AppTheme.terracotta,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: turn.speaker == .source ? 6 : 20,
                    bottomTrailingRadius: turn.speaker == .source ? 20 : 6,
                    topTrailingRadius: 20,
                    style: .continuous
                )
            )
            .softShadow(radius: 8, y: 3, opacity: turn.speaker == .source ? 0.045 : 0.12)
        }
        .frame(maxWidth: .infinity, alignment: turn.speaker == .source ? .leading : .trailing)
    }
}

#Preview {
    VoiceConversationView(
        sourceLanguage: .english,
        targetLanguage: .chinese,
        onPickSource: {},
        onPickTarget: {}
    )
}
