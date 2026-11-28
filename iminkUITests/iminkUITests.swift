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

    /// 真实登录态 + 种子库（761 场对战 / 12,257 场打工）搜索验收截图 + 穿透录屏全流程：
    /// - 捕获 `dock-search-typing.png`（输入「涂地」后键盘弹出、面板上移且只剩匹配项）
    /// - 捕获 `dock-search-empty.png`（输入「zzz」显示「没有匹配的筛选项」）
    /// - 录制 `dock-demo2.mp4`（真数据卡片滚动 -> 二次点击展开含最近使用与搜索框 -> 点搜索框弹起键盘整体上移 -> 输入「涂地」过滤 -> 点选「涂地模式」先收键盘再收面板并实时筛出涂地卡片）
    func testSeededContentDemoFlowForRecording() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-imink.useCustomDock", "YES",
            "-debugScrollToBottom", "NO"
        ]
        app.launch()

        let battleTab = app.buttons["expandingDock.tab.1"]
        XCTAssertTrue(battleTab.waitForExistence(timeout: 10))

        // 切到「对战」Tab，并断言已处于真实数据登录态（严禁出现登录页）
        if !battleTab.isSelected {
            battleTab.tap()
            Thread.sleep(forTimeInterval: 0.7)
        } else {
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertFalse(app.buttons["任天堂账号登录"].exists, "录屏必须处于真实数据登录态，严禁录登录页")

        // 先恢复「全部对战」干净起点（同时也会预热最近使用分区）
        if !app.navigationBars["全部对战"].exists {
            battleTab.tap()
            let allRow = app.buttons["expandingDock.battleMode.ALL"]
            if allRow.waitForExistence(timeout: 3) {
                allRow.tap()
                Thread.sleep(forTimeInterval: 0.7)
            }
        }

        // 第 1 幕：滚动真实对战彩色卡片，展示底部毛玻璃胶囊实时透色折射
        let scrollView = app.scrollViews.firstMatch
        if scrollView.waitForExistence(timeout: 3) {
            let bottomCoord = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let topCoord = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38))
            bottomCoord.press(forDuration: 0.05, thenDragTo: topCoord)
            Thread.sleep(forTimeInterval: 0.45)
            topCoord.press(forDuration: 0.05, thenDragTo: bottomCoord)
            Thread.sleep(forTimeInterval: 0.55)
        }

        // 第 2 幕：二次点击已选中的「对战」Tab -> 展开面板（含顶部 36pt 搜索框与最近使用分区）
        battleTab.tap()
        let searchField = app.textFields["expandingDock.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.75)

        // 第 3 幕：点击搜索框 -> 软键盘弹出，面板 + 底部 4-Tab 底座整体上移至键盘上方 -> 输入「涂地」
        searchField.tap()
        Thread.sleep(forTimeInterval: 0.75)
        searchField.typeText("涂地")
        let turfRuleRow = app.buttons["expandingDock.battleRule.TURF_WAR"]
        XCTAssertTrue(turfRuleRow.waitForExistence(timeout: 3))
        // 验证不匹配项已被过滤隐藏
        XCTAssertFalse(app.buttons["expandingDock.battleMode.XMATCH"].exists)
        Thread.sleep(forTimeInterval: 0.65)
        try saveDesignScreenshot(named: "dock-search-typing.png")

        // 第 4 幕：点选匹配出的「涂地模式」-> 先收键盘再收面板，底层列表实时过滤为「涂地模式」真实卡片
        turfRuleRow.tap()
        XCTAssertTrue(app.navigationBars["涂地模式"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.9)
    }

    /// 独立捕获无匹配态截图 `dock-search-empty.png`（输入 `zzz` 显示「没有匹配的筛选项」并验证点遮罩先收键盘再收面板）。
    func testCaptureSearchEmptyScreenshot() throws {
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
            Thread.sleep(forTimeInterval: 0.6)
        }

        battleTab.tap()
        let searchField = app.textFields["expandingDock.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        Thread.sleep(forTimeInterval: 0.7)
        searchField.typeText("zzz")

        let emptyState = app.otherElements["expandingDock.searchEmptyState"]
        let emptyLabel = app.staticTexts["没有匹配的筛选项"]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3) || emptyLabel.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        try saveDesignScreenshot(named: "dock-search-empty.png")

        // 点击面板上方遮罩区验证「先收键盘再收面板」
        let topBackdrop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        topBackdrop.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertFalse(searchField.exists)
    }

    /// UIKit 第二版底导完整验收截图与交互回归：
    /// 输出 `uikit-dock-collapsed.png`、`uikit-dock-expanded.png`、`uikit-dock-search.png` 并校验全部产品规格。
    func testCaptureUIKitDockAcceptanceScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-imink.useCustomDock", "YES",
            "-debugScrollToBottom", "NO",
            "-session_token", "seed_preview_session_token",
            "-accountId", "1",
        ]
        app.launch()

        let homeTab = app.buttons["expandingDock.tab.0"]
        let battleTab = app.buttons["expandingDock.tab.1"]
        let coopTab = app.buttons["expandingDock.tab.2"]
        let meTab = app.buttons["expandingDock.tab.3"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        XCTAssertTrue(battleTab.exists)
        XCTAssertTrue(coopTab.exists)
        XCTAssertTrue(meTab.exists)
        XCTAssertFalse(app.buttons["expandingDock.toggleButton"].exists)

        // 切至「对战」Tab（首次点击仅切换 Tab，不弹面板），并确认已处于真实种子数据登录态
        if !battleTab.isSelected {
            battleTab.tap()
            Thread.sleep(forTimeInterval: 0.9)
        }
        XCTAssertFalse(app.buttons["任天堂账号登录"].exists)
        XCTAssertFalse(app.buttons["expandingDock.battleMode.BANKARA"].exists)

        // 预热一条「最近使用」（选一次 X 比赛再切回全部对战），让展开态完整呈现「最近使用 + 分组标题 + 36pt 搜索框」
        battleTab.tap()
        let xMatchRow = app.buttons["expandingDock.battleMode.XMATCH"]
        XCTAssertTrue(xMatchRow.waitForExistence(timeout: 3))
        xMatchRow.tap()
        XCTAssertTrue(app.navigationBars["X比赛"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.9)

        battleTab.tap()
        let allBattleRow = app.buttons["expandingDock.battleMode.ALL"]
        XCTAssertTrue(allBattleRow.waitForExistence(timeout: 3))
        allBattleRow.tap()
        XCTAssertTrue(app.navigationBars["全部对战"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.9)
        XCTAssertFalse(allBattleRow.exists)

        // 1. 捕获收起态截图 `uikit-dock-collapsed.png`（完整收起、底部仅 4 颗真实 Liquid Glass 按钮 + 彩色对战卡片）
        try saveDesignScreenshot(named: "uikit-dock-collapsed.png")

        // 2. 二次点击「对战」Tab 展开面板 -> 校验 4 个 Tab 按钮全程仍在 -> 捕获 `uikit-dock-expanded.png`
        battleTab.tap()
        let searchField = app.textFields["expandingDock.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        XCTAssertTrue(homeTab.exists && battleTab.exists && coopTab.exists && meTab.exists)
        Thread.sleep(forTimeInterval: 0.7)
        try saveDesignScreenshot(named: "uikit-dock-expanded.png")

        // 3. 点击 36pt 搜索框 -> 软键盘弹出、面板整体上移避让 -> 输入「涂地」 -> 捕获 `uikit-dock-search.png`
        searchField.tap()
        Thread.sleep(forTimeInterval: 0.7)
        searchField.typeText("涂地")
        let turfRow = app.buttons["expandingDock.battleRule.TURF_WAR"]
        XCTAssertTrue(turfRow.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["expandingDock.battleMode.XMATCH"].exists)
        Thread.sleep(forTimeInterval: 0.6)
        try saveDesignScreenshot(named: "uikit-dock-search.png")

        // 4. 验证空匹配态「没有匹配的筛选项」及点击遮罩「先收键盘再收面板」
        let clearBtn = app.buttons["expandingDock.searchClearButton"]
        if clearBtn.exists {
            clearBtn.tap()
        }
        searchField.typeText("zzz")
        XCTAssertTrue(app.otherElements["expandingDock.searchEmptyState"].waitForExistence(timeout: 3))
        let backdropTop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        backdropTop.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertFalse(searchField.exists)

        // 5. 复现并验证「鲑鱼跑 -> 大型跑」链路
        coopTab.tap()
        Thread.sleep(forTimeInterval: 0.7)
        coopTab.tap()
        let bigRunRow = app.buttons["expandingDock.coopRule.BIG_RUN"]
        XCTAssertTrue(bigRunRow.waitForExistence(timeout: 3))
        bigRunRow.tap()
        XCTAssertTrue(app.navigationBars["大型跑"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.6)

        // 恢复「全部打工」干净态
        coopTab.tap()
        let allCoopRow = app.buttons["expandingDock.coopRule.ALL_RULE"]
        if allCoopRow.waitForExistence(timeout: 3) {
            allCoopRow.tap()
            XCTAssertTrue(app.navigationBars["全部打工"].waitForExistence(timeout: 3))
        }
    }

    /// 供 `uikit-dock-demo.mp4` 录屏使用的三段式演示：
    /// 在「鲑鱼跑」Tab 上复现主人反馈的完整路径（静止收起态 -> 二次点击「鲑鱼跑」展开面板 -> 点选「大型跑」自动回弹收起），全程 4 颗底导按钮常驻可见。
    func testUIKitDockDemoRecordingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-imink.useCustomDock", "YES",
            "-debugScrollToBottom", "NO",
            "-session_token", "seed_preview_session_token",
            "-accountId", "1",
        ]
        app.launch()

        let coopTab = app.buttons["expandingDock.tab.2"]
        XCTAssertTrue(coopTab.waitForExistence(timeout: 10))
        if !coopTab.isSelected {
            coopTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }
        XCTAssertFalse(app.buttons["任天堂账号登录"].exists)
        if !app.navigationBars["全部打工"].exists {
            coopTab.tap()
            let allCoop = app.buttons["expandingDock.coopRule.ALL_RULE"]
            if allCoop.waitForExistence(timeout: 3) {
                allCoop.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // 写就绪标记文件通知外部录屏脚本精确起拍，彻底避开启动期白屏
        try "ready".write(toFile: "/tmp/imink_demo_ready.flag", atomically: true, encoding: .utf8)

        // 起拍静止段（收起态 4 按钮完整可见） -> 二次点击「鲑鱼跑」展开 -> 点选「大型跑」自动回弹收起
        Thread.sleep(forTimeInterval: 1.3)
        coopTab.tap()
        let bigRunRow = app.buttons["expandingDock.coopRule.BIG_RUN"]
        XCTAssertTrue(bigRunRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.3)

        bigRunRow.tap()
        XCTAssertTrue(app.navigationBars["大型跑"].waitForExistence(timeout: 3))
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
