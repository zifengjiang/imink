import XCTest
@testable import imink

final class iminkTests: XCTestCase {

    override func setUpWithError() throws {
            // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
            // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
            // This is an example of a functional test case.
            // Use XCTAssert and related functions to verify your tests produce the correct results.
            // Any test you write for XCTest can be annotated as throws and async.
            // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
            // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
            // This is an example of a performance test case.
        self.measure {
                // Put the code you want to measure the time of here.
        }
    }

    func testRequestWebServiceToken () async throws {
        let sessionToken = ""
        let nso = NSOAuthorization.shared
        do {
            let web = try await nso.requestWebServiceToken(sessionToken: sessionToken)
            print("Web service token: \(web.result.accessToken)")
            print("Expires in: \(web.result.expiresIn)")
        } catch {
            print("Error in requestWebServiceToken: \(error)")
        }

    }

    func testSplatNetSampleDataDoesNotCrash() {
        XCTAssertEqual(SN3API.web().sampleData, Data())
        XCTAssertEqual(LatestBattleHistoriesQuery().sampleData, Data())
    }

    func testRecordSelectionTracksModeAndSelectedIds() {
        var selection = RecordSelection<Int64>()

        XCTAssertFalse(selection.isActive)
        XCTAssertTrue(selection.selectedIds.isEmpty)

        selection.start()
        selection.toggle(42)

        XCTAssertTrue(selection.isActive)
        XCTAssertEqual(selection.selectedIds, [42])

        selection.toggle(42)

        XCTAssertTrue(selection.isActive)
        XCTAssertTrue(selection.selectedIds.isEmpty)

        selection.cancel()

        XCTAssertFalse(selection.isActive)
        XCTAssertTrue(selection.selectedIds.isEmpty)
    }

    func testRecordSelectionSelectsAndClearsAllVisibleIds() {
        var selection = RecordSelection<Int64>()
        let visibleIds: [Int64] = [1, 2, 3]

        selection.toggleAll(visibleIds)

        XCTAssertTrue(selection.isActive)
        XCTAssertEqual(selection.selectedIds, Set(visibleIds))

        selection.toggleAll(visibleIds)

        XCTAssertTrue(selection.isActive)
        XCTAssertTrue(selection.selectedIds.isEmpty)
    }

    func testRecordBatchOperationServiceBatchesIds() {
        let batches = RecordBatchOperationService.batches([1, 2, 3, 4, 5], batchSize: 2)

        XCTAssertEqual(batches, [[1, 2], [3, 4], [5]])
    }

    func testDebugBuildShowsDeveloperOptions() {
        XCTAssertTrue(BuildConfiguration.showsDeveloperOptions)
    }

    func testMeSummaryMetricsFormatsRecordCounts() {
        let metrics = MeSummaryMetric.recordCounts(
            battleCount: 1234,
            salmonRunCount: 56,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertEqual(metrics.map(\.title), ["战斗记录", "鲑鱼跑记录"])
        XCTAssertEqual(metrics.map(\.value), ["1,234", "56"])
        XCTAssertEqual(metrics.map(\.icon), ["paintpalette.fill", "drop.fill"])
    }

    func testSessionTokenInputTrimsWhitespaceAndRejectsBlankValues() {
        XCTAssertEqual(SessionTokenLoginInput.normalized("  abc.def \n"), "abc.def")
        XCTAssertNil(SessionTokenLoginInput.normalized(" \n\t "))
    }

    func testBattleShiftSummaryBuilderAggregatesShift() {
        let battles = [
            BattleShiftSummaryBuilder.BattleInput(
                judgement: "WIN",
                rule: "TURF_WAR",
                stageName: "Vss_Stage_A",
                weaponName: "Weapon_A",
                kill: 6,
                assist: 2,
                death: 3
            ),
            BattleShiftSummaryBuilder.BattleInput(
                judgement: "LOSE",
                rule: "AREA",
                stageName: "Vss_Stage_B",
                weaponName: "Weapon_A",
                kill: 2,
                assist: 1,
                death: 0
            ),
            BattleShiftSummaryBuilder.BattleInput(
                judgement: "DRAW",
                rule: "TURF_WAR",
                stageName: "Vss_Stage_A",
                weaponName: "Weapon_B",
                kill: 1,
                assist: 0,
                death: 1
            ),
            BattleShiftSummaryBuilder.BattleInput(
                judgement: "DEEMED_LOSE",
                rule: "LOFT",
                stageName: "Vss_Stage_C",
                weaponName: nil,
                kill: 0,
                assist: 0,
                death: 0
            )
        ]

        let summary = BattleShiftSummaryBuilder.build(from: battles)

        XCTAssertEqual(summary.totalCount, 4)
        XCTAssertEqual(summary.winCount, 1)
        XCTAssertEqual(summary.loseCount, 1)
        XCTAssertEqual(summary.drawCount, 1)
        XCTAssertEqual(summary.disconnectCount, 1)
        XCTAssertEqual(summary.stageCount, 3)
        XCTAssertEqual(summary.weaponCount, 2)
        XCTAssertEqual(summary.kill, 9)
        XCTAssertEqual(summary.assist, 3)
        XCTAssertEqual(summary.death, 4)
        XCTAssertEqual(summary.kd, 2.25, accuracy: 0.001)
        XCTAssertEqual(summary.kad, 3.0, accuracy: 0.001)
        XCTAssertEqual(summary.ruleBuckets.map(\.rule), ["TURF_WAR", "AREA", "LOFT"])
        XCTAssertEqual(summary.ruleBuckets.map(\.count), [2, 1, 1])
    }

}
