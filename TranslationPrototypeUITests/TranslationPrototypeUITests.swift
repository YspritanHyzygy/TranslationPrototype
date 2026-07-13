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

        XCTAssertTrue(waitUntilSelected(tabButton(named: "语音", in: app)))
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

        XCTAssertTrue(waitUntilSelected(tabButton(named: "相机", in: app)))
        let gallery = element("camera.galleryPicker", in: app)
        let shutter = element("camera.shutterButton", in: app)
        let flash = element("camera.flashButton", in: app)
        XCTAssertTrue(gallery.waitForExistence(timeout: 3))
        XCTAssertTrue(shutter.waitForExistence(timeout: 3))
        XCTAssertTrue(flash.waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntilHittable(gallery))
        XCTAssertTrue(waitUntilHittable(shutter))
        XCTAssertTrue(waitUntilHittable(flash))

        let tabBarFrame = app.tabBars.firstMatch.frame
        XCTAssertFalse(gallery.frame.intersects(tabBarFrame))
        XCTAssertFalse(shutter.frame.intersects(tabBarFrame))
        XCTAssertFalse(flash.frame.intersects(tabBarFrame))
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
    func testBottomNavigationPersistsAcrossEveryMode() throws {
        let app = launchApp(mode: "text")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))

        let textMode = tabBar.buttons["文字"]
        let voiceMode = tabBar.buttons["语音"]
        let cameraMode = tabBar.buttons["相机"]

        assertTabBarExists(tabBar: tabBar, text: textMode, voice: voiceMode, camera: cameraMode)
        XCTAssertTrue(waitUntilSelected(textMode))

        voiceMode.tap()
        let microphone = element("conversation-microphone-button", in: app)
        let listeningStatus = element("conversation-listening-status", in: app)
        XCTAssertTrue(microphone.waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntilSelected(voiceMode))
        XCTAssertTrue(waitUntilDeselected(textMode))
        assertTabBarExists(tabBar: tabBar, text: textMode, voice: voiceMode, camera: cameraMode)
        captureScreenshot(named: "native-tab-voice", of: app)

        microphone.tap()
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", "已暂停 · 轻点继续"), on: listeningStatus))

        cameraMode.tap()
        let shutter = element("camera.shutterButton", in: app)
        XCTAssertTrue(shutter.waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntilHittable(shutter))
        XCTAssertTrue(waitUntilSelected(cameraMode))
        XCTAssertTrue(waitUntilDeselected(voiceMode))
        assertTabBarExists(tabBar: tabBar, text: textMode, voice: voiceMode, camera: cameraMode)
        captureScreenshot(named: "native-tab-camera", of: app)

        voiceMode.tap()
        XCTAssertTrue(waitUntilSelected(voiceMode))
        let restoredListeningStatus = element("conversation-listening-status", in: app)
        let restoredMicrophone = element("conversation-microphone-button", in: app)
        XCTAssertTrue(wait(for: NSPredicate(format: "label == %@", "已暂停 · 轻点继续"), on: restoredListeningStatus))
        XCTAssertEqual(restoredMicrophone.label, "开始聆听")

        textMode.tap()
        XCTAssertTrue(element("source-text-editor", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(waitUntilSelected(textMode))
        XCTAssertTrue(waitUntilDeselected(voiceMode))
        assertTabBarExists(tabBar: tabBar, text: textMode, voice: voiceMode, camera: cameraMode)
        captureScreenshot(named: "native-tab-text", of: app)
    }

    @MainActor
    private func launchApp(mode: String, sheet: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_Hans_CN",
            "--prototype-mode", mode
        ]
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
    private func tabButton(named title: String, in app: XCUIApplication) -> XCUIElement {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        let button = tabBar.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 2))
        return button
    }

    @MainActor
    private func assertTabBarExists(
        tabBar: XCUIElement,
        text: XCUIElement,
        voice: XCUIElement,
        camera: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(tabBar.exists, file: file, line: line)
        XCTAssertTrue(text.waitForExistence(timeout: 2), file: file, line: line)
        XCTAssertTrue(voice.waitForExistence(timeout: 2), file: file, line: line)
        XCTAssertTrue(camera.waitForExistence(timeout: 2), file: file, line: line)
    }

    @MainActor
    private func waitUntilSelected(_ element: XCUIElement) -> Bool {
        wait(for: NSPredicate(format: "selected == YES"), on: element)
    }

    @MainActor
    private func waitUntilDeselected(_ element: XCUIElement) -> Bool {
        wait(for: NSPredicate(format: "selected == NO"), on: element)
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement) -> Bool {
        wait(for: NSPredicate(format: "hittable == YES"), on: element)
    }

    @MainActor
    private func captureScreenshot(named name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
