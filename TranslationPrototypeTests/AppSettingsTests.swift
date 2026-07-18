import XCTest
@testable import TranslationPrototype

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultValues() {
        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.translationEngine, .google)
        XCTAssertFalse(settings.autoSpeaksTranslation)
        XCTAssertNil(settings.lastSourceLanguageCode)
        XCTAssertNil(settings.lastTargetLanguageCode)
        XCTAssertNil(settings.storedSourceLanguage)
        XCTAssertNil(settings.storedTargetLanguage)
    }

    func testRoundTripPersistence() {
        let settings = AppSettings(defaults: defaults)
        settings.autoSpeaksTranslation = true
        settings.lastSourceLanguageCode = "en"
        settings.lastTargetLanguageCode = "zh-Hans"

        let reloaded = AppSettings(defaults: defaults)

        XCTAssertEqual(reloaded.translationEngine, .google)
        XCTAssertTrue(reloaded.autoSpeaksTranslation)
        XCTAssertEqual(reloaded.storedSourceLanguage, .english)
        XCTAssertEqual(reloaded.storedTargetLanguage, .chinese)
    }

    func testUnknownEngineRawValueFallsBackToGoogle() {
        defaults.set("bing", forKey: "settings.translationEngine")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.translationEngine, .google)
    }

    func testStoredLanguageResolution() {
        let settings = AppSettings(defaults: defaults)

        settings.lastSourceLanguageCode = "auto"
        XCTAssertEqual(settings.storedSourceLanguage, .auto)

        settings.lastSourceLanguageCode = "xx"
        XCTAssertNil(settings.storedSourceLanguage)

        settings.lastSourceLanguageCode = nil
        XCTAssertNil(settings.storedSourceLanguage)
        XCTAssertNil(defaults.string(forKey: "settings.lastSourceLanguageCode"))
    }

    func testOnlyAvailableEnginesAreSelectableInCatalog() {
        XCTAssertEqual(TranslationEngine.allCases.filter(\.isAvailable), [.google])
    }
}
