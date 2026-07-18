import Foundation

/// 可切换的翻译引擎。后续接入自研模型与 LLM 翻译时在此扩展。
enum TranslationEngine: String, CaseIterable, Identifiable {
    case google
    case custom
    case llm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: "谷歌翻译"
        case .custom: "自研模型"
        case .llm: "LLM 翻译"
        }
    }

    var subtitle: String {
        switch self {
        case .google: "免费 · 在线翻译"
        case .custom: "端侧离线 · 更快更私密"
        case .llm: "自带 API Key · 更高质量"
        }
    }

    var isAvailable: Bool {
        self == .google
    }

    func makeService() -> any TranslationService {
        switch self {
        case .google: GoogleTranslateService()
        // 未接入的引擎在 UI 中不可选；防御性回退到谷歌翻译。
        case .custom, .llm: GoogleTranslateService()
        }
    }
}

struct TranslationRequest: Equatable {
    let text: String
    let source: Language
    let target: Language
}

struct TranslationResult: Equatable {
    let text: String
    let detectedLanguage: Language?
    let alternatives: [String]
}

enum TranslationError: LocalizedError, Equatable {
    case network
    case rateLimited
    case serverError(Int)
    case invalidResponse
    case textTooLong

    var errorDescription: String? {
        switch self {
        case .network: "网络连接失败，请检查网络后重试"
        case .rateLimited: "请求过于频繁，请稍后再试"
        case .serverError(let code): "翻译服务暂时不可用（HTTP \(code)）"
        case .invalidResponse: "无法解析翻译结果，请重试"
        case .textTooLong: "文本过长，请缩短后重试"
        }
    }
}

protocol TranslationService: Sendable {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult
}

/// 原型阶段的本地演示译文，UI 测试通过 --prototype-canned-translation 注入，
/// 保持既有测试断言的固定输出。
struct CannedTranslationService: TranslationService {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        let translation = cannedTranslation(
            for: request.text,
            sourceCode: request.source.code,
            target: request.target
        )
        return TranslationResult(
            text: translation,
            detectedLanguage: request.source.isAuto ? detectLanguage(of: request.text) : nil,
            alternatives: cannedAlternatives(for: request.text, translation: translation, target: request.target)
        )
    }

    private func cannedTranslation(for text: String, sourceCode: String, target: Language) -> String {
        switch (sourceCode, target.code, text) {
        case ("zh-Hans", "en", "今天的晚霞特别好看，我想和你一起去海边走走。"):
            return "The sunset is especially beautiful today — I'd love to take a walk along the beach with you."
        case ("en", "zh-Hans", "The sunset is especially beautiful today — I'd love to take a walk along the beach with you."):
            return "今天的晚霞特别好看，我想和你一起去海边走走。"
        case ("zh-Hans", "en", "你好"):
            return "Hello"
        case ("en", "zh-Hans", "Good morning"):
            return "早上好"
        case ("zh-Hans", "ja", "谢谢你的款待。"):
            return "おもてなしをありがとう。"
        default:
            return fallbackTranslation(for: text, target: target)
        }
    }

    private func fallbackTranslation(for text: String, target: Language) -> String {
        switch target.code {
        case "en":
            return "A natural translation of “\(text)”"
        case "zh-Hans":
            return "“\(text)” 的自然译文"
        case "ja":
            return "「\(text)」の自然な翻訳"
        default:
            return "[\(target.nativeName)] \(text)"
        }
    }

    private func cannedAlternatives(for text: String, translation: String, target: Language) -> [String] {
        if text.contains("晚霞") && target.code == "en" {
            return [
                "Today's sunset is breathtaking — I'd love to walk along the beach with you.",
                "The evening sky looks especially beautiful today. Shall we take a walk by the sea?"
            ]
        }
        return [
            "\(translation) (更自然)",
            "\(translation) (更简洁)"
        ]
    }

    private func detectLanguage(of text: String) -> Language {
        let containsCJK = text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
        return containsCJK ? .chinese : .english
    }
}
