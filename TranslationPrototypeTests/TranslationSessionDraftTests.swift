import XCTest
@testable import TranslationPrototype

final class TranslationSessionDraftTests: XCTestCase {
    func testDraftChangesStayIsolatedUntilCommit() {
        let session = TranslationSession()
        let committedSourceText = session.sourceText
        let committedTranslation = session.translatedText
        let committedSourceLanguage = session.sourceLanguage
        let committedTargetLanguage = session.targetLanguage

        var draft = session.makeTextDraft()
        draft.sourceText = "Good morning"
        draft.sourceLanguage = .english
        draft.targetLanguage = .japanese

        XCTAssertEqual(session.sourceText, committedSourceText)
        XCTAssertEqual(session.translatedText, committedTranslation)
        XCTAssertEqual(session.sourceLanguage, committedSourceLanguage)
        XCTAssertEqual(session.targetLanguage, committedTargetLanguage)

        session.commitAndTranslate(draft)

        XCTAssertEqual(session.sourceText, "Good morning")
        XCTAssertEqual(session.sourceLanguage, .english)
        XCTAssertEqual(session.targetLanguage, .japanese)
        XCTAssertEqual(session.translatedText, "「Good morning」の自然な翻訳")
    }

    func testCommittingEmptyDraftClearsCurrentTranslation() {
        let session = TranslationSession()
        var draft = session.makeTextDraft()
        draft.sourceText = "\n  "

        session.commitAndTranslate(draft)

        XCTAssertEqual(session.sourceText, "\n  ")
        XCTAssertTrue(session.translatedText.isEmpty)
    }
}
