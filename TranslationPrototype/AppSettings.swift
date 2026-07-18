import Foundation
import Observation

/// 全局偏好，UserDefaults 持久化。设置页写入，翻译流程读取。
@Observable
final class AppSettings {
    private static let engineKey = "settings.translationEngine"
    private static let autoSpeakKey = "settings.autoSpeaksTranslation"
    private static let sourceLanguageKey = "settings.lastSourceLanguageCode"
    private static let targetLanguageKey = "settings.lastTargetLanguageCode"

    @ObservationIgnored private let defaults: UserDefaults

    var translationEngine: TranslationEngine {
        didSet { defaults.set(translationEngine.rawValue, forKey: Self.engineKey) }
    }

    var autoSpeaksTranslation: Bool {
        didSet { defaults.set(autoSpeaksTranslation, forKey: Self.autoSpeakKey) }
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
        if ProcessInfo.processInfo.arguments.contains("--prototype-reset-settings") {
            [Self.engineKey, Self.autoSpeakKey, Self.sourceLanguageKey, Self.targetLanguageKey]
                .forEach(defaults.removeObject(forKey:))
        }
#endif
        translationEngine = defaults.string(forKey: Self.engineKey)
            .flatMap(TranslationEngine.init(rawValue:)) ?? .google
        autoSpeaksTranslation = defaults.bool(forKey: Self.autoSpeakKey)
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
