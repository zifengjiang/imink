import XCTest

final class iminkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    /// 捕获设计验收三张静态截图并验证（4-Tab 居中对称胶囊 + 二次点击当前 Tab 弹出/收起）：
    /// 1) `dock-collapsed.png`（对战收起态：仅 4 个对称按钮，无第 5 颗右圆钮）
    /// 2) 二次点击已选中的「对战」Tab -> `dock-expanded.png`（对战展开态：Liquid Glass 透明毛玻璃 + 背景虚化 + 底部 4-Tab 胶囊把手常驻 + 40pt 行高）
    /// 3) 点选「蛮颓比赛」后**自动回弹收起**（无需再点关闭按钮）且底层列表实时过滤为「蛮颓比赛」
    /// 4) 二次点击「对战」展开、再点一次「对战」收起（验证二次点击同 Tab 双向切换）
    /// 5) 首次点击「鲑鱼跑」切换 Tab（不自动弹窗）-> 二次点击「鲑鱼跑」展开 -> `dock-expanded-coop.png` -> 点选「大型跑」自动收起与过滤
    func testCaptureDockScreenshotsAndVerifyFilter() throws {
        let app = XCUIApplication()
        // 注意：不通过 launchArguments 注入 `-mainViewTabSelection`，避免 NSArgumentDomain 只读优先级重置 Tab
        app.launchArguments += [
            "-imink.useCustomDock", "YES",
            "-debugScrollToBottom", "NO"
        ]
        app.launch()

        // 验证只有 4 个 Tab 按钮，不存在第 5 颗独立右圆钮
        let homeTab = app.buttons["expandingDock.tab.0"]
        let battleTab = app.buttons["expandingDock.tab.1"]
        let coopTab = app.buttons["expandingDock.tab.2"]
        let meTab = app.buttons["expandingDock.tab.3"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        XCTAssertTrue(battleTab.exists)
        XCTAssertTrue(coopTab.exists)
        XCTAssertTrue(meTab.exists)
        XCTAssertFalse(app.buttons["expandingDock.toggleButton"].exists)

        // 验证 4 个按钮胶囊整体水平居中对称（左按钮左边距与右按钮右边距对称）
        let leftMargin = homeTab.frame.minX - app.frame.minX
        let rightMargin = app.frame.maxX - meTab.frame.maxX
        XCTAssertLessThan(abs(leftMargin - rightMargin), 3.0)

        // 首次点击切换到「对战」Tab（不应直接弹开筛选面板）
        if !battleTab.isSelected {
            battleTab.tap()
            Thread.sleep(forTimeInterval: 0.9)
            XCTAssertFalse(app.buttons["expandingDock.battleMode.BANKARA"].exists)
        } else {
            Thread.sleep(forTimeInterval: 0.8)
        }

        // 确保处于「全部对战」干净初始态
        if !app.navigationBars["全部对战"].exists {
            battleTab.tap() // 已在对战页，二次点击弹出面板
            let allRow = app.buttons["expandingDock.battleMode.ALL"]
            if allRow.waitForExistence(timeout: 3) {
                allRow.tap() // 自动收起
                Thread.sleep(forTimeInterval: 0.9)
            }
        }
        try saveDesignScreenshot(named: "dock-collapsed.png")

        // 1. 在「对战」页再点一次「对战」Tab -> 展开对战模式面板 -> 截 `dock-expanded.png`
        battleTab.tap()
        let anarchyRow = app.buttons["expandingDock.battleMode.BANKARA"]
        XCTAssertTrue(anarchyRow.waitForExistence(timeout: 3))
        // 验证展开时底部 4-Tab 胶囊把手依然常驻不消失
        XCTAssertTrue(battleTab.exists)
        Thread.sleep(forTimeInterval: 0.9)
        try saveDesignScreenshot(named: "dock-expanded.png")

        // 2. 点选「蛮颓比赛」-> 验证立刻筛选生效并**自动收起**
        anarchyRow.tap()
        XCTAssertTrue(app.navigationBars["蛮颓比赛"].waitForExistence(timeout: 3))
        XCTAssertFalse(anarchyRow.exists)

        // 3. 验证「再点同 Tab 展开 -> 再点同 Tab 收起」闭环，随后恢复「全部对战」
        battleTab.tap()
        let allBattleRow = app.buttons["expandingDock.battleMode.ALL"]
        XCTAssertTrue(allBattleRow.waitForExistence(timeout: 3))
        battleTab.tap() // 展开态再点同 Tab 立即收起
        Thread.sleep(forTimeInterval: 0.7)
        XCTAssertFalse(allBattleRow.exists)

        battleTab.tap()
        XCTAssertTrue(allBattleRow.waitForExistence(timeout: 3))
        allBattleRow.tap()
        XCTAssertTrue(app.navigationBars["全部对战"].waitForExistence(timeout: 3))

        // 4. 首次点击「鲑鱼跑」切换 Tab（保持收起），二次点击「鲑鱼跑」展开打工规则面板 -> 截 `dock-expanded-coop.png`
        coopTab.tap()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertFalse(app.buttons["expandingDock.coopRule.BIG_RUN"].exists)

        if !app.navigationBars["全部打工"].exists {
            coopTab.tap()
            let allCoopRow = app.buttons["expandingDock.coopRule.ALL_RULE"]
            if allCoopRow.waitForExistence(timeout: 3) {
                allCoopRow.tap()
                Thread.sleep(forTimeInterval: 0.8)
            }
        }

        coopTab.tap() // 二次点击「鲑鱼跑」展开面板
        let bigRunRow = app.buttons["expandingDock.coopRule.BIG_RUN"]
        XCTAssertTrue(bigRunRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.9)
        try saveDesignScreenshot(named: "dock-expanded-coop.png")

        // 5. 点选「大型跑」-> 验证自动收起且打工列表切换到「大型跑」
        bigRunRow.tap()
        XCTAssertTrue(app.navigationBars["大型跑"].waitForExistence(timeout: 3))
        XCTAssertFalse(bigRunRow.exists)

        // 恢复「全部打工」
        coopTab.tap()
        let allCoopRow = app.buttons["expandingDock.coopRule.ALL_RULE"]
        if allCoopRow.waitForExistence(timeout: 3) {
            allCoopRow.tap()
            XCTAssertTrue(app.navigationBars["全部打工"].waitForExistence(timeout: 3))
        }
    }

    /// 配合外部 `xcrun simctl io booted recordVideo` 录制三段交互（二次点击当前 Tab 展开 → 选一个模式 → 自动回弹收起）。
    func testDemoFlowForVideoRecording() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-imink.useCustomDock", "YES",
            "-debugScrollToBottom", "NO"
        ]
        app.launch()

        let battleTab = app.buttons["expandingDock.tab.1"]
        XCTAssertTrue(battleTab.waitForExistence(timeout: 10))

        if !battleTab.isSelected {
            battleTab.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        if !app.navigationBars["全部对战"].exists {
            battleTab.tap()
            let allRow = app.buttons["expandingDock.battleMode.ALL"]
            if allRow.waitForExistence(timeout: 3) {
                allRow.tap()
                Thread.sleep(forTimeInterval: 0.9)
            }
        }

        // 静止收起态起拍缓冲（4-Tab 居中对称胶囊）
        Thread.sleep(forTimeInterval: 1.2)

        // 第 1 段：在「对战」页再点一次「对战」Tab -> 胶囊原地向上变形展开透明毛玻璃面板 + 背景景深虚化
        battleTab.tap()
        let anarchyRow = app.buttons["expandingDock.battleMode.BANKARA"]
        XCTAssertTrue(anarchyRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.3)

        // 第 2 & 3 段：点选「蛮颓比赛」-> 勾选落定后自动沿带轻微回弹的弹簧收起为对称胶囊，列表实时过滤为蛮颓比赛
        anarchyRow.tap()
        XCTAssertTrue(app.navigationBars["蛮颓比赛"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.5)
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
