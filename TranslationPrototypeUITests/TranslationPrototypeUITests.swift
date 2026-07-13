import XCTest

final class TranslationPrototypeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTextDictationProducesResultAndFavoriteAppearsInHistory() throws {
        let app = launchApp(mode: "text")

        let sourceEditor = element("source-text-editor", in: app)
        let translationResult = element("translation-result", in: app)
        let clearButton = element("clear-source-button", in: app)
        let dictationButton = element("dictation-button", in: app)

        XCTAssertTrue(sourceEditor.waitForExistence(timeout: 3))
        XCTAssertTrue(translationResult.waitForExistence(timeout: 3))
        XCTAssertTrue(clearButton.waitForExistence(timeout: 3))
        clearButton.tap()

        XCTAssertTrue(wait(for: NSPredicate(format: "value == %@", ""), on: sourceEditor))
        XCTAssertFalse(translationResult.isEnabled)

        XCTAssertTrue(dictationButton.waitForExistence(timeout: 2))
        dictationButton.tap()

        XCTAssertTrue(wait(for: NSPredicate(format: "value == %@", "你好"), on: sourceEditor, timeout: 4))
        XCTAssertTrue(wait(for: NSPredicate(format: "enabled == YES"), on: translationResult))

        let favoriteButton = element("favorite-result-button", in: app)
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 2))
        XCTAssertEqual(favoriteButton.label, "收藏译文")
        favoriteButton.tap()
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", "取消收藏"), on: favoriteButton))

        let historyButton = element("history-button", in: app)
        XCTAssertTrue(historyButton.waitForExistence(timeout: 2))
        historyButton.tap()

        XCTAssertTrue(app.staticTexts["历史记录"].waitForExistence(timeout: 3))
        let favoritesFilter = element("history-favorites-filter", in: app)
        XCTAssertTrue(favoritesFilter.waitForExistence(timeout: 2))
        favoritesFilter.tap()

        let savedHistoryItem = app.buttons
            .matching(NSPredicate(format: "label == %@", "载入翻译：你好"))
            .firstMatch
        XCTAssertTrue(savedHistoryItem.waitForExistence(timeout: 3))
        savedHistoryItem.tap()

        XCTAssertTrue(sourceEditor.waitForExistence(timeout: 3))
        XCTAssertTrue(wait(for: NSPredicate(format: "value == %@", "你好"), on: sourceEditor))
        XCTAssertTrue(translationResult.isEnabled)
    }

    @MainActor
    func testLanguageSearchAndTargetSelection() throws {
        let app = launchApp(mode: "text", sheet: "language-target")

        XCTAssertTrue(app.staticTexts["选择语言"].waitForExistence(timeout: 3))
        let searchField = element("languagePicker.searchField", in: app)
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("ja")

        let japanese = element("languagePicker.language.ja", in: app)
        XCTAssertTrue(japanese.waitForExistence(timeout: 3))
        japanese.tap()

        XCTAssertFalse(app.staticTexts["选择语言"].waitForExistence(timeout: 2))
        let selectedTarget = app.buttons
            .matching(NSPredicate(format: "label == %@", "日本語"))
            .firstMatch
        XCTAssertTrue(selectedTarget.waitForExistence(timeout: 3))
    }

    @MainActor
    func testVoicePauseResumeAddsConversationTurn() throws {
        let app = launchApp(mode: "voice")

        let microphone = element("conversation-microphone-button", in: app)
        let listeningStatus = element("conversation-listening-status", in: app)
        XCTAssertTrue(microphone.waitForExistence(timeout: 3))
        XCTAssertTrue(listeningStatus.waitForExistence(timeout: 3))
        XCTAssertEqual(microphone.label, "暂停聆听")

        microphone.tap()
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", "已暂停 · 轻点继续"), on: listeningStatus))
        XCTAssertEqual(microphone.label, "开始聆听")

        microphone.tap()
        // XCUITest waits for the prototype's 0.85 second processing task to become
        // idle, so the observable stable state is the resumed listening state.
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", "正在聆听 · English"), on: listeningStatus, timeout: 4))

        let addedTurn = firstElement(containingLabel: "Could you recommend a good local restaurant?", in: app)
        XCTAssertTrue(addedTurn.waitForExistence(timeout: 3))
    }

    @MainActor
    func testCameraShutterShowsRecognizedMenuResults() throws {
        let app = launchApp(mode: "camera")

        let shutter = element("camera.shutterButton", in: app)
        XCTAssertTrue(shutter.waitForExistence(timeout: 3))
        shutter.tap()

        // As with voice processing, the loading state completes before XCUI's
        // post-tap idle wait returns. Verify the stable recognized state and data.
        let recognizedTitle = element("camera.recognitionTitle", in: app)
        XCTAssertTrue(recognizedTitle.waitForExistence(timeout: 4))
        XCTAssertTrue(shutter.isEnabled)

        let recognizedResult = firstElement(containingLabel: "Braised Beef Noodles", in: app)
        XCTAssertTrue(recognizedResult.waitForExistence(timeout: 2))
    }

    @MainActor
    private func launchApp(mode: String, sheet: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--prototype-mode", mode]
        if let sheet {
            app.launchArguments.append(contentsOf: ["--prototype-sheet", sheet])
        }
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func firstElement(containingLabel text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    @MainActor
    private func wait(
        for predicate: NSPredicate,
        on object: Any,
        timeout: TimeInterval = 3
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
