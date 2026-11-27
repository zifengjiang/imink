import XCTest

final class iminkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    /// 捕获设计验收三张静态截图并校验双向筛选联动：
    /// 1) `dock-collapsed.png`（对战收起态）
    /// 2) `dock-expanded.png`（对战展开态）
    /// 3) `dock-expanded-coop.png`（打工展开态）
    func testCaptureDockScreenshotsAndVerifyFilter() throws {
        let app = XCUIApplication()
        // 注意：不通过 launchArguments 注入 `-mainViewTabSelection`，否则 NSArgumentDomain 只读优先级会让 Tab 切换后被重置回初始值
        app.launchArguments += [
            "-imink.useCustomDock", "YES",
            "-debugScrollToBottom", "NO"
        ]
        app.launch()

        let toggleButton = app.buttons["expandingDock.toggleButton"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 10))

        let battleTab = app.buttons["expandingDock.tab.1"]
        XCTAssertTrue(battleTab.waitForExistence(timeout: 3))
        if !battleTab.isSelected {
            battleTab.tap()
        }
        Thread.sleep(forTimeInterval: 1.5)

        // 若上次运行遗留了筛选条件，先确保处于「全部对战」干净初始态再截收起态图
        if !app.navigationBars["全部对战"].exists {
            toggleButton.tap()
            let allRow = app.buttons["expandingDock.battleMode.ALL"]
            if allRow.waitForExistence(timeout: 3) {
                allRow.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
            toggleButton.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        try saveDesignScreenshot(named: "dock-collapsed.png")

        // 1. 展开对战模式面板 -> 截 `dock-expanded.png`
        toggleButton.tap()
        let anarchyRow = app.buttons["expandingDock.battleMode.BANKARA"]
        XCTAssertTrue(anarchyRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.9)
        try saveDesignScreenshot(named: "dock-expanded.png")

        // 2. 点选「蛮颓比赛」并收起面板 -> 验证顶部标题与列表真正切换到「蛮颓比赛」
        anarchyRow.tap()
        Thread.sleep(forTimeInterval: 0.7)
        toggleButton.tap()
        XCTAssertTrue(app.navigationBars["蛮颓比赛"].waitForExistence(timeout: 3))

        // 恢复「全部对战」以便后续录屏从「全部对战」起步
        toggleButton.tap()
        let allBattleRow = app.buttons["expandingDock.battleMode.ALL"]
        if allBattleRow.waitForExistence(timeout: 3) {
            allBattleRow.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        toggleButton.tap()
        Thread.sleep(forTimeInterval: 0.7)

        // 3. 切换到鲑鱼跑 Tab 并展开打工规则面板 -> 截 `dock-expanded-coop.png`
        let coopTab = app.buttons["expandingDock.tab.2"]
        XCTAssertTrue(coopTab.waitForExistence(timeout: 3))
        coopTab.tap()
        Thread.sleep(forTimeInterval: 1.2)

        if !app.navigationBars["全部打工"].exists {
            toggleButton.tap()
            let allCoopRow = app.buttons["expandingDock.coopRule.ALL_RULE"]
            if allCoopRow.waitForExistence(timeout: 3) {
                allCoopRow.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
            toggleButton.tap()
            Thread.sleep(forTimeInterval: 0.7)
        }

        toggleButton.tap()
        let bigRunRow = app.buttons["expandingDock.coopRule.BIG_RUN"]
        XCTAssertTrue(bigRunRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.9)
        try saveDesignScreenshot(named: "dock-expanded-coop.png")

        // 4. 点选「大型跑」并收起 -> 验证打工列表真正切换到「大型跑」
        bigRunRow.tap()
        Thread.sleep(forTimeInterval: 0.7)
        toggleButton.tap()
        XCTAssertTrue(app.navigationBars["大型跑"].waitForExistence(timeout: 3))

        // 恢复「全部打工」
        toggleButton.tap()
        let allCoopRow = app.buttons["expandingDock.coopRule.ALL_RULE"]
        if allCoopRow.waitForExistence(timeout: 3) {
            allCoopRow.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        toggleButton.tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// 配合外部 `xcrun simctl io booted recordVideo` 录制三段交互（展开 → 点一个模式 → 收起）。
    func testDemoFlowForVideoRecording() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-imink.useCustomDock", "YES",
            "-mainViewTabSelection", "1",
            "-debugScrollToBottom", "NO"
        ]
        app.launch()

        let toggleButton = app.buttons["expandingDock.toggleButton"]
        XCTAssertTrue(toggleButton.waitForExistence(timeout: 10))
        // 留出稳定初始画面，方便剪掉启动帧后从静止收起态开始
        Thread.sleep(forTimeInterval: 1.4)

        // 第 1 段：点击右端圆钮展开面板（弹簧回弹 + 背景变暗）
        toggleButton.tap()
        let anarchyRow = app.buttons["expandingDock.battleMode.BANKARA"]
        XCTAssertTrue(anarchyRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.3)

        // 第 2 段：点击「蛮颓比赛」（行高亮勾选 + 底层列表实时筛选为真格比赛）
        anarchyRow.tap()
        Thread.sleep(forTimeInterval: 1.3)

        // 第 3 段：再点右下圆钮收起成轻薄胶囊（展示过滤后的蛮颓比赛列表与圆钮橙色角标）
        toggleButton.tap()
        XCTAssertTrue(app.navigationBars["蛮颓比赛"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.6)
    }

    private func saveDesignScreenshot(named filename: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)

        let dir = URL(fileURLWithPath: "/Users/jiangfeng/Documents/imink-design", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(filename), options: .atomic)
    }
}
