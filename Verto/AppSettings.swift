import Foundation
import Observation

/// 语音对话页的译文朗读行为。文字页沿用 autoSpeaksTranslation，互不影响。
enum VoicePlaybackMode: String, CaseIterable, Identifiable {
    case textOnly
    case speakAfterTranslation
    case speakOnlyWithHeadphones

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .textOnly: "仅显示文字"
        case .speakAfterTranslation: "翻译完自动朗读"
        case .speakOnlyWithHeadphones: "仅戴耳机时朗读"
        }
    }

    var subtitle: String {
        switch self {
        case .textOnly: "不自动播放语音"
        case .speakAfterTranslation: "每句译文完成后自动播放"
        case .speakOnlyWithHeadphones: "连接耳机时才自动播放"
        }
    }
}

/// 全局外观模式。设置页写入，AppShell 应用 preferredColorScheme。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var subtitle: String {
        switch self {
        case .system: "与系统外观保持一致"
        case .light: "始终使用浅色外观"
        case .dark: "始终使用深色外观"
        }
    }
}

/// 全局偏好，UserDefaults 持久化。设置页写入，翻译流程读取。
@Observable
final class AppSettings {
    private static let engineKey = "settings.translationEngine"
    private static let appearanceKey = "settings.appearanceMode"
    private static let autoSpeakKey = "settings.autoSpeaksTranslation"
    private static let voicePlaybackKey = "settings.voicePlaybackMode"
    private static let sourceLanguageKey = "settings.lastSourceLanguageCode"
    private static let targetLanguageKey = "settings.lastTargetLanguageCode"

    @ObservationIgnored private let defaults: UserDefaults

    var translationEngine: TranslationEngine {
        didSet { defaults.set(translationEngine.rawValue, forKey: Self.engineKey) }
    }

    var autoSpeaksTranslation: Bool {
        didSet { defaults.set(autoSpeaksTranslation, forKey: Self.autoSpeakKey) }
    }

    var voicePlaybackMode: VoicePlaybackMode {
        didSet { defaults.set(voicePlaybackMode.rawValue, forKey: Self.voicePlaybackKey) }
    }

    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Self.appearanceKey) }
    }

    var lastSourceLanguageCode: String? {
        didSet { persist(lastSourceLanguageCode, forKey: Self.sourceLanguageKey) }
    }

    var lastTargetLanguageCode: String? {
        didSet { persist(lastTargetLanguageCode, forKey: Self.targetLanguageKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-reset-settings") {
            [Self.engineKey, Self.appearanceKey, Self.autoSpeakKey, Self.voicePlaybackKey, Self.sourceLanguageKey, Self.targetLanguageKey]
                .forEach(defaults.removeObject(forKey:))
        }
#endif
        translationEngine = defaults.string(forKey: Self.engineKey)
            .flatMap(TranslationEngine.init(rawValue:)) ?? .google
        autoSpeaksTranslation = defaults.bool(forKey: Self.autoSpeakKey)
        voicePlaybackMode = defaults.string(forKey: Self.voicePlaybackKey)
            .flatMap(VoicePlaybackMode.init(rawValue:)) ?? .speakAfterTranslation
        appearanceMode = defaults.string(forKey: Self.appearanceKey)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        lastSourceLanguageCode = defaults.string(forKey: Self.sourceLanguageKey)
        lastTargetLanguageCode = defaults.string(forKey: Self.targetLanguageKey)
    }

    var storedSourceLanguage: Language? {
        language(forCode: lastSourceLanguageCode)
    }

    var storedTargetLanguage: Language? {
        language(forCode: lastTargetLanguageCode)
    }

    private func language(forCode code: String?) -> Language? {
        guard let code else { return nil }
        if code == Language.auto.code {
            return .auto
        }
        return Language.all.first { $0.code == code }
    }

    private func persist(_ value: String?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
