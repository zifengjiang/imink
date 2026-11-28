import XCTest

final class iminkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
    }

    /// 单物体变形底导完整验收回归（默认直出，无需 `-commaDockExperiment` 参数）：
    /// 1) 静止态原生 4-Tab 居中对称胶囊（主页 / 对战 / 鲑鱼跑 / 我）
    /// 2) 首次点击切换至「鲑鱼跑」仅切 Tab，不弹菜单
    /// 3) 二次点击「鲑鱼跑」原地变形为单卡片极简菜单（仅 4 行：全部打工/鲑鱼跑/大型跑/团队打工竞赛，无搜索框/标题栏/底部第二条底栏）
    /// 4) 点选「大型跑」筛选生效并缩回 4-Tab 胶囊
    /// 5) 详情页 Push 保护：进入「打工详情」后再点「鲑鱼跑」不弹菜单而返回根列表
    /// 6) 切换至「对战」→ 二次点击展开 7 行极简模式菜单 → 点选「活动比赛」筛选生效并缩回 4-Tab 胶囊
    /// 7) 点击遮罩区关闭菜单不穿透触发列表 push
    func testSingleObjectMorphDockAcceptanceAndDetailPushGuard() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-debugScrollToBottom", "NO",
            "-session_token", "seed_preview_session_token",
            "-accountId", "1",
        ]
        app.launch()

        let homeTab = tabButton(in: app, index: 0, fallbackTitle: "主页")
        let battleTab = tabButton(in: app, index: 1, fallbackTitle: "对战")
        let coopTab = tabButton(in: app, index: 2, fallbackTitle: "鲑鱼跑")
        let meTab = tabButton(in: app, index: 3, fallbackTitle: "我")

        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        XCTAssertTrue(battleTab.exists)
        XCTAssertTrue(coopTab.exists)
        XCTAssertTrue(meTab.exists)

        // 1. 切换至「鲑鱼跑」Tab（首次点击不展开菜单）
        if !coopTab.isSelected {
            coopTab.tap()
            Thread.sleep(forTimeInterval: 0.7)
        }
        XCTAssertFalse(app.buttons["expandingDock.coopRule.BIG_RUN"].exists)

        // 恢复「全部打工」初始态
        if !app.navigationBars["全部打工"].exists {
            coopTab.tap()
            let allCoop = app.buttons["expandingDock.coopRule.ALL_RULE"]
            if allCoop.waitForExistence(timeout: 3) {
                allCoop.tap()
                XCTAssertTrue(app.navigationBars["全部打工"].waitForExistence(timeout: 3))
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // 2. 二次点击「鲑鱼跑」展开单物体卡片菜单：校验极简 4 行且无搜索框/标题栏/最近使用
        coopTab.tap()
        let allCoopRow = app.buttons["expandingDock.coopRule.ALL_RULE"]
        let regularCoopRow = app.buttons["expandingDock.coopRule.REGULAR"]
        let bigRunRow = app.buttons["expandingDock.coopRule.BIG_RUN"]
        let teamContestRow = app.buttons["expandingDock.coopRule.TEAM_CONTEST"]
        XCTAssertTrue(bigRunRow.waitForExistence(timeout: 3))
        XCTAssertTrue(allCoopRow.exists)
        XCTAssertTrue(regularCoopRow.exists)
        XCTAssertTrue(teamContestRow.exists)
        XCTAssertFalse(app.textFields["expandingDock.searchField"].exists)
        XCTAssertFalse(app.buttons["expandingDock.searchToggleButton"].exists)

        // 3. 点选「大型跑」→ 筛选生效并缩回 4-Tab 胶囊
        bigRunRow.tap()
        XCTAssertTrue(app.navigationBars["大型跑"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(bigRunRow.exists)
        XCTAssertTrue(homeTab.exists && battleTab.exists && coopTab.exists && meTab.exists)

        // 4. 切回「全部打工」，并测试详情页 Push 保护（点首行进入「打工详情」，再点「鲑鱼跑」不弹筛选菜单）
        coopTab.tap()
        XCTAssertTrue(allCoopRow.waitForExistence(timeout: 3))
        allCoopRow.tap()
        XCTAssertTrue(app.navigationBars["全部打工"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.6)

        if !app.buttons["任天堂账号登录"].exists {
            let firstListPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
            firstListPoint.tap()
            if app.navigationBars["打工详情"].waitForExistence(timeout: 3) {
                if coopTab.exists && coopTab.isHittable {
                    coopTab.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                    XCTAssertFalse(
                        app.buttons["expandingDock.coopRule.BIG_RUN"].exists,
                        "处于打工详情二级页时二次点击鲑鱼跑不得弹出筛选菜单"
                    )
                }
                if app.navigationBars["打工详情"].exists {
                    let backButton = app.navigationBars.buttons.element(boundBy: 0)
                    if backButton.exists && backButton.isHittable {
                        backButton.tap()
                    }
                }
                XCTAssertTrue(app.navigationBars["全部打工"].waitForExistence(timeout: 3))
            }
        }

        // 5. 切换至「对战」Tab（首次点击不弹菜单）
        battleTab.tap()
        Thread.sleep(forTimeInterval: 0.7)
        XCTAssertFalse(app.buttons["expandingDock.battleMode.LEAGUE"].exists)

        // 6. 二次点击「对战」展开单物体 7 行菜单 → 点选「活动比赛」
        battleTab.tap()
        let allBattleRow = app.buttons["expandingDock.battleMode.ALL"]
        let regularBattleRow = app.buttons["expandingDock.battleMode.REGULAR"]
        let anarchyRow = app.buttons["expandingDock.battleMode.BANKARA"]
        let xMatchRow = app.buttons["expandingDock.battleMode.XMATCH"]
        let leagueRow = app.buttons["expandingDock.battleMode.LEAGUE"]
        let privateRow = app.buttons["expandingDock.battleMode.PRIVATE"]
        let festRow = app.buttons["expandingDock.battleMode.FEST"]

        XCTAssertTrue(leagueRow.waitForExistence(timeout: 3))
        XCTAssertTrue(allBattleRow.exists && regularBattleRow.exists && anarchyRow.exists)
        XCTAssertTrue(xMatchRow.exists && privateRow.exists && festRow.exists)

        leagueRow.tap()
        XCTAssertTrue(app.navigationBars["活动比赛"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(leagueRow.exists)
        XCTAssertTrue(homeTab.exists && battleTab.exists && coopTab.exists && meTab.exists)

        // 7. 展开菜单后点击外部遮罩区：菜单收起且不穿透触发列表详情 push
        battleTab.tap()
        XCTAssertTrue(allBattleRow.waitForExistence(timeout: 3))
        let topBackdrop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.20))
        topBackdrop.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(allBattleRow.exists)
        XCTAssertTrue(app.navigationBars["活动比赛"].exists)

        // 恢复「全部对战」
        battleTab.tap()
        XCTAssertTrue(allBattleRow.waitForExistence(timeout: 3))
        allBattleRow.tap()
        XCTAssertTrue(app.navigationBars["全部对战"].waitForExistence(timeout: 3))
    }

    /// 供 60fps 验收录屏 `/Users/jiangfeng/Documents/imink-design/dock-morph-fixed.mp4` 使用的完整编排：
    /// 鲑鱼跑列表静止 4-Tab → 再点「鲑鱼跑」展开单卡片菜单 → 点「大型跑」筛选生效并缩回 4-Tab 胶囊 →
    /// 切到「对战」→ 再点「对战」展开菜单 → 点「活动比赛」筛选生效并缩回 4-Tab 胶囊。
    func testDockMorphFixedVideoRecordingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-debugScrollToBottom", "NO",
            "-session_token", "seed_preview_session_token",
            "-accountId", "1",
        ]
        app.launch()

        let battleTab = tabButton(in: app, index: 1, fallbackTitle: "对战")
        let coopTab = tabButton(in: app, index: 2, fallbackTitle: "鲑鱼跑")
        XCTAssertTrue(coopTab.waitForExistence(timeout: 10))

        // 先切到「鲑鱼跑」并确保处于真数据「全部打工」初始态
        if !coopTab.isSelected {
            coopTab.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        XCTAssertFalse(app.buttons["任天堂账号登录"].exists, "录屏必须注入真数据与登录态")
        if !app.navigationBars["全部打工"].exists {
            coopTab.tap()
            let allCoop = app.buttons["expandingDock.coopRule.ALL_RULE"]
            if allCoop.waitForExistence(timeout: 3) {
                allCoop.tap()
                XCTAssertTrue(app.navigationBars["全部打工"].waitForExistence(timeout: 3))
                Thread.sleep(forTimeInterval: 0.7)
            }
        }

        // 通知外部录屏脚本精确起拍
        try "ready".write(toFile: "/tmp/imink_morph_ready.flag", atomically: true, encoding: .utf8)

        // 第 1 拍：鲑鱼跑列表静止 4-Tab
        Thread.sleep(forTimeInterval: 1.0)

        // 第 2 拍：再点「鲑鱼跑」展开单卡片菜单（底下无第二条底栏）
        coopTab.tap()
        let bigRunRow = app.buttons["expandingDock.coopRule.BIG_RUN"]
        XCTAssertTrue(bigRunRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.1)

        // 第 3 拍：点「大型跑」筛选生效并缩回 4-Tab 胶囊
        bigRunRow.tap()
        XCTAssertTrue(app.navigationBars["大型跑"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.2)

        // 第 4 拍：切到「对战」静止 4-Tab
        battleTab.tap()
        Thread.sleep(forTimeInterval: 1.0)

        // 第 5 拍：再点「对战」展开单卡片菜单
        battleTab.tap()
        let leagueRow = app.buttons["expandingDock.battleMode.LEAGUE"]
        XCTAssertTrue(leagueRow.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.1)

        // 第 6 拍：点「活动比赛」筛选生效并缩回 4-Tab 胶囊
        leagueRow.tap()
        XCTAssertTrue(app.navigationBars["活动比赛"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.3)
    }

    private func tabButton(in app: XCUIApplication, index: Int, fallbackTitle: String) -> XCUIElement {
        let byID = app.buttons["expandingDock.tab.\(index)"]
        if byID.exists {
            return byID
        }
        let inTabBarByID = app.tabBars.buttons["expandingDock.tab.\(index)"]
        if inTabBarByID.exists {
            return inTabBarByID
        }
        return app.tabBars.buttons[fallbackTitle]
    }
}
