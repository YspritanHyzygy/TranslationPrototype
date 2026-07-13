import Foundation
import Observation
import SwiftUI

enum AppMode: String, CaseIterable, Identifiable {
    case text
    case voice
    case camera

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "文字"
        case .voice: "语音"
        case .camera: "相机"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "textformat"
        case .voice: "mic"
        case .camera: "camera"
        }
    }

    var next: AppMode {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var previous: AppMode {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + all.count - 1) % all.count]
    }
}

enum LanguageSelectionRole: String, Identifiable {
    case source
    case target

    var id: String { rawValue }

    var title: String {
        switch self {
        case .source: "翻译自"
        case .target: "翻译到"
        }
    }
}

enum SheetDestination: Identifiable {
    case language(LanguageSelectionRole)
    case history

    var id: String {
        switch self {
        case .language(let role): "language-\(role.rawValue)"
        case .history: "history"
        }
    }
}

struct Language: Identifiable, Equatable, Hashable {
    let code: String
    let nativeName: String
    let chineseName: String

    var id: String { code }

    static let chinese = Language(code: "zh-Hans", nativeName: "中文", chineseName: "简体中文")
    static let english = Language(code: "en", nativeName: "English", chineseName: "英语")
    static let japanese = Language(code: "ja", nativeName: "日本語", chineseName: "日语")

    static let recent: [Language] = [.english, .chinese]

    static let all: [Language] = [
        .english,
        .chinese,
        .japanese,
        Language(code: "ko", nativeName: "한국어", chineseName: "韩语"),
        Language(code: "fr", nativeName: "Français", chineseName: "法语"),
        Language(code: "es", nativeName: "Español", chineseName: "西班牙语"),
        Language(code: "de", nativeName: "Deutsch", chineseName: "德语")
    ]
}

struct ConversationTurn: Identifiable {
    enum Speaker {
        case source
        case target
    }

    let id: UUID
    let speaker: Speaker
    let language: String
    let original: String
    let translation: String

    init(
        id: UUID = UUID(),
        speaker: Speaker,
        language: String,
        original: String,
        translation: String
    ) {
        self.id = id
        self.speaker = speaker
        self.language = language
        self.original = original
        self.translation = translation
    }

    static let samples: [ConversationTurn] = [
        ConversationTurn(
            speaker: .source,
            language: "English",
            original: "Excuse me, where's the nearest subway station?",
            translation: "请问，最近的地铁站在哪里？"
        ),
        ConversationTurn(
            speaker: .target,
            language: "中文",
            original: "往前走两个路口，地铁站就在右手边。",
            translation: "Go straight for two blocks, the station is on your right."
        ),
        ConversationTurn(
            speaker: .source,
            language: "English",
            original: "Perfect, thank you so much!",
            translation: "太好了，非常感谢！"
        )
    ]
}

struct MenuTranslation: Identifiable {
    let id = UUID()
    let source: String
    let result: String
    let price: String

    static let samples: [MenuTranslation] = [
        MenuTranslation(source: "红烧牛肉面", result: "Braised Beef Noodles", price: "¥38"),
        MenuTranslation(source: "宫保鸡丁", result: "Kung Pao Chicken", price: "¥32"),
        MenuTranslation(source: "麻婆豆腐", result: "Mapo Tofu", price: "¥26")
    ]
}

struct HistoryItem: Identifiable, Equatable {
    let id: UUID
    let dayLabel: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let source: String
    let result: String
    var isFavorite: Bool

    var direction: String {
        "\(sourceLanguage.nativeName) → \(targetLanguage.nativeName)"
    }

    init(
        id: UUID = UUID(),
        dayLabel: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        source: String,
        result: String,
        isFavorite: Bool
    ) {
        self.id = id
        self.dayLabel = dayLabel
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.source = source
        self.result = result
        self.isFavorite = isFavorite
    }

    static let today: [HistoryItem] = [
        HistoryItem(
            dayLabel: "今天",
            sourceLanguage: .chinese,
            targetLanguage: .english,
            source: "今天的晚霞特别好看。",
            result: "The sunset is especially beautiful today.",
            isFavorite: true
        ),
        HistoryItem(
            dayLabel: "今天",
            sourceLanguage: .english,
            targetLanguage: .chinese,
            source: "Where's the nearest subway station?",
            result: "最近的地铁站在哪里？",
            isFavorite: false
        )
    ]

    static let yesterday: [HistoryItem] = [
        HistoryItem(
            dayLabel: "昨天",
            sourceLanguage: .chinese,
            targetLanguage: .japanese,
            source: "谢谢你的款待。",
            result: "おもてなしをありがとう。",
            isFavorite: false
        )
    ]
}

@Observable
final class TranslationSession {
    var sourceLanguage: Language = .chinese
    var targetLanguage: Language = .english
    var sourceText = "今天的晚霞特别好看，我想和你一起去海边走走。"
    var translatedText = "The sunset is especially beautiful today — I'd love to take a walk along the beach with you."
    var historyItems: [HistoryItem] = HistoryItem.today + HistoryItem.yesterday

    var characterCount: Int {
        sourceText.filter { !$0.isWhitespace }.count
    }

    var isCurrentFavorite: Bool {
        historyItems.first {
            $0.source == sourceText
                && $0.result == translatedText
                && $0.sourceLanguage == sourceLanguage
                && $0.targetLanguage == targetLanguage
        }?.isFavorite == true
    }

    var alternatives: [String] {
        guard !translatedText.isEmpty else { return [] }
        if sourceText.contains("晚霞") && targetLanguage.code == "en" {
            return [
                translatedText,
                "Today's sunset is breathtaking — I'd love to walk along the beach with you.",
                "The evening sky looks especially beautiful today. Shall we take a walk by the sea?"
            ]
        }
        return [
            translatedText,
            "\(translatedText) (更自然)",
            "\(translatedText) (更简洁)"
        ]
    }

    func refreshTranslation() {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            translatedText = ""
            return
        }

        switch (sourceLanguage.code, targetLanguage.code, text) {
        case ("zh-Hans", "en", "今天的晚霞特别好看，我想和你一起去海边走走。"):
            translatedText = "The sunset is especially beautiful today — I'd love to take a walk along the beach with you."
        case ("en", "zh-Hans", "The sunset is especially beautiful today — I'd love to take a walk along the beach with you."):
            translatedText = "今天的晚霞特别好看，我想和你一起去海边走走。"
        case ("zh-Hans", "en", "你好"):
            translatedText = "Hello"
        case ("en", "zh-Hans", "Good morning"):
            translatedText = "早上好"
        case ("zh-Hans", "ja", "谢谢你的款待。"):
            translatedText = "おもてなしをありがとう。"
        default:
            translatedText = fallbackTranslation(for: text)
        }
    }

    func swapLanguages() {
        let oldSource = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = oldSource
        sourceText = translatedText
        refreshTranslation()
    }

    func select(_ language: Language, for role: LanguageSelectionRole) {
        if role == .source {
            sourceLanguage = language
        } else {
            targetLanguage = language
        }
        refreshTranslation()
    }

    func saveCurrent(favorite: Bool? = nil) {
        guard !sourceText.isEmpty, !translatedText.isEmpty else { return }
        if let index = historyItems.firstIndex(where: {
            $0.source == sourceText
                && $0.result == translatedText
                && $0.sourceLanguage == sourceLanguage
                && $0.targetLanguage == targetLanguage
        }) {
            if let favorite {
                historyItems[index].isFavorite = favorite
            }
            return
        }

        historyItems.insert(
            HistoryItem(
                dayLabel: "今天",
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                source: sourceText,
                result: translatedText,
                isFavorite: favorite ?? false
            ),
            at: 0
        )
    }

    func toggleFavorite(for id: UUID) {
        guard let index = historyItems.firstIndex(where: { $0.id == id }) else { return }
        historyItems[index].isFavorite.toggle()
    }

    func toggleCurrentFavorite() {
        saveCurrent(favorite: !isCurrentFavorite)
    }

    func load(_ item: HistoryItem) {
        sourceLanguage = item.sourceLanguage
        targetLanguage = item.targetLanguage
        sourceText = item.source
        translatedText = item.result
    }

    private func fallbackTranslation(for text: String) -> String {
        switch targetLanguage.code {
        case "en":
            return "A natural translation of “\(text)”"
        case "zh-Hans":
            return "“\(text)” 的自然译文"
        case "ja":
            return "「\(text)」の自然な翻訳"
        default:
            return "[\(targetLanguage.nativeName)] \(text)"
        }
    }
}
