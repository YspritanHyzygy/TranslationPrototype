import AVFoundation
import OSLog
import SwiftUI
import UIKit

struct TextTranslateView: View {
    @Bindable var session: TranslationSession
    let onSwap: () -> Void
    let onPickSource: () -> Void
    let onPickTarget: () -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @FocusState private var sourceIsFocused: Bool
    @State private var draft: TextTranslationDraft?
    @State private var isDictating = false
    @State private var presentedSheet: TextTranslateSheet?
    @State private var toastText: String?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var pendingFocusTask: Task<Void, Never>?
    @State private var transitionPhase: TextEntryTransitionPhase = .idle
    @State private var transitionGeneration = 0
    @State private var pendingEntryAnimationGeneration: Int?
    @State private var pendingEntryLayoutCandidate: TextEntrySourceLayoutMeasurement?
    @State private var entryLayoutValidationPass = 0
    @State private var idleSourceFrame = CGRect.zero
    @State private var liveSourceFrame = CGRect.zero
    @State private var idleResultFrame = CGRect.zero
    @State private var currentViewportSize = CGSize.zero
    @State private var idleViewportSize = CGSize.zero
    @State private var idleViewportHeight: CGFloat = 0
    @State private var transitionSourceFrame = CGRect.zero
    @State private var transitionResultFrame = CGRect.zero
    @State private var transitionPaperTargetHeight: CGFloat = 0
    @State private var transitionPaperGeometryIsValid = false
    @State private var transitionResultGeometryIsValid = false
    @State private var transitionSnapshot = TextEntryTransitionSnapshot.empty
    @State private var paperRevealProgress: CGFloat = 0
    @State private var transitionPaperOpacity: Double = 0
    @State private var liveSourceOpacity: Double = 1
    @State private var liveResultOpacity: Double = 1
    @State private var transitionResultOpacity: Double = 0
    @State private var transitionResultOffset: CGFloat = 0
    @State private var idleHeaderOpacity: Double = 1
    @State private var finishButtonProgress: CGFloat = 0
#if DEBUG
    @State private var motionProbeTransitionID = 0
    @State private var motionProbeDirection: TextEntryMotionDirection = .idle
#endif
    @State private var transitionSignpostState: OSSignpostIntervalState?

    var body: some View {
        VStack(spacing: 0) {
            header
            languagePairBar

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            sourceCard
                                .frame(height: focusedSourceCardHeight(in: proxy.size.height))
                                .opacity(liveSourceOpacity)
                                .allowsHitTesting(
                                    transitionPhase == .idle || transitionPhase == .editing
                                )
                                .modifier(
                                    TextEntryTransitionAccessibilityModifier(
                                        isHidden: transitionPhase == .entering
                                            || transitionPhase == .exiting
                                    )
                                )
                                .onGeometryChange(for: TextEntrySourceLayoutMeasurement.self) { cardProxy in
                                    TextEntrySourceLayoutMeasurement(
                                        generation: transitionGeneration,
                                        validationPass: entryLayoutValidationPass,
                                        frame: cardProxy.frame(
                                            in: .named(TextEntryCoordinateSpace.name)
                                        ),
                                        viewportSize: proxy.size
                                    )
                                } action: { measurement in
                                    storeSourceLayout(measurement)
                                }

                            if transitionPhase == .idle {
                                resultGroup
                                    .opacity(liveResultOpacity)
                                    .background {
                                        GeometryReader { resultProxy in
                                            Color.clear.preference(
                                                key: IdleResultFramePreferenceKey.self,
                                                value: resultProxy.frame(in: .named(TextEntryCoordinateSpace.name))
                                            )
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                    .zIndex(0)

                    TextEntryTransitionOverlay(
                        snapshot: transitionSnapshot,
                        sourceFrame: transitionSourceFrame,
                        resultFrame: transitionResultFrame,
                        paperTargetHeight: transitionPaperTargetHeight,
                        paperProgress: paperRevealProgress,
                        paperOpacity: transitionPaperOpacity,
                        resultOpacity: transitionResultOpacity,
                        resultOffset: transitionResultOffset,
                        reducesMotion: motionProfile.reducesMotion,
                        probe: motionProbeToken
                    )
                    .zIndex(10)

                    motionProbeAccessibilityView
                        .zIndex(20)
                }
                .coordinateSpace(name: TextEntryCoordinateSpace.name)
                .onAppear {
                    storeIdleViewportSize(proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    storeIdleViewportSize(newSize)
                }
                .onPreferenceChange(IdleResultFramePreferenceKey.self, perform: storeIdleResultFrame)
            }
        }
        .background(AppTheme.paper.ignoresSafeArea())
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
        .sheet(item: $presentedSheet, onDismiss: restoreDraftFocusIfNeeded) { destination in
            sheetView(for: destination)
        }
        .onDisappear {
            cancelPendingFocus()
            pendingEntryAnimationGeneration = nil
            pendingEntryLayoutCandidate = nil
            transitionGeneration &+= 1
            endTransitionSignpost(markStable: false)
        }
        .toolbar(isEditingSource ? .hidden : .visible, for: .tabBar)
    }

    private var header: some View {
        HStack {
            Text("翻译")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(AppTheme.ink)

            Spacer()

            ZStack(alignment: .trailing) {
                HStack(spacing: 10) {
                    IconCircleButton(systemName: "clock", action: onHistory)
                        .accessibilityLabel("历史记录")
                        .accessibilityIdentifier("history-button")
                    IconCircleButton(systemName: "slider.horizontal.3", action: onSettings)
                        .accessibilityLabel("语言设置")
                        .accessibilityIdentifier("settings-button")
                }
                .opacity(idleHeaderOpacity)
                .allowsHitTesting(transitionPhase == .idle)
                .accessibilityHidden(transitionPhase != .idle)

                Button(action: finishEditingAndTranslate) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.terracotta, in: Circle())
                        .softShadow(radius: 9, y: 4, opacity: 0.2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("完成并翻译")
                .accessibilityHint("提交当前文字并返回翻译结果")
                .accessibilityIdentifier(
                    transitionPhase == .editing
                        ? "finish-source-editing-button"
                        : "finish-source-editing-button-hidden"
                )
                .opacity(finishButtonProgress)
                .scaleEffect(motionProfile.finishButtonScale(progress: finishButtonProgress))
                .allowsHitTesting(transitionPhase == .editing)
                .accessibilityHidden(transitionPhase != .editing)
            }
            .frame(width: 102, height: 46, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private var languagePairBar: some View {
        LanguagePairBar(
            source: activeSourceLanguage,
            target: activeTargetLanguage,
            onSourceTap: { presentLanguagePicker(for: .source) },
            onTargetTap: { presentLanguagePicker(for: .target) },
            onSwap: swapActiveLanguages
        )
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .allowsHitTesting(transitionPhase == .idle || transitionPhase == .editing)
        .modifier(
            TextEntryTransitionAccessibilityModifier(
                isHidden: transitionPhase == .entering || transitionPhase == .exiting
            )
        )
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(
                text: activeSourceLanguage.nativeName.uppercased(),
                color: isEditingSource ? AppTheme.secondaryInk : AppTheme.faint
            )

            ZStack(alignment: .topLeading) {
                if activeSourceText.isEmpty {
                    Text("输入需要翻译的文字")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: sourceTextBinding)
                    .font(.system(size: 25, weight: .regular))
                    .lineSpacing(7)
                    .foregroundStyle(AppTheme.ink)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 94, maxHeight: .infinity)
                    .focused($sourceIsFocused)
                    .allowsHitTesting(isEditingSource)
                    .accessibilityLabel("原文")
                    .accessibilityHint("输入完成后，点按右上角对勾翻译")
                    .accessibilityIdentifier("source-text-editor")
                    .accessibilityHidden(transitionPhase != .editing)

                if !isEditingSource {
                    Button(action: beginEditingIfNeeded) {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("原文")
                    .accessibilityValue(activeSourceText)
                    .accessibilityHint("点按以编辑原文")
                    .accessibilityIdentifier("source-text-editor")
                }
            }

            HStack {
                Text("\(activeCharacterCount) 字")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.faint)

                Spacer()

                Button(action: startPrototypeDictation) {
                    Image(systemName: isDictating ? "waveform" : "mic")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isDictating ? "正在听写" : "开始听写")
                .accessibilityIdentifier("dictation-button")

                Button(action: clearActiveSource) {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空原文")
                .accessibilityIdentifier("clear-source-button")
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(AppTheme.muted)
            .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background {
            sourceCardSurface(strokeOpacity: isEditingSource ? 0.24 : 0)
        }
    }

    private func sourceCardSurface(strokeOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.terracotta.opacity(strokeOpacity), lineWidth: 1.5)
            }
            .softShadow(radius: 8, y: 2, opacity: 0.045)
    }

    private var resultGroup: some View {
        VStack(spacing: 14) {
            resultCard

            Button {
                presentedSheet = .alternatives
            } label: {
                Text("轻点结果可查看其他译法")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: 0xC4BBAC))
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .disabled(session.translatedText.isEmpty)
        }
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
                presentedSheet = .alternatives
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
            .accessibilityValue(session.translatedText)
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

    private var isEditingSource: Bool {
        draft != nil
    }

    private var activeSourceText: String {
        draft?.sourceText ?? session.sourceText
    }

    private var activeSourceLanguage: Language {
        draft?.sourceLanguage ?? session.sourceLanguage
    }

    private var activeTargetLanguage: Language {
        draft?.targetLanguage ?? session.targetLanguage
    }

    private var activeCharacterCount: Int {
        activeSourceText.filter { !$0.isWhitespace }.count
    }

    private var motionProfile: TextEntryMotionProfile {
        TextEntryMotionProfile(reducesMotion: shouldReduceMotion)
    }

    private var shouldReduceMotion: Bool {
#if DEBUG
        accessibilityReduceMotion
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-reduce-motion")
#else
        accessibilityReduceMotion
#endif
    }

    private var motionProbeIsEnabled: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing-text-entry-motion-probe")
#else
        false
#endif
    }

    @ViewBuilder
    private var motionProbeAccessibilityView: some View {
#if DEBUG
        if motionProbeIsEnabled {
            TextEntryMotionProbeAccessibilityView(reducesMotion: shouldReduceMotion)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        }
#endif
    }

    private var sourceTextBinding: Binding<String> {
        Binding {
            activeSourceText
        } set: { newValue in
            guard draft != nil else { return }
            draft?.sourceText = newValue
        }
    }

    private func focusedSourceCardHeight(in viewportHeight: CGFloat) -> CGFloat? {
        guard isEditingSource else { return nil }
        return max(260, viewportHeight - 32)
    }

    private func storeIdleViewportSize(_ size: CGSize) {
        if abs(currentViewportSize.width - size.width) >= 1
            || abs(currentViewportSize.height - size.height) >= 1 {
            currentViewportSize = size
        }

        guard transitionPhase == .idle,
              draft == nil,
              (abs(idleViewportSize.width - size.width) >= 1
                || abs(idleViewportSize.height - size.height) >= 1) else { return }
        idleViewportSize = size
        idleViewportHeight = size.height
    }

    private func storeSourceLayout(_ measurement: TextEntrySourceLayoutMeasurement) {
        let frame = measurement.frame
        guard frame.width > 0, frame.height > 0 else { return }

        storeIdleViewportSize(measurement.viewportSize)

        if framesDiffer(liveSourceFrame, frame) {
            liveSourceFrame = frame
        }

        if transitionPhase == .entering,
           pendingEntryAnimationGeneration == measurement.generation,
           measurement.generation == transitionGeneration,
           draft != nil {
            if let candidate = pendingEntryLayoutCandidate,
               entryLayoutsAreStable(candidate, measurement) {
                let generation = measurement.generation
                withNoAnimation {
                    transitionPaperTargetHeight = max(
                        transitionSourceFrame.height,
                        frame.height
                    )
                    pendingEntryAnimationGeneration = nil
                    pendingEntryLayoutCandidate = nil
                }
                startEntryAnimation(generation: generation)
            } else {
                withNoAnimation {
                    pendingEntryLayoutCandidate = measurement
                }
                scheduleEntryLayoutValidation(for: measurement)
            }
        }

        guard transitionPhase == .idle,
              draft == nil,
              framesDiffer(idleSourceFrame, frame) else { return }
        idleSourceFrame = frame
    }

    private func entryLayoutsAreStable(
        _ lhs: TextEntrySourceLayoutMeasurement,
        _ rhs: TextEntrySourceLayoutMeasurement
    ) -> Bool {
        lhs.generation == rhs.generation
            && !framesDiffer(lhs.frame, rhs.frame)
            && abs(lhs.viewportSize.width - rhs.viewportSize.width) < 1
            && abs(lhs.viewportSize.height - rhs.viewportSize.height) < 1
    }

    private func scheduleEntryLayoutValidation(
        for candidate: TextEntrySourceLayoutMeasurement
    ) {
        // Cross a main-run-loop transaction before asking SwiftUI for the
        // confirming sample. This gives the parent TabView time to commit its
        // toolbar visibility and safe-area proposal without guessing a delay.
        // A late geometry update replaces the candidate and invalidates this
        // callback, so only the latest generation can advance validation.
        DispatchQueue.main.async {
            guard transitionPhase == .entering,
                  pendingEntryAnimationGeneration == candidate.generation,
                  candidate.generation == transitionGeneration,
                  pendingEntryLayoutCandidate == candidate else { return }
            withNoAnimation {
                entryLayoutValidationPass &+= 1
            }
        }
    }

    private func storeIdleResultFrame(_ frame: CGRect) {
        guard transitionPhase == .idle,
              draft == nil,
              frame.width > 0,
              framesDiffer(idleResultFrame, frame) else { return }
        idleResultFrame = frame
    }

    private func framesDiffer(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) >= 1
            || abs(lhs.minY - rhs.minY) >= 1
            || abs(lhs.width - rhs.width) >= 1
            || abs(lhs.height - rhs.height) >= 1
    }

    private func prepareTransitionGeometry() {
        let measuredSourceIsValid = idleSourceFrame.width >= 1
            && idleSourceFrame.height >= 1
            && idleViewportHeight >= 1
        let viewportWidth = idleViewportSize.width >= 1 ? idleViewportSize.width : 390
        let viewportHeight = idleViewportHeight >= 1 ? idleViewportHeight : 600
        let fallbackHeight = min(230, max(190, viewportHeight * 0.30))
        let fallbackSourceFrame = CGRect(
            x: 18,
            y: 16,
            width: max(1, viewportWidth - 36),
            height: fallbackHeight
        )

        transitionPaperGeometryIsValid = measuredSourceIsValid
        transitionSourceFrame = measuredSourceIsValid ? idleSourceFrame : fallbackSourceFrame
        transitionPaperTargetHeight = max(
            transitionSourceFrame.height,
            max(260, viewportHeight - 32)
        )

        transitionResultGeometryIsValid = idleResultFrame.width >= 1
            && idleResultFrame.height >= 1
        transitionResultFrame = transitionResultGeometryIsValid
            ? idleResultFrame
            : CGRect(
                x: transitionSourceFrame.minX,
                y: transitionSourceFrame.maxY + 14,
                width: transitionSourceFrame.width,
                height: 220
            )

        if !transitionPaperGeometryIsValid || !transitionResultGeometryIsValid {
            TextEntryMotionTrace.signposter.emitEvent("TextEntryGeometryFallback")
        }
    }

    private func makeTransitionSnapshot(
        from textDraft: TextTranslationDraft
    ) -> TextEntryTransitionSnapshot {
        TextEntryTransitionSnapshot(
            sourceText: textDraft.sourceText,
            sourceLanguageName: textDraft.sourceLanguage.nativeName.uppercased(),
            characterCount: textDraft.sourceText.filter { !$0.isWhitespace }.count,
            isDictating: isDictating,
            resultLanguageName: session.targetLanguage.nativeName.uppercased(),
            translatedText: session.translatedText,
            resultIsFavorite: session.isCurrentFavorite
        )
    }

    private var motionProbeToken: TextEntryMotionProbeToken {
#if DEBUG
        TextEntryMotionProbeToken(
            id: motionProbeTransitionID,
            direction: motionProbeDirection,
            originY: transitionSourceFrame.minY,
            isVisible: transitionPaperOpacity > 0.01
        )
#else
        .disabled
#endif
    }

    private func beginMotionProbe(direction: TextEntryMotionDirection) {
#if DEBUG
        motionProbeTransitionID &+= 1
        motionProbeDirection = direction
        if motionProbeIsEnabled {
            TextEntryMotionProbe.shared.begin(
                id: motionProbeTransitionID,
                direction: direction,
                reducesMotion: shouldReduceMotion,
                initialBottomY: transitionSourceFrame.minY
                    + (direction == .entering
                        ? transitionSourceFrame.height
                        : transitionPaperTargetHeight)
            )
        }
#endif
    }

    private func completeMotionProbe(direction: TextEntryMotionDirection) {
#if DEBUG
        if motionProbeIsEnabled {
            TextEntryMotionProbe.shared.complete(
                id: motionProbeTransitionID,
                direction: direction,
                expectedBottomY: direction == .entering
                    ? transitionSourceFrame.minY + transitionPaperTargetHeight
                    : transitionSourceFrame.maxY
            )
        }
#endif
    }

    @ViewBuilder
    private func sheetView(for destination: TextTranslateSheet) -> some View {
        switch destination {
        case .alternatives:
            AlternativeTranslationsView(session: session)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        case .draftLanguage(let role):
            LanguagePickerView(
                role: role,
                sourceSelection: draftLanguageBinding(for: .source),
                targetSelection: draftLanguageBinding(for: .target)
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(30)
        }
    }

    private func beginEditingIfNeeded() {
        guard draft == nil, transitionPhase == .idle else {
            scheduleSourceFocus(afterNanoseconds: 0)
            return
        }

        transitionGeneration &+= 1
        let generation = transitionGeneration
        beginTransitionSignpost()
        TextEntryMotionTrace.signposter.emitEvent("TextEntryTapped")

        let initialDraft = session.makeTextDraft()
        prepareTransitionGeometry()

        withNoAnimation {
            transitionSnapshot = makeTransitionSnapshot(from: initialDraft)
            draft = initialDraft
            transitionPhase = .entering
            paperRevealProgress = 0
            transitionPaperOpacity = 1
            liveSourceOpacity = 0
            liveResultOpacity = 1
            transitionResultOpacity = 1
            transitionResultOffset = 0
            idleHeaderOpacity = 1
            finishButtonProgress = 0
            pendingEntryLayoutCandidate = nil
            pendingEntryAnimationGeneration = generation
        }
    }

    private func startEntryAnimation(generation: Int) {
        guard generation == transitionGeneration,
              transitionPhase == .entering,
              draft != nil else { return }
        beginMotionProbe(direction: .entering)

        if motionProfile.reducesMotion {
            withNoAnimation {
                paperRevealProgress = 1
            }
            withAnimation(
                motionProfile.reducedMotionCrossfade,
                completionCriteria: .removed
            ) {
                transitionPaperOpacity = 0
                liveSourceOpacity = 1
                transitionResultOpacity = 0
                idleHeaderOpacity = 0
                finishButtonProgress = 1
            } completion: {
                completeEntryTransition(generation: generation)
            }
            scheduleSourceFocus(afterNanoseconds: 0)
            return
        }

        withAnimation(motionProfile.resultExitAnimation) {
            transitionResultOpacity = 0
            transitionResultOffset = motionProfile.resultExitOffset
            idleHeaderOpacity = 0
        }
        withAnimation(motionProfile.finishButtonAnimation.delay(0.04)) {
            finishButtonProgress = 1
        }
        withAnimation(
            motionProfile.paperExpansionAnimation,
            completionCriteria: .removed
        ) {
            paperRevealProgress = 1
        } completion: {
            beginEntryHandoff(generation: generation)
        }
        scheduleSourceFocus(afterNanoseconds: motionProfile.focusDelayNanoseconds)
    }

    private func finishEditingAndTranslate() {
        guard transitionPhase == .editing, let completedDraft = draft else { return }
        cancelPendingFocus()
        transitionGeneration &+= 1
        let generation = transitionGeneration
        pendingEntryAnimationGeneration = nil
        pendingEntryLayoutCandidate = nil
        endTransitionSignpost(markStable: false)
        beginTransitionSignpost()
        let focusedHeight = focusedSourceCardHeight(in: currentViewportSize.height) ?? 0
        let frozenEditingHeight = max(
            transitionSourceFrame.height,
            max(focusedHeight, liveSourceFrame.height)
        )
        sourceIsFocused = false
        session.commitAndTranslate(completedDraft)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withNoAnimation {
            transitionSnapshot = makeTransitionSnapshot(from: completedDraft)
            transitionPhase = .exiting
            transitionPaperTargetHeight = frozenEditingHeight
            paperRevealProgress = 1
            transitionPaperOpacity = 0
            liveSourceOpacity = 1
            liveResultOpacity = 1
            transitionResultOpacity = 0
            transitionResultOffset = motionProfile.resultExitOffset
        }
        beginMotionProbe(direction: .exiting)

        if motionProfile.reducesMotion {
            finishReducedMotionExit(generation: generation)
            return
        }

        withAnimation(
            motionProfile.overlayHandoffAnimation,
            completionCriteria: .removed
        ) {
            transitionPaperOpacity = 1
            liveSourceOpacity = 0
            finishButtonProgress = 0
        } completion: {
            beginExitContraction(generation: generation)
        }
    }

    private func beginEntryHandoff(generation: Int) {
        guard generation == transitionGeneration, transitionPhase == .entering else { return }
        withAnimation(
            motionProfile.overlayHandoffAnimation,
            completionCriteria: .removed
        ) {
            transitionPaperOpacity = 0
            liveSourceOpacity = 1
        } completion: {
            completeEntryTransition(generation: generation)
        }
    }

    private func completeEntryTransition(generation: Int) {
        guard generation == transitionGeneration, transitionPhase == .entering else { return }
        withNoAnimation {
            transitionPhase = .editing
            transitionPaperOpacity = 0
            liveSourceOpacity = 1
        }
        completeMotionProbe(direction: .entering)
        endTransitionSignpost(markStable: true)
    }

    private func beginExitContraction(generation: Int) {
        guard generation == transitionGeneration, transitionPhase == .exiting else { return }
        withAnimation(motionProfile.resultRevealAnimation.delay(0.08)) {
            transitionResultOpacity = 1
            transitionResultOffset = 0
            idleHeaderOpacity = 1
        }
        withAnimation(
            motionProfile.paperExitAnimation,
            completionCriteria: .removed
        ) {
            paperRevealProgress = 0
        } completion: {
            beginExitHandoff(generation: generation)
        }
    }

    private func beginExitHandoff(generation: Int) {
        guard generation == transitionGeneration, transitionPhase == .exiting else { return }
        withNoAnimation {
            draft = nil
            transitionPhase = .idle
            liveSourceOpacity = 0
            liveResultOpacity = 0
        }
        withAnimation(
            motionProfile.overlayHandoffAnimation,
            completionCriteria: .removed
        ) {
            transitionPaperOpacity = 0
            transitionResultOpacity = 0
            liveSourceOpacity = 1
            liveResultOpacity = 1
        } completion: {
            completeExitTransition(generation: generation)
        }
    }

    private func finishReducedMotionExit(generation: Int) {
        withNoAnimation {
            transitionPaperOpacity = 1
            transitionResultOpacity = 1
            transitionResultOffset = 0
            draft = nil
            transitionPhase = .idle
            paperRevealProgress = 1
            liveSourceOpacity = 0
            liveResultOpacity = 0
        }
        withAnimation(
            motionProfile.reducedMotionCrossfade,
            completionCriteria: .removed
        ) {
            transitionPaperOpacity = 0
            transitionResultOpacity = 0
            liveSourceOpacity = 1
            liveResultOpacity = 1
            idleHeaderOpacity = 1
            finishButtonProgress = 0
        } completion: {
            completeExitTransition(generation: generation)
        }
    }

    private func completeExitTransition(generation: Int) {
        guard generation == transitionGeneration, transitionPhase == .idle else { return }
        withNoAnimation {
            paperRevealProgress = 0
            transitionPaperOpacity = 0
            transitionResultOpacity = 0
            transitionResultOffset = 0
            liveSourceOpacity = 1
            liveResultOpacity = 1
            idleHeaderOpacity = 1
            finishButtonProgress = 0
        }
        completeMotionProbe(direction: .exiting)
        endTransitionSignpost(markStable: true)
    }

    private func clearActiveSource() {
        if draft != nil {
            draft?.sourceText = ""
            scheduleSourceFocus(afterNanoseconds: 0)
        } else {
            session.clearCurrent()
        }
    }

    private func presentLanguagePicker(for role: LanguageSelectionRole) {
        guard transitionPhase == .idle || transitionPhase == .editing else { return }

        guard transitionPhase == .editing else {
            if role == .source {
                onPickSource()
            } else {
                onPickTarget()
            }
            return
        }

        cancelPendingFocus()
        sourceIsFocused = false
        presentedSheet = .draftLanguage(role)
    }

    private func swapActiveLanguages() {
        guard transitionPhase == .idle || transitionPhase == .editing else { return }

        guard transitionPhase == .editing, var currentDraft = draft else {
            onSwap()
            return
        }

        let previousSource = currentDraft.sourceLanguage
        currentDraft.sourceLanguage = currentDraft.targetLanguage
        currentDraft.targetLanguage = previousSource
        draft = currentDraft
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func draftLanguageBinding(for role: LanguageSelectionRole) -> Binding<Language> {
        Binding {
            guard let draft else {
                return role == .source ? session.sourceLanguage : session.targetLanguage
            }
            return role == .source ? draft.sourceLanguage : draft.targetLanguage
        } set: { newValue in
            guard var currentDraft = draft else { return }
            if role == .source {
                currentDraft.sourceLanguage = newValue
            } else {
                currentDraft.targetLanguage = newValue
            }
            draft = currentDraft
        }
    }

    private func restoreDraftFocusIfNeeded() {
        guard transitionPhase == .editing else { return }
        scheduleSourceFocus(afterNanoseconds: 0)
    }

    private func scheduleSourceFocus(afterNanoseconds delay: UInt64) {
        cancelPendingFocus()
        pendingFocusTask = Task { @MainActor in
            if delay == 0 {
                await Task.yield()
            } else {
                try? await Task.sleep(nanoseconds: delay)
            }

            guard !Task.isCancelled,
                  transitionPhase == .entering || transitionPhase == .editing,
                  presentedSheet == nil else { return }
            pendingFocusTask = nil
            TextEntryMotionTrace.signposter.emitEvent("TextEntryFocusRequested")
            sourceIsFocused = true
        }
    }

    private func cancelPendingFocus() {
        pendingFocusTask?.cancel()
        pendingFocusTask = nil
    }

    private func beginTransitionSignpost() {
        transitionSignpostState = TextEntryMotionTrace.signposter.beginInterval("TextEntryTransition")
    }

    private func endTransitionSignpost(markStable: Bool) {
        guard let transitionSignpostState else { return }
        if markStable {
            TextEntryMotionTrace.signposter.emitEvent("TextEntryStable")
        }
        TextEntryMotionTrace.signposter.endInterval("TextEntryTransition", transitionSignpostState)
        self.transitionSignpostState = nil
    }

    private func withNoAnimation(_ updates: () -> Void) {
        withTransaction(Transaction(animation: nil), updates)
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
        beginEditingIfNeeded()
        isDictating = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        showToast("正在听写…")
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard draft != nil else {
                isDictating = false
                return
            }
            draft?.sourceText = activeSourceLanguage.code == "zh-Hans" ? "你好" : "Good morning"
            isDictating = false
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

private struct TextEntryMotionProfile {
    let reducesMotion: Bool

    var paperExpansionAnimation: Animation {
        reducesMotion
            ? .easeOut(duration: 0.12)
            : .spring(duration: 0.38, bounce: 0.12)
    }

    var paperExitAnimation: Animation {
        reducesMotion
            ? .easeOut(duration: 0.12)
            : .smooth(duration: 0.30, extraBounce: 0)
    }

    var resultExitAnimation: Animation {
        reducesMotion
            ? .easeOut(duration: 0.12)
            : .easeOut(duration: 0.14)
    }

    var resultRevealAnimation: Animation {
        .easeOut(duration: reducesMotion ? 0.12 : 0.18)
    }

    var finishButtonAnimation: Animation {
        reducesMotion
            ? .easeOut(duration: 0.12)
            : .spring(duration: 0.30, bounce: 0.22)
    }

    var overlayHandoffAnimation: Animation {
        .easeOut(duration: reducesMotion ? 0.12 : 0.08)
    }

    var reducedMotionCrossfade: Animation {
        .easeOut(duration: 0.12)
    }

    var focusDelayNanoseconds: UInt64 {
        reducesMotion ? 0 : 180_000_000
    }

    var resultExitOffset: CGFloat {
        reducesMotion ? 0 : 6
    }

    func finishButtonScale(progress: CGFloat) -> CGFloat {
        guard !reducesMotion else { return 1 }
        return 0.84 + (0.16 * progress)
    }

}

private struct TextEntryTransitionSnapshot: Equatable {
    let sourceText: String
    let sourceLanguageName: String
    let characterCount: Int
    let isDictating: Bool
    let resultLanguageName: String
    let translatedText: String
    let resultIsFavorite: Bool

    static let empty = TextEntryTransitionSnapshot(
        sourceText: "",
        sourceLanguageName: "",
        characterCount: 0,
        isDictating: false,
        resultLanguageName: "",
        translatedText: "",
        resultIsFavorite: false
    )
}

private struct TextEntryTransitionOverlay: View {
    let snapshot: TextEntryTransitionSnapshot
    let sourceFrame: CGRect
    let resultFrame: CGRect
    let paperTargetHeight: CGFloat
    let paperProgress: CGFloat
    let paperOpacity: Double
    let resultOpacity: Double
    let resultOffset: CGFloat
    let reducesMotion: Bool
    let probe: TextEntryMotionProbeToken

    private var sourceWidth: CGFloat {
        max(1, sourceFrame.width)
    }

    private var initialHeight: CGFloat {
        max(1, sourceFrame.height)
    }

    private var targetHeight: CGFloat {
        max(initialHeight, paperTargetHeight)
    }

    private var normalizedProgress: CGFloat {
        min(1, max(0, paperProgress))
    }

    private var revealHeight: CGFloat {
        initialHeight + ((targetHeight - initialHeight) * normalizedProgress)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEntryResultSnapshotView(snapshot: snapshot)
                .frame(width: max(1, resultFrame.width))
                .opacity(resultOpacity)
                .offset(
                    x: resultFrame.minX,
                    y: resultFrame.minY + resultOffset
                )

            paperLayer
                .opacity(paperOpacity)
                .offset(x: sourceFrame.minX, y: sourceFrame.minY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var paperLayer: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.045))
                .frame(width: sourceWidth, height: initialHeight)
                .blur(radius: 8)
                .offset(y: 2)
                .opacity(1 - Double(normalizedProgress))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.045))
                .frame(width: sourceWidth, height: targetHeight)
                .blur(radius: 8)
                .offset(y: 2)
                .opacity(Double(normalizedProgress))

            TextEntryPaperShape(
                progress: paperProgress,
                initialHeight: initialHeight,
                targetHeight: targetHeight,
                probe: probe
            )
            .fill(.white)
            .overlay {
                TextEntryPaperShape(
                    progress: paperProgress,
                    initialHeight: initialHeight,
                    targetHeight: targetHeight,
                    probe: .disabled
                )
                .stroke(
                    AppTheme.terracotta.opacity(0.24 * Double(normalizedProgress)),
                    lineWidth: 1.5
                )
            }

            paperContent
                .mask {
                    TextEntryPaperShape(
                        progress: paperProgress,
                        initialHeight: initialHeight,
                        targetHeight: targetHeight,
                        probe: .disabled
                    )
                }

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppTheme.terracotta.opacity(0.24))
                    .frame(height: 1.5)
                LinearGradient(
                    colors: [Color.black.opacity(0.065), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
            }
            .frame(width: max(1, sourceWidth - 16))
            .opacity(reducesMotion ? 0 : 1)
            .offset(x: 8, y: revealHeight - 1)
        }
        .frame(width: sourceWidth, height: targetHeight, alignment: .topLeading)
    }

    private var paperContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(
                text: snapshot.sourceLanguageName,
                color: AppTheme.secondaryInk
            )

            Group {
                if snapshot.sourceText.isEmpty {
                    Text("输入需要翻译的文字")
                        .foregroundStyle(AppTheme.muted)
                } else {
                    Text(snapshot.sourceText)
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .font(.system(size: 25, weight: .regular))
            .lineSpacing(7)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .clipped()
            .padding(.horizontal, 5)
            .padding(.vertical, 8)

            HStack {
                Text("\(snapshot.characterCount) 字")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.faint)

                Spacer()

                Image(systemName: snapshot.isDictating ? "waveform" : "mic")
                    .frame(width: 44, height: 44)
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(AppTheme.muted)
            .padding(.top, 2)
            .layoutPriority(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(
            width: sourceWidth,
            height: max(1, revealHeight),
            alignment: .topLeading
        )
        .clipped()
    }
}

private struct TextEntryResultSnapshotView: View {
    let snapshot: TextEntryTransitionSnapshot

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(AppTheme.terracotta)
                        .frame(width: 7, height: 7)
                    SectionLabel(
                        text: snapshot.resultLanguageName,
                        color: AppTheme.terracotta
                    )
                }

                Text(snapshot.translatedText.isEmpty ? "译文会显示在这里" : snapshot.translatedText)
                    .font(.system(size: 25, weight: .regular, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(
                        snapshot.translatedText.isEmpty
                            ? AppTheme.faint
                            : Color(hex: 0x26221D)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    snapshotActionIcon("speaker.wave.2")
                    snapshotActionIcon("doc.on.doc")
                    snapshotActionIcon(snapshot.resultIsFavorite ? "star.fill" : "star")
                    Spacer()
                    snapshotActionIcon("square.and.arrow.up")
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
            .background(
                AppTheme.terracottaSoft,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )

            Text("轻点结果可查看其他译法")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: 0xC4BBAC))
                .padding(.top, 2)
        }
    }

    private func snapshotActionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppTheme.terracotta.opacity(0.78))
            .frame(width: 36, height: 36)
            .background(AppTheme.terracotta.opacity(0.08), in: Circle())
    }
}

private struct TextEntryPaperShape: Shape {
    var progress: CGFloat
    let initialHeight: CGFloat
    let targetHeight: CGFloat
    let probe: TextEntryMotionProbeToken

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let normalizedProgress = min(1, max(0, progress))
        let resolvedInitialHeight = max(1, initialHeight)
        let resolvedTargetHeight = max(resolvedInitialHeight, targetHeight)
        let currentHeight = resolvedInitialHeight
            + ((resolvedTargetHeight - resolvedInitialHeight) * normalizedProgress)
        let paperRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(rect.height, currentHeight)
        )
#if DEBUG
        if probe.id > 0, probe.direction != .idle {
            TextEntryMotionProbe.shared.record(
                id: probe.id,
                direction: probe.direction,
                progress: normalizedProgress,
                bottomY: probe.originY + paperRect.height,
                opacity: probe.isVisible ? 1 : 0,
                geometryIsValid: rect.width > 1
                    && resolvedTargetHeight - resolvedInitialHeight >= 24
            )
        }
#endif
        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .path(in: paperRect)
    }
}

private struct TextEntryMotionProbeToken {
    let id: Int
    let direction: TextEntryMotionDirection
    let originY: CGFloat
    let isVisible: Bool

    static let disabled = TextEntryMotionProbeToken(
        id: 0,
        direction: .idle,
        originY: 0,
        isVisible: false
    )
}

private enum TextEntryMotionDirection: String {
    case idle
    case entering = "enter"
    case exiting = "exit"
}

private enum TextEntryTransitionPhase {
    case idle
    case entering
    case editing
    case exiting
}

private struct TextEntryTransitionAccessibilityModifier: ViewModifier {
    let isHidden: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isHidden {
            content.accessibilityHidden(true)
        } else {
            content
        }
    }
}

private enum TextEntryCoordinateSpace {
    static let name = "text-entry-content"
}

private struct TextEntrySourceLayoutMeasurement: Equatable {
    let generation: Int
    let validationPass: Int
    let frame: CGRect
    let viewportSize: CGSize
}

private enum TextEntryMotionTrace {
    static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "TranslationPrototype",
        category: "TextEntryMotion"
    )
}

#if DEBUG
private struct TextEntryMotionProbeAccessibilityView: UIViewRepresentable {
    let reducesMotion: Bool

    func makeUIView(context: Context) -> TextEntryMotionProbeAXView {
        let view = TextEntryMotionProbeAXView()
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "text-entry-motion-probe"
        view.accessibilityLabel = "文字键入动画探针"
        view.backgroundColor = .clear
        TextEntryMotionProbe.shared.setReducesMotion(reducesMotion)
        TextEntryMotionProbeAXRegistry.shared.attach(view)
        return view
    }

    func updateUIView(_ uiView: TextEntryMotionProbeAXView, context: Context) {
        TextEntryMotionProbe.shared.setReducesMotion(reducesMotion)
        TextEntryMotionProbeAXRegistry.shared.attach(uiView)
    }

    static func dismantleUIView(_ uiView: TextEntryMotionProbeAXView, coordinator: Void) {
        TextEntryMotionProbeAXRegistry.shared.detach(uiView)
    }
}

private final class TextEntryMotionProbeAXView: UIView {
    override var accessibilityValue: String? {
        get { TextEntryMotionProbe.shared.accessibilityValue }
        set {}
    }
}

@MainActor
private final class TextEntryMotionProbeAXRegistry {
    static let shared = TextEntryMotionProbeAXRegistry()
    private weak var view: UIView?

    func attach(_ view: UIView) {
        self.view = view
    }

    func detach(_ view: UIView) {
        if self.view === view {
            self.view = nil
        }
    }

    func postChange() {
        guard view != nil else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}

private final class TextEntryMotionProbe: @unchecked Sendable {
    static let shared = TextEntryMotionProbe()

    private struct Sample {
        let progress: CGFloat
        let bottomY: CGFloat
        let opacity: Double
        let geometryIsValid: Bool
    }

    private struct Track {
        var id = 0
        var initialBottomY: CGFloat = 0
        var expectedBottomY: CGFloat?
        var samples: [Sample] = []
        var isComplete = false

        mutating func append(_ sample: Sample) {
            guard samples.count < 240 else { return }
            if let last = samples.last,
               abs(last.progress - sample.progress) < 0.005,
               abs(last.bottomY - sample.bottomY) < 0.5 {
                return
            }
            samples.append(sample)
        }

        func evaluation(for direction: TextEntryMotionDirection) -> Evaluation {
            guard let expectedBottomY else {
                return .empty
            }

            let validSamples = samples.filter {
                $0.opacity > 0.01
                    && $0.geometryIsValid
                    && $0.bottomY.isFinite
            }
            let signedDistance = direction == .entering
                ? expectedBottomY - initialBottomY
                : initialBottomY - expectedBottomY
            let distance = max(0, signedDistance)
            guard distance >= 24 else {
                return Evaluation(
                    sawStart: false,
                    sawMiddle: false,
                    sawEnd: false,
                    steps: 0,
                    geometryIsValid: false,
                    isMonotonic: false,
                    distance: distance,
                    passed: false
                )
            }

            let normalizedPositions = validSamples.map { sample -> CGFloat in
                let travelled = direction == .entering
                    ? sample.bottomY - initialBottomY
                    : initialBottomY - sample.bottomY
                return min(1, max(0, travelled / distance))
            }
            let sawStart = normalizedPositions.contains { $0 <= 0.12 }
            let sawMiddle = normalizedPositions.contains { $0 > 0.12 && $0 < 0.88 }
            let sawEnd = normalizedPositions.contains { $0 >= 0.88 }
            let steps = Set(normalizedPositions.map { Int(($0 * 20).rounded()) }).count
            let regressionTolerance = max(3, distance * 0.04)
            var extreme = initialBottomY
            var isMonotonic = true
            for sample in validSamples {
                if direction == .entering {
                    if sample.bottomY < extreme - regressionTolerance {
                        isMonotonic = false
                        break
                    }
                    extreme = max(extreme, sample.bottomY)
                } else {
                    if sample.bottomY > extreme + regressionTolerance {
                        isMonotonic = false
                        break
                    }
                    extreme = min(extreme, sample.bottomY)
                }
            }

            return Evaluation(
                sawStart: sawStart,
                sawMiddle: sawMiddle,
                sawEnd: sawEnd,
                steps: steps,
                geometryIsValid: !validSamples.isEmpty,
                isMonotonic: isMonotonic,
                distance: distance,
                passed: isComplete
                    && sawStart
                    && sawMiddle
                    && sawEnd
                    && steps >= 3
                    && isMonotonic
            )
        }
    }

    private struct Evaluation {
        let sawStart: Bool
        let sawMiddle: Bool
        let sawEnd: Bool
        let steps: Int
        let geometryIsValid: Bool
        let isMonotonic: Bool
        let distance: CGFloat
        let passed: Bool

        static let empty = Evaluation(
            sawStart: false,
            sawMiddle: false,
            sawEnd: false,
            steps: 0,
            geometryIsValid: false,
            isMonotonic: false,
            distance: 0,
            passed: false
        )
    }

    private let lock = NSLock()
    private let enabled = ProcessInfo.processInfo.arguments.contains(
        "--ui-testing-text-entry-motion-probe"
    )
    private var reducesMotion = false
    private var enterTrack = Track()
    private var exitTrack = Track()

    var accessibilityValue: String {
        lock.lock()
        defer { lock.unlock() }
        let enter = enterTrack.evaluation(for: .entering)
        let exit = exitTrack.evaluation(for: .exiting)
        return [
            "reduce=\(reducesMotion ? 1 : 0)",
            summary(name: "enter", track: enterTrack, evaluation: enter),
            summary(name: "exit", track: exitTrack, evaluation: exit)
        ].joined(separator: ";")
    }

    func setReducesMotion(_ reducesMotion: Bool) {
        guard enabled else { return }
        lock.lock()
        self.reducesMotion = reducesMotion
        lock.unlock()
    }

    func begin(
        id: Int,
        direction: TextEntryMotionDirection,
        reducesMotion: Bool,
        initialBottomY: CGFloat
    ) {
        guard enabled else { return }
        lock.lock()
        self.reducesMotion = reducesMotion
        switch direction {
        case .entering:
            enterTrack = Track(id: id, initialBottomY: initialBottomY)
        case .exiting:
            exitTrack = Track(id: id, initialBottomY: initialBottomY)
        case .idle:
            break
        }
        lock.unlock()
        scheduleAccessibilityUpdate()
    }

    func record(
        id: Int,
        direction: TextEntryMotionDirection,
        progress: CGFloat,
        bottomY: CGFloat,
        opacity: Double,
        geometryIsValid: Bool
    ) {
        guard enabled else { return }
        let sample = Sample(
            progress: min(1, max(0, progress)),
            bottomY: bottomY,
            opacity: opacity,
            geometryIsValid: geometryIsValid
        )
        lock.lock()
        switch direction {
        case .entering where enterTrack.id == id:
            enterTrack.append(sample)
        case .exiting where exitTrack.id == id:
            exitTrack.append(sample)
        default:
            break
        }
        lock.unlock()
    }

    func complete(
        id: Int,
        direction: TextEntryMotionDirection,
        expectedBottomY: CGFloat
    ) {
        guard enabled else { return }
        lock.lock()
        switch direction {
        case .entering where enterTrack.id == id:
            enterTrack.expectedBottomY = expectedBottomY
            enterTrack.isComplete = true
        case .exiting where exitTrack.id == id:
            exitTrack.expectedBottomY = expectedBottomY
            exitTrack.isComplete = true
        default:
            break
        }
        lock.unlock()
        scheduleAccessibilityUpdate()
    }

    private func summary(
        name: String,
        track: Track,
        evaluation: Evaluation
    ) -> String {
        let state = track.id == 0 ? "idle" : (track.isComplete ? "complete" : "running")
        return "\(name)-state=\(state)"
            + ";\(name)-id=\(track.id)"
            + ";\(name)-start=\(evaluation.sawStart ? 1 : 0)"
            + ";\(name)-mid=\(evaluation.sawMiddle ? 1 : 0)"
            + ";\(name)-end=\(evaluation.sawEnd ? 1 : 0)"
            + ";\(name)-steps=\(evaluation.steps)"
            + ";\(name)-geometry=\(evaluation.geometryIsValid ? 1 : 0)"
            + ";\(name)-monotonic=\(evaluation.isMonotonic ? 1 : 0)"
            + ";\(name)-delta=\(Int(evaluation.distance.rounded()))"
            + ";\(name)-pass=\(evaluation.passed ? 1 : 0)"
    }

    private func scheduleAccessibilityUpdate() {
        Task { @MainActor in
            TextEntryMotionProbeAXRegistry.shared.postChange()
        }
    }
}
#endif

private struct IdleResultFramePreferenceKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private enum TextTranslateSheet: Identifiable {
    case alternatives
    case draftLanguage(LanguageSelectionRole)

    var id: String {
        switch self {
        case .alternatives:
            return "alternatives"
        case .draftLanguage(let role):
            return "draft-language-\(role.rawValue)"
        }
    }
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
        onSwap: {},
        onPickSource: {},
        onPickTarget: {},
        onHistory: {},
        onSettings: {}
    )
}
