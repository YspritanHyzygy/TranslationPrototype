import XCTest
@testable import Verto

final class LanguageSpeechLocaleTests: XCTestCase {
    func testSpeechLocaleIdentifiers() {
        XCTAssertEqual(Language.chinese.speechLocaleIdentifier, "zh-CN")
        XCTAssertEqual(Language.english.speechLocaleIdentifier, "en-US")
        XCTAssertEqual(Language.japanese.speechLocaleIdentifier, "ja-JP")
        XCTAssertEqual(
            Language(code: "ko", nativeName: "한국어", chineseName: "韩语").speechLocaleIdentifier,
            "ko-KR"
        )
    }

    func testResolvedForVoiceMapsAutoToConcreteLanguage() {
        XCTAssertEqual(Language.auto.resolvedForVoice(counterpart: .english), .chinese)
        XCTAssertEqual(Language.auto.resolvedForVoice(counterpart: .chinese), .english)
    }

    func testResolvedForVoicePassesThroughConcreteLanguage() {
        XCTAssertEqual(Language.japanese.resolvedForVoice(counterpart: .chinese), .japanese)
        XCTAssertEqual(Language.english.resolvedForVoice(counterpart: .chinese), .english)
    }

    func testLanguageScorerPrefersMatchingScript() {
        let candidates: [Language] = [.chinese, .english]
        let zhForChinese = TranscriptionLanguageScorer.score(text: "你好早上好", language: .chinese, candidates: candidates)
        let zhForEnglish = TranscriptionLanguageScorer.score(text: "你好早上好", language: .english, candidates: candidates)
        XCTAssertGreaterThan(zhForChinese, zhForEnglish)

        let enForEnglish = TranscriptionLanguageScorer.score(text: "Good morning everyone", language: .english, candidates: candidates)
        let enForChinese = TranscriptionLanguageScorer.score(text: "Good morning everyone", language: .chinese, candidates: candidates)
        XCTAssertGreaterThan(enForEnglish, enForChinese)
    }

    func testLanguageScorerConfidenceBreaksTies() {
        let candidates: [Language] = [.chinese, .english]
        let low = TranscriptionLanguageScorer.score(text: "OK", language: .english, candidates: candidates, confidence: 0.1)
        let high = TranscriptionLanguageScorer.score(text: "OK", language: .english, candidates: candidates, confidence: 0.9)
        XCTAssertGreaterThan(high, low)
    }

    func testWinnerIndexHysteresis() {
        XCTAssertEqual(TranscriptionLanguageScorer.winnerIndex(current: nil, scores: [0.5, 0.1]), 0)
        // 挑战者未超过滞回阈值：维持现任，防止逐字闪烁。
        XCTAssertEqual(TranscriptionLanguageScorer.winnerIndex(current: 0, scores: [0.5, 0.55]), 0)
        XCTAssertEqual(TranscriptionLanguageScorer.winnerIndex(current: 0, scores: [0.5, 0.9]), 1)
        XCTAssertNil(TranscriptionLanguageScorer.winnerIndex(current: nil, scores: [0, 0]))
        XCTAssertEqual(TranscriptionLanguageScorer.winnerIndex(current: 1, scores: []), 1)
    }
}
