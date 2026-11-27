import XCTest
import SwiftUI
import SplatDatabase
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

    func testNintendoLoginAcceptsUserWithoutBirthday() throws {
        let user = try JSONDecoder().decode(
            NSOAuthorization.NAUser.self,
            from: Data(#"{"country":"US","language":"en-US","id":"123"}"#.utf8)
        )
        XCTAssertEqual(user.id, "123")
        XCTAssertEqual(NSOAPI.login(encryptedTokenRequest: Data()).path, "/v4/Account/Login")
        XCTAssertEqual(
            AppAPI.nxapiZnca_f_advanced(
                accessToken: "", step: .hash1, idToken: "", encryptTokenRequest: .init(url: "", parameter: [:]), naId: "", coralUserId: nil
            ).headers?["X-znca-Client-Version"],
            "d8fAZDPzwimzQ7c6"
        )
        let form = String(data: try XCTUnwrap(AppAPI.nxapiZnca_auth_token.request.httpBody), encoding: .utf8)
        XCTAssertEqual(form?.components(separatedBy: "client_id=").count, 2)
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

    func testRecordStoreBatchesIdsInChunks() {
        let batches = SplatDatabase.batches([1, 2, 3, 4, 5], batchSize: 2)

        XCTAssertEqual(batches, [[1, 2], [3, 4], [5]])
    }

    func testRecordKindMapsToTableAndNotification() {
        XCTAssertEqual(SplatRecordKind.coop.table, "coop")
        XCTAssertEqual(SplatRecordKind.battle.table, "battle")
        XCTAssertEqual(SplatRecordKind.coop.dataChangedNotification, .coopDataChanged)
        XCTAssertEqual(SplatRecordKind.battle.dataChangedNotification, .battleDataChanged)
    }


    func testBadgeHierarchyMergesSingleBadgeNodes() {
        let badges = [
            ImageMap(nameId: "1", name: "Badge_Mode_Rainmaker_Lv1", hash: "h1"),
            ImageMap(nameId: "2", name: "Badge_Mode_Rainmaker_Lv2", hash: "h2"),
            ImageMap(nameId: "3", name: "Badge_Solo", hash: "h3"),
            ImageMap(nameId: "4", name: "NotABadge", hash: "h4"),
        ]

        let hierarchy = BadgeHierarchy.build(from: badges)

        XCTAssertEqual(hierarchy.map(\.name), ["Mode", BadgeHierarchy.singleLevelGroupName])
        XCTAssertEqual(hierarchy[0].displayName, "Mode - Rainmaker")
        XCTAssertEqual(hierarchy[0].badges.count, 2)
        XCTAssertEqual(hierarchy[1].badges.map(\.nameId), ["3"])
    }

    func testDebugBuildShowsDeveloperOptions() {
        XCTAssertTrue(BuildConfiguration.showsDeveloperOptions)
    }

    func testMeSummaryMetricsFormatsRecordCounts() {
        let metrics = MeSummaryMetric.recordCounts(
            battleCount: 1234,
            salmonRunCount: 56,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(metrics.map(\.title), ["战斗记录", "鲑鱼跑记录"])
        XCTAssertEqual(metrics.map(\.value), ["1,234", "56"])
        XCTAssertEqual(metrics.map(\.icon), ["paintpalette.fill", "drop.fill"])
    }

    func testSessionTokenInputTrimsWhitespaceAndRejectsBlankValues() {
        XCTAssertEqual(SessionTokenLoginInput.normalized("  abc.def \n"), "abc.def")
        XCTAssertNil(SessionTokenLoginInput.normalized(" \n\t "))
    }

    func testSplatNetWebRequestUsesOfficialHostAndNintendoHeaders() throws {
        let session = SplatNetWebSession(
            gameWebToken: "game-web-token",
            country: "JP",
            accountLanguage: "ja-JP"
        )

        let request = try SplatNetWebRequestBuilder.request(
            for: session,
            interfaceLanguage: "zh-CN",
            colorScheme: .dark
        )
        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        )
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, SplatNetWebRequestBuilder.allowedHost)
        XCTAssertEqual(query["lang"], "zh-CN")
        XCTAssertEqual(query["na_country"], "JP")
        XCTAssertEqual(query["na_lang"], "ja-JP")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "zh-CN;q=0.9")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-GameWebToken"), "game-web-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Requested-With"), "com.nintendo.znca")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-AppColorScheme"), "DARK")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "User-Agent"),
            SplatNetWebRequestBuilder.androidWebViewUserAgent
        )
    }

    func testSplatNetWebRequestRejectsBlankSessionValues() {
        let session = SplatNetWebSession(
            gameWebToken: " ",
            country: "JP",
            accountLanguage: "ja-JP"
        )

        XCTAssertThrowsError(
            try SplatNetWebRequestBuilder.request(
                for: session,
                interfaceLanguage: "zh-CN",
                colorScheme: .light
            )
        )
    }

    func testSplatNetWebLanguageMapsChineseLocalizations() {
        XCTAssertEqual(SplatNetWebLanguage.identifier(for: "zh-Hans"), "zh-CN")
        XCTAssertEqual(SplatNetWebLanguage.identifier(for: "zh-Hans-CN"), "zh-CN")
        XCTAssertEqual(SplatNetWebLanguage.identifier(for: "zh-Hant"), "zh-TW")
        XCTAssertEqual(SplatNetWebLanguage.identifier(for: "zh-HK"), "zh-TW")
    }

    func testSplatNetBridgeEscapesGameWebTokenAsJSON() throws {
        let token = "token\"with\\characters\nand\u{2028}separator"
        let literal = SplatNetBridgeScript.javascriptStringLiteral(token)
        let decoded = try JSONDecoder().decode(String.self, from: Data(literal.utf8))
        let source = SplatNetBridgeScript.source(gameWebToken: token)

        XCTAssertEqual(decoded, token)
        XCTAssertTrue(source.contains(literal))
        XCTAssertTrue(source.contains("window.requestGameWebToken"))
    }

    func testSplatNetNavigationOnlyEmbedsTheOfficialHTTPSHost() throws {
        let officialURL = try XCTUnwrap(
            URL(string: "https://api.lp1.av5ja.srv.nintendo.net/history")
        )
        let insecureURL = try XCTUnwrap(
            URL(string: "http://api.lp1.av5ja.srv.nintendo.net/history")
        )
        let suffixAttackURL = try XCTUnwrap(
            URL(string: "https://api.lp1.av5ja.srv.nintendo.net.example.com/")
        )

        XCTAssertTrue(SplatNetWebNavigationPolicy.isAllowedInternalURL(officialURL))
        XCTAssertFalse(SplatNetWebNavigationPolicy.isAllowedInternalURL(insecureURL))
        XCTAssertFalse(SplatNetWebNavigationPolicy.isAllowedInternalURL(suffixAttackURL))
    }

    func testMyGearQueryUsesPersistedQueryNameAndInterfaceLanguage() {
        let query: MyOutfitCommonDataEquipmentsQuery =
            .myOutfitCommonDataEquipments(
                language: "zh-CN",
                gameWebToken: "game-web-token",
                country: "JP",
                accountLanguage: "ja-JP"
            )

        XCTAssertEqual(
            MyOutfitCommonDataEquipmentsQuery.name,
            "myOutfitCommonDataEquipmentsQuery"
        )
        XCTAssertEqual(query.headers?["Accept-Language"], "zh-CN")
        XCTAssertEqual(query.headers?["Cookie"], "_gtoken=game-web-token; _dnt=1")
        XCTAssertEqual(
            query.headers?["Referer"],
            "https://api.lp1.av5ja.srv.nintendo.net/?lang=zh-CN&na_country=JP&na_lang=ja-JP"
        )
        XCTAssertEqual(query.headers?["X-Requested-With"], "com.nintendo.znca")
    }

    func testBulletTokenRequestUsesAccountLocaleAndNintendoWebHeaders() {
        let target = SN3API.bulletTokens(
            gameServiceToken: "game-web-token",
            country: "JP",
            accountLanguage: "ja-JP",
            interfaceLanguage: "zh-CN"
        )
        let request = target.request

        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "zh-CN")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-NACOUNTRY"), "JP")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Cookie"),
            "_gtoken=game-web-token; _dnt=1"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Referer"),
            "https://api.lp1.av5ja.srv.nintendo.net/?lang=zh-CN&na_country=JP&na_lang=ja-JP"
        )
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Requested-With"),
            "com.nintendo.znca"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Sec-Fetch-Dest"), "empty")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Sec-Fetch-Mode"), "cors")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Sec-Fetch-Site"), "same-origin")

        let preparedRequest = BulletTokenPlugin(
            bulletToken: "stale-bullet-token"
        ).prepare(request, target: target)
        XCTAssertNil(preparedRequest.value(forHTTPHeaderField: "Authorization"))
    }

    func testMyGearCollectionDecodesAllCategoriesAndAbilitySlots() throws {
        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )

        XCTAssertEqual(collection.headGears.nodes.map(\.id), [
            "headgear-101",
            "headgear-102",
        ])
        XCTAssertEqual(collection.clothingGears.nodes.map(\.id), ["clothing-201"])
        XCTAssertEqual(collection.shoesGears.nodes.map(\.id), ["shoes-301"])
        XCTAssertEqual(
            collection.headGears.nodes.map(\.additionalGearPowers.count),
            [0, 3]
        )
        XCTAssertEqual(
            collection.clothingGears.nodes.first?.additionalGearPowers.count,
            1
        )
        XCTAssertEqual(collection.headGears.nodes.first?.stats?.exp, 1200)
    }

    func testMyGearCollectionSortsByBrandAndPrimaryAbility() throws {
        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )

        XCTAssertEqual(
            collection.gears(for: .headgear, sortedBy: .defaultOrder).map(\.id),
            ["headgear-101", "headgear-102"]
        )
        XCTAssertEqual(
            collection.gears(for: .headgear, sortedBy: .brand).map(\.id),
            ["headgear-102", "headgear-101"]
        )
        XCTAssertEqual(
            collection.gears(for: .headgear, sortedBy: .primaryAbility).map(\.id),
            ["headgear-101", "headgear-102"]
        )
    }

    func testMyGearSearchMatchesGearBrandAndAbilityNames() throws {
        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )

        func matchingIDs(_ searchText: String) -> [String] {
            var filter = MyGearFilter()
            filter.searchText = searchText
            return collection.gears(
                for: .headgear,
                filteredBy: filter,
                sortedBy: .defaultOrder
            ).map(\.id)
        }

        XCTAssertEqual(matchingIDs("HEADGEAR two"), ["headgear-102"])
        XCTAssertEqual(matchingIDs("Brand Z"), ["headgear-101"])
        XCTAssertEqual(matchingIDs("Ability Ten"), ["headgear-101"])
        XCTAssertEqual(matchingIDs("Ability Three"), ["headgear-102"])
        XCTAssertEqual(matchingIDs("Brand-A Three"), ["headgear-102"])
        XCTAssertEqual(
            matchingIDs("  \n  "),
            ["headgear-101", "headgear-102"]
        )
    }

    func testMyGearFilterUsesORWithinGroupsAndANDBetweenGroups() throws {
        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )
        var filter = MyGearFilter()

        filter.brandIDs = ["Brand-A", "Brand-Z"]
        XCTAssertEqual(
            collection.gears(
                for: .headgear,
                filteredBy: filter,
                sortedBy: .defaultOrder
            ).map(\.id),
            ["headgear-101", "headgear-102"]
        )

        filter.primaryGearPowerIDs = [20]
        filter.additionalGearPowerIDs = [2, 999]
        filter.searchText = "Three"
        XCTAssertEqual(
            collection.gears(
                for: .headgear,
                filteredBy: filter,
                sortedBy: .defaultOrder
            ).map(\.id),
            ["headgear-102"]
        )

        filter.brandIDs = ["Brand-Z"]
        XCTAssertTrue(
            collection.gears(
                for: .headgear,
                filteredBy: filter,
                sortedBy: .defaultOrder
            ).isEmpty
        )
    }

    func testMyGearFilterOptionsAreScopedToCategory() throws {
        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )

        XCTAssertEqual(
            collection.availableBrands(for: .headgear).map(\.id),
            ["Brand-A", "Brand-Z"]
        )
        XCTAssertEqual(
            Set(
                collection.availablePrimaryGearPowers(for: .headgear)
                    .map(\.gearPowerID)
            ),
            Set([10, 20])
        )
        XCTAssertEqual(
            Set(
                collection.availableAdditionalGearPowers(for: .headgear)
                    .map(\.gearPowerID)
            ),
            Set([1, 2, 3])
        )
        XCTAssertEqual(
            collection.availableBrands(for: .clothing).map(\.id),
            ["Brand-C"]
        )
        XCTAssertEqual(
            Set(
                collection.availablePrimaryGearPowers(for: .clothing)
                    .map(\.gearPowerID)
            ),
            Set([30])
        )
        XCTAssertEqual(
            Set(
                collection.availableAdditionalGearPowers(for: .clothing)
                    .map(\.gearPowerID)
            ),
            Set([4])
        )
    }

    func testMyGearFilterRetainsAvailableSelectionsAndResets() {
        var filter = MyGearFilter(
            searchText: "headgear",
            brandIDs: ["Brand-A", "Brand-C"],
            primaryGearPowerIDs: [20, 30],
            additionalGearPowerIDs: [2, 4]
        )

        filter.retainAvailableSelections(
            brandIDs: ["Brand-A", "Brand-Z"],
            primaryGearPowerIDs: [10, 20],
            additionalGearPowerIDs: [1, 2, 3]
        )

        XCTAssertEqual(filter.searchText, "headgear")
        XCTAssertEqual(filter.brandIDs, ["Brand-A"])
        XCTAssertEqual(filter.primaryGearPowerIDs, [20])
        XCTAssertEqual(filter.additionalGearPowerIDs, [2])
        XCTAssertEqual(filter.selectedFilterCount, 3)
        XCTAssertTrue(filter.hasActiveCriteria)

        filter.reset()

        XCTAssertEqual(filter, MyGearFilter())
        XCTAssertFalse(filter.hasActiveCriteria)
    }

    @MainActor
    func testMyGearRequestCacheReusesResultForFiveMinutes() async throws {
        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let cache = MyGearCollectionRequestCache(
            timeToLive: 300,
            now: { currentDate }
        )
        let key = MyGearCollectionRequestCache.Key(
            session: SplatNetWebSession(
                gameWebToken: "token-a",
                country: "JP",
                accountLanguage: "ja-JP"
            ),
            interfaceLanguage: "zh-CN"
        )
        var loadCount = 0

        let first = try await cache.value(for: key) {
            loadCount += 1
            return collection
        }
        currentDate.addTimeInterval(299)
        let cached = try await cache.value(for: key) {
            loadCount += 1
            return collection
        }

        XCTAssertEqual(first, collection)
        XCTAssertEqual(cached, collection)
        XCTAssertEqual(loadCount, 1)

        currentDate.addTimeInterval(1)
        _ = try await cache.value(for: key) {
            loadCount += 1
            return collection
        }

        XCTAssertEqual(loadCount, 2)
    }

    @MainActor
    func testMyGearRequestCacheCoalescesConcurrentLoads() async throws {
        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )
        let cache = MyGearCollectionRequestCache()
        let key = MyGearCollectionRequestCache.Key(
            session: SplatNetWebSession(
                gameWebToken: "token-a",
                country: "JP",
                accountLanguage: "ja-JP"
            ),
            interfaceLanguage: "zh-CN"
        )
        var loadCount = 0
        var secondStarted = false
        var continuation: CheckedContinuation<MyGearCollection, Error>?

        let firstTask = Task { @MainActor in
            try await cache.value(for: key) {
                loadCount += 1
                return try await withCheckedThrowingContinuation {
                    continuation = $0
                }
            }
        }
        while continuation == nil {
            await Task.yield()
        }

        let secondTask = Task { @MainActor in
            secondStarted = true
            return try await cache.value(for: key) {
                loadCount += 1
                return collection
            }
        }
        while !secondStarted {
            await Task.yield()
        }

        XCTAssertEqual(loadCount, 1)
        let pendingContinuation = try XCTUnwrap(continuation)
        continuation = nil
        pendingContinuation.resume(returning: collection)

        let firstValue = try await firstTask.value
        let secondValue = try await secondTask.value
        XCTAssertEqual(firstValue, collection)
        XCTAssertEqual(secondValue, collection)
        XCTAssertEqual(loadCount, 1)
    }

    @MainActor
    func testMyGearRequestCacheDoesNotCacheErrorsOrCrossContexts() async throws {
        enum TestError: Error {
            case failed
        }

        let collection = try MyGearResponseDecoder.decode(
            Data(Self.myGearFixture.utf8)
        )
        let cache = MyGearCollectionRequestCache()
        let session = SplatNetWebSession(
            gameWebToken: "token-a",
            country: "JP",
            accountLanguage: "ja-JP"
        )
        let chineseKey = MyGearCollectionRequestCache.Key(
            session: session,
            interfaceLanguage: "zh-CN"
        )
        let japaneseKey = MyGearCollectionRequestCache.Key(
            session: session,
            interfaceLanguage: "ja-JP"
        )
        var loadCount = 0

        do {
            _ = try await cache.value(for: chineseKey) {
                loadCount += 1
                throw TestError.failed
            }
            XCTFail("失败的装备请求不应返回结果")
        } catch TestError.failed {
            // Expected. Failed requests must not enter the cache.
        }

        _ = try await cache.value(for: chineseKey) {
            loadCount += 1
            return collection
        }
        _ = try await cache.value(for: japaneseKey) {
            loadCount += 1
            return collection
        }

        XCTAssertEqual(loadCount, 3)
    }

    func testMyGearDecoderToleratesUnusedNullableValues() throws {
        let response = Data(
            """
            {
              "data": {
                "headGears": {
                  "nodes": [
                    {
                      "headGearId": 101,
                      "name": "Headgear",
                      "rarity": null,
                      "image": { "url": "https://example.com/Gear.png" },
                      "brand": {
                        "id": "Brand",
                        "name": "Brand",
                        "image": { "url": "https://example.com/Brand.png" }
                      },
                      "primaryGearPower": {
                        "gearPowerId": 10,
                        "name": "Primary",
                        "image": { "url": "https://example.com/Primary.png" },
                        "power": null
                      },
                      "additionalGearPowers": [
                        {
                          "gearPowerId": 20,
                          "name": "Additional",
                          "image": { "url": "https://example.com/Additional.png" }
                        }
                      ],
                      "stats": { "exp": null }
                    }
                  ]
                },
                "clothingGears": { "nodes": [] },
                "shoesGears": { "nodes": [] }
              }
            }
            """.utf8
        )

        let gear = try XCTUnwrap(
            MyGearResponseDecoder.decode(response).headGears.nodes.first
        )

        XCTAssertNil(gear.rarity)
        XCTAssertNil(gear.primaryGearPower.power)
        XCTAssertNil(gear.additionalGearPowers.first?.power)
        XCTAssertNil(gear.stats?.exp)
    }

    func testMyGearDecoderAcceptsFractionalAbilityPower() throws {
        let response = Data(
            """
            {
              "data": {
                "headGears": {
                  "nodes": [
                    {
                      "headGearId": 101,
                      "name": "Headgear",
                      "rarity": 2,
                      "image": { "url": "https://example.com/Gear.png" },
                      "brand": {
                        "id": "Brand",
                        "name": "Brand",
                        "image": { "url": "https://example.com/Brand.png" }
                      },
                      "primaryGearPower": {
                        "gearPowerId": 10,
                        "name": "Primary",
                        "image": { "url": "https://example.com/Primary.png" },
                        "power": 1.0
                      },
                      "additionalGearPowers": [
                        {
                          "gearPowerId": 20,
                          "name": "Additional",
                          "image": { "url": "https://example.com/Additional.png" },
                          "power": 0.3
                        }
                      ],
                      "stats": { "exp": 1200 }
                    }
                  ]
                },
                "clothingGears": { "nodes": [] },
                "shoesGears": { "nodes": [] }
              }
            }
            """.utf8
        )

        let gear = try XCTUnwrap(
            MyGearResponseDecoder.decode(response).headGears.nodes.first
        )

        XCTAssertEqual(gear.primaryGearPower.power, 1.0)
        XCTAssertEqual(gear.additionalGearPowers.first?.power, 0.3)
    }

    func testMyGearGraphQLErrorsAreNotTreatedAsEmptyData() throws {
        let response = Data(
            """
            {
              "data": {
                "headGears": null,
                "clothingGears": null,
                "shoesGears": null
              },
              "errors": [
                { "message": "Authentication required" }
              ]
            }
            """.utf8
        )

        XCTAssertThrowsError(try MyGearResponseDecoder.decode(response)) { error in
            XCTAssertEqual(
                error as? MyGearCollectionError,
                .graphQL("Authentication required")
            )
        }
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

    private static let myGearFixture = """
    {
      "data": {
        "headGears": {
          "nodes": [
            {
              "headGearId": 101,
              "name": "Headgear One",
              "rarity": 2,
              "image": { "url": "https://example.com/Gear_Head_One.png" },
              "brand": {
                "id": "Brand-Z",
                "name": "Brand Z",
                "image": { "url": "https://example.com/Brand_Z.png" }
              },
              "primaryGearPower": {
                "gearPowerId": 10,
                "name": "Ability Ten",
                "image": { "url": "https://example.com/Ability_10.png" },
                "power": 10
              },
              "additionalGearPowers": [],
              "stats": { "exp": 1200 }
            },
            {
              "headGearId": 102,
              "name": "Headgear Two",
              "rarity": 1,
              "image": { "url": "https://example.com/Gear_Head_Two.png" },
              "brand": {
                "id": "Brand-A",
                "name": "Brand A",
                "image": { "url": "https://example.com/Brand_A.png" }
              },
              "primaryGearPower": {
                "gearPowerId": 20,
                "name": "Ability Twenty",
                "image": { "url": "https://example.com/Ability_20.png" },
                "power": 10
              },
              "additionalGearPowers": [
                {
                  "gearPowerId": 1,
                  "name": "Ability One",
                  "image": { "url": "https://example.com/Ability_1.png" },
                  "power": 3
                },
                {
                  "gearPowerId": 2,
                  "name": "Ability Two",
                  "image": { "url": "https://example.com/Ability_2.png" },
                  "power": 3
                },
                {
                  "gearPowerId": 3,
                  "name": "Ability Three",
                  "image": { "url": "https://example.com/Ability_3.png" },
                  "power": 3
                }
              ],
              "stats": null
            }
          ]
        },
        "clothingGears": {
          "nodes": [
            {
              "clothingGearId": 201,
              "name": "Clothing One",
              "rarity": 0,
              "image": { "url": "https://example.com/Gear_Clothing_One.png" },
              "brand": {
                "id": "Brand-C",
                "name": "Brand C",
                "image": { "url": "https://example.com/Brand_C.png" }
              },
              "primaryGearPower": {
                "gearPowerId": 30,
                "name": "Ability Thirty",
                "image": { "url": "https://example.com/Ability_30.png" },
                "power": 10
              },
              "additionalGearPowers": [
                {
                  "gearPowerId": 4,
                  "name": "Ability Four",
                  "image": { "url": "https://example.com/Ability_4.png" },
                  "power": 3
                }
              ],
              "stats": { "exp": 0 }
            }
          ]
        },
        "shoesGears": {
          "nodes": [
            {
              "shoesGearId": 301,
              "name": "Shoes One",
              "rarity": 0,
              "image": { "url": "https://example.com/Gear_Shoes_One.png" },
              "brand": {
                "id": "Brand-S",
                "name": "Brand S",
                "image": { "url": "https://example.com/Brand_S.png" }
              },
              "primaryGearPower": {
                "gearPowerId": 40,
                "name": "Ability Forty",
                "image": { "url": "https://example.com/Ability_40.png" },
                "power": 10
              },
              "additionalGearPowers": [],
              "stats": null
            }
          ]
        }
      }
    }
    """

}

@MainActor
final class InkWaterBarSnapshotTests: XCTestCase {
    /// 把墨水条在若干时刻渲染成 PNG，便于人工核对形态。
    func testRenderInkWaterBarFrames() throws {
        let segments: [InkWaterBar.Segment] = [
            .init(color: .purple, ratio: 0.382),
            .init(color: Color(red: 0.72, green: 0.92, blue: 0.16), ratio: 0.541)
        ]

        for (index, time) in [0.0, 1.5, 3.0, 4.5].enumerated() {
            let view = InkWaterBar(segments: segments, fixedTime: time)
                .frame(width: 360, height: 30)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            guard let image = renderer.uiImage else {
                XCTFail("render failed at \(time)")
                continue
            }
            let url = URL(fileURLWithPath: "/tmp/inkbar_\(index).png")
            try XCTUnwrap(image.pngData()).write(to: url)
        }
    }
}
