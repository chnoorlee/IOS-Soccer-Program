import XCTest

final class OnboardingJourneyTests: XCTestCase {
    func testCompetitionDetailSwitchesToSeasonFixturesAndOpensMatchCenter() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let competitions = app.buttons["explore.category.competitions"]
        XCTAssertTrue(competitions.waitForExistence(timeout: 3))
        competitions.tap()
        let competition = app.descendants(matching: .any)[
            "competition.card.demo-premier-league"
        ]
        XCTAssertTrue(competition.waitForExistence(timeout: 3))
        competition.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["competition.detail"]
                .waitForExistence(timeout: 3)
        )
        let latestTab = app.buttons["competition.section.latest"]
        XCTAssertTrue(latestTab.waitForExistence(timeout: 3))
        latestTab.tap()
        let competitionNews = app.descendants(matching: .any)["competition.content.news"]
        scrollUntilHittable(competitionNews, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["competition.content.article.article-1"]
                .waitForExistence(timeout: 3)
        )
        let competitionVideos = app.descendants(matching: .any)["competition.content.videos"]
        scrollUntilHittable(competitionVideos, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["competition.content.video.video-highlight-1"]
                .waitForExistence(timeout: 3)
        )
        let fixturesTab = app.buttons["competition.section.fixtures"]
        let sectionRail = app.descendants(matching: .any)["competition.sections.scroll"]
        scrollTowardTopUntilHittable(sectionRail, in: app)
        if !fixturesTab.isHittable {
            sectionRail.swipeLeft()
        }
        XCTAssertTrue(fixturesTab.isHittable)
        fixturesTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["competition.fixtures"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["competition.fixtures.section.live"]
                .waitForExistence(timeout: 3)
        )
        let liveFixture = app.descendants(matching: .any)[
            "competition.fixture.fixture-live-1"
        ]
        scrollUntilHittable(liveFixture, in: app)
        liveFixture.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.screen"]
                .waitForExistence(timeout: 5)
        )
        let broadcastGuide = app.descendants(matching: .any)["matchCenter.broadcasts"]
        scrollUntilHittable(broadcastGuide, in: app)
        XCTAssertTrue(broadcastGuide.exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.broadcast.SA.0"].exists
        )
        let matchMoments = app.descendants(matching: .any)[
            "matchCenter.content.moments"
        ]
        scrollUntilHittable(matchMoments, in: app)
        let openingGoal = app.descendants(matching: .any)[
            "matchCenter.moment.moment-opening-goal"
        ]
        XCTAssertTrue(openingGoal.waitForExistence(timeout: 3))
        openingGoal.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["video.detail"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["video.availability"]
                .waitForExistence(timeout: 3)
        )
    }

    func testCompetitionArchiveKeepsHistoricalFixturesInTheirSelectedSeason() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let competitions = app.buttons["explore.category.competitions"]
        XCTAssertTrue(competitions.waitForExistence(timeout: 3))
        competitions.tap()
        let competition = app.descendants(matching: .any)[
            "competition.card.demo-premier-league"
        ]
        XCTAssertTrue(competition.waitForExistence(timeout: 3))
        competition.tap()

        let archive = app.descendants(matching: .any)["competition.season.archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 3))
        scrollUntilHittable(archive, in: app)
        archive.tap()
        let archivedSeason = app.buttons[
            "competition.season.option.demo-season-2025-26"
        ]
        XCTAssertTrue(archivedSeason.waitForExistence(timeout: 3))
        archivedSeason.tap()

        let fixturesTab = app.buttons["competition.section.fixtures"]
        let sectionRail = app.descendants(matching: .any)["competition.sections.scroll"]
        scrollTowardTopUntilHittable(sectionRail, in: app)
        if !fixturesTab.isHittable {
            sectionRail.swipeLeft()
        }
        XCTAssertTrue(fixturesTab.isHittable)
        fixturesTab.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["competition.fixtures.section.results"]
                .waitForExistence(timeout: 3)
        )
        let historicalFixture = app.descendants(matching: .any)[
            "competition.fixture.fixture-history-season-2025-26-final"
        ]
        scrollUntilHittable(historicalFixture, in: app)
        historicalFixture.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.screen"]
                .waitForExistence(timeout: 5)
        )
    }

    func testFixtureDeepLinkWaitsForOnboardingAndOpensMatchCenter() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-onboarding",
            "-ui-test-reset-history",
            "-ui-test-deep-link",
            "sportshub://fixtures/fixture-live-1"
        ]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["matchCenter.screen"].exists)
        english.tap()

        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.screen"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.tabBars.buttons["Matches"].isSelected)
        XCTAssertTrue(
            app.descendants(matching: .any)["share.fixtures.fixture-live-1"]
                .waitForExistence(timeout: 3)
        )
        let liveActivityControl = app.descendants(matching: .any)[
            "match.activity.control"
        ]
        scrollUntilHittable(liveActivityControl, in: app)
        XCTAssertTrue(liveActivityControl.exists)
        XCTAssertTrue(app.buttons["match.activity.toggle"].exists)
    }

    func testHomeAnnouncesAnOfflinePublicSnapshotWithoutCallingItDemoData() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-onboarding",
            "-ui-test-seed-offline-freshness"
        ]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["freshness.home.offlineSnapshot"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["freshness.home.demo"].exists
        )
    }

    func testUserCanFollowTeamAndOpenHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.title"].waitForExistence(timeout: 3)
        )

        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()

        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["home.screen"].waitForExistence(timeout: 3)
        )
    }

    func testUserCanChoosePlayerAndCompetitionDuringOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()

        let player = app.buttons["onboarding.player.player-tariq"]
        scrollUntilHittable(player, in: app)
        player.tap()

        let competition = app.buttons[
            "onboarding.competition.demo-premier-league"
        ]
        scrollUntilHittable(competition, in: app)
        competition.tap()

        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        scrollUntilHittable(continueButton, in: app)
        continueButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["home.screen"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "home.interest.PLAYER.player-tariq"
            ].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "home.interest.COMPETITION.demo-premier-league"
            ].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["home.relatedMatches"]
                .waitForExistence(timeout: 3)
        )
        let competitionMatch = app.descendants(matching: .any)[
            "match.card.fixture-upcoming-1"
        ]
        XCTAssertTrue(competitionMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(competitionMatch.label.contains("Followed competition"))
        let latestNews = app.descendants(matching: .any)["home.latestNews"]
        scrollUntilHittable(latestNews, in: app)
        XCTAssertFalse(app.descendants(matching: .any)["home.forYou"].exists)
        let followingTab = app.tabBars.buttons["Following"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 3))
        followingTab.tap()
        let competitionCard = app.descendants(matching: .any)[
            "following.entity.COMPETITION.demo-premier-league"
        ]
        scrollUntilHittable(competitionCard, in: app)
        let playerCard = app.descendants(matching: .any)[
            "following.entity.PLAYER.player-tariq"
        ]
        scrollUntilHittable(playerCard, in: app)
    }

    func testUserCanSkipOnboardingWithoutCreatingInterests() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        waitUntilEnabled(skip)
        skip.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["home.screen"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["home.interests.empty"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["home.importantMatches"]
                .waitForExistence(timeout: 3)
        )
        let latestNews = app.descendants(matching: .any)["home.latestNews"]
        scrollUntilHittable(latestNews, in: app)
        let savedScope = app.buttons["home.newsScope.saved"]
        scrollUntilHittable(savedScope, in: app)
        savedScope.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["home.news.empty.saved"]
                .waitForExistence(timeout: 3)
        )
        let followingTab = app.tabBars.buttons["Following"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 3))
        followingTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["following.interests.empty"]
                .waitForExistence(timeout: 3)
        )
    }

    func testHomeNewsCategoryFilterUsesOnlyPayloadCategories() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        waitUntilEnabled(skip)
        skip.tap()

        let latestNews = app.descendants(matching: .any)["home.latestNews"]
        XCTAssertTrue(latestNews.waitForExistence(timeout: 3))
        scrollUntilHittable(latestNews, in: app)
        let firstArticle = app.descendants(matching: .any)["article.card.article-1"]
        XCTAssertTrue(firstArticle.waitForExistence(timeout: 3))
        XCTAssertTrue(firstArticle.label.contains("Reactions: 202"))
        XCTAssertTrue(firstArticle.label.contains("Published comments: 3"))
        XCTAssertFalse(firstArticle.label.contains("Image unavailable"))

        let statistics = app.buttons["home.newsCategory.category.statistics"]
        scrollUntilHittable(statistics, in: app)
        XCTAssertFalse(app.buttons["home.newsCategory.category.transfers"].exists)
        statistics.tap()

        XCTAssertTrue(statistics.isSelected)
        let visualArticle = app.descendants(matching: .any)["article.card.article-2"]
        XCTAssertTrue(visualArticle.waitForExistence(timeout: 3))
        waitUntilAbsent(firstArticle)
        scrollUntilHittable(visualArticle, in: app)
        visualArticle.tap()

        let visualBrief = app.descendants(matching: .any)["article.visualBrief"]
        XCTAssertTrue(visualBrief.waitForExistence(timeout: 3))
        let matchPulse = app.descendants(matching: .any)["article.visual.section.match-pulse"]
        scrollUntilHittable(matchPulse, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["article.visual.item.metric-shots"]
                .waitForExistence(timeout: 3)
        )
    }

    func testHomeMatchStatusFilterPreservesFixtureIdentity() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        waitUntilEnabled(skip)
        skip.tap()

        let liveFilter = app.buttons["home.matchFilter.live"]
        scrollUntilHittable(liveFilter, in: app)
        liveFilter.tap()
        XCTAssertTrue(liveFilter.isSelected)

        let liveFixture = app.descendants(matching: .any)["match.card.fixture-live-1"]
        XCTAssertTrue(liveFixture.waitForExistence(timeout: 3))
        waitUntilAbsent(
            app.descendants(matching: .any)["match.card.fixture-upcoming-1"]
        )
        waitUntilAbsent(
            app.descendants(matching: .any)["match.card.fixture-finished-1"]
        )

        let filterRail = app.scrollViews["home.matchFilters.scroll"]
        XCTAssertTrue(filterRail.waitForExistence(timeout: 3))
        let upcomingFilter = app.buttons["home.matchFilter.upcoming"]
        scrollHorizontallyUntilHittable(upcomingFilter, in: filterRail)
        upcomingFilter.tap()
        XCTAssertTrue(upcomingFilter.isSelected)

        XCTAssertTrue(
            app.descendants(matching: .any)["match.card.fixture-upcoming-1"]
                .waitForExistence(timeout: 3)
        )
        waitUntilAbsent(liveFixture)
    }

    func testMatchesCombineFiveDayCompetitionAndLiveFilters() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        waitUntilEnabled(skip)
        skip.tap()

        let matchesTab = app.tabBars.buttons["Matches"]
        XCTAssertTrue(matchesTab.waitForExistence(timeout: 3))
        matchesTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matches.screen"]
                .waitForExistence(timeout: 3)
        )

        for offset in -2...2 {
            XCTAssertTrue(
                app.buttons["matches.day.\(offset)"].waitForExistence(timeout: 3)
            )
        }
        XCTAssertTrue(app.buttons["matches.day.0"].isSelected)

        let leagueGroup = app.descendants(matching: .any)[
            "matches.group.demo-premier-league"
        ]
        XCTAssertTrue(leagueGroup.waitForExistence(timeout: 3))
        let cupGroup = app.descendants(matching: .any)["matches.group.demo-cup"]
        XCTAssertTrue(cupGroup.waitForExistence(timeout: 3))
        let cupFixture = app.descendants(matching: .any)[
            "matches.fixture.fixture-cup-upcoming-1"
        ]
        scrollUntilHittable(cupFixture, in: app)

        let cupFilter = app.buttons["matches.competition.demo-cup"]
        scrollTowardTopUntilHittable(cupFilter, in: app)
        let competitionRail = app.scrollViews["matches.competitions.scroll"]
        XCTAssertTrue(competitionRail.waitForExistence(timeout: 3))
        scrollHorizontallyUntilHittable(cupFilter, in: competitionRail)
        cupFilter.tap()
        XCTAssertTrue(cupFilter.isSelected)
        waitUntilAbsent(leagueGroup)
        XCTAssertTrue(
            cupFixture.waitForExistence(timeout: 3)
        )

        let liveFilter = app.buttons["matches.status.live"]
        scrollTowardTopUntilHittable(liveFilter, in: app)
        liveFilter.tap()
        XCTAssertTrue(liveFilter.isSelected)
        XCTAssertTrue(
            app.descendants(matching: .any)["matches.empty.liveInCompetition"]
                .waitForExistence(timeout: 3)
        )

        let allStatus = app.buttons["matches.status.all"]
        scrollTowardTopUntilHittable(allStatus, in: app)
        allStatus.tap()
        let tomorrow = app.buttons["matches.day.1"]
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 3))
        let dayRail = app.scrollViews["matches.days.scroll"]
        XCTAssertTrue(dayRail.waitForExistence(timeout: 3))
        scrollHorizontallyUntilHittable(tomorrow, in: dayRail)
        tomorrow.tap()
        XCTAssertTrue(tomorrow.isSelected)
        XCTAssertTrue(
            app.descendants(matching: .any)["matches.empty.date"]
                .waitForExistence(timeout: 3)
        )
    }

    func testMatchesCalendarAndScopedSearchEntryPoints() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        waitUntilEnabled(skip)
        skip.tap()

        let matchesTab = app.tabBars.buttons["Matches"]
        XCTAssertTrue(matchesTab.waitForExistence(timeout: 3))
        matchesTab.tap()
        let leagueGroup = app.descendants(matching: .any)[
            "matches.group.demo-premier-league"
        ]
        XCTAssertTrue(leagueGroup.waitForExistence(timeout: 3))

        let calendarButton = app.buttons["matches.toolbar.calendar"]
        XCTAssertTrue(calendarButton.waitForExistence(timeout: 3))
        calendarButton.tap()
        let calendarSheet = app.descendants(matching: .any)["matches.calendar.sheet"]
        XCTAssertTrue(calendarSheet.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["matches.calendar.datePicker"]
                .waitForExistence(timeout: 3)
        )
        let today = app.buttons["matches.calendar.today"]
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        today.tap()
        let applyDate = app.buttons["matches.calendar.apply"]
        XCTAssertTrue(applyDate.waitForExistence(timeout: 3))
        applyDate.tap()
        waitUntilAbsent(calendarSheet)
        XCTAssertTrue(leagueGroup.waitForExistence(timeout: 3))

        let searchButton = app.buttons["matches.toolbar.search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
        searchButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matches.search.sheet"]
                .waitForExistence(timeout: 3)
        )
        let field = app.textFields["matches.search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Falcons")
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "matches.search.result.fixture-live-1"
            ].waitForExistence(timeout: 3)
        )

        let clear = app.buttons["matches.search.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        clear.tap()
        field.typeText("zzzzzz")
        XCTAssertTrue(
            app.descendants(matching: .any)["matches.search.empty"]
                .waitForExistence(timeout: 3)
        )
    }

    func testMatchesFollowingScopeUsesExplicitTeamRelationshipAndComposesWithLive() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let matchesTab = app.tabBars.buttons["Matches"]
        XCTAssertTrue(matchesTab.waitForExistence(timeout: 3))
        matchesTab.tap()

        let following = app.buttons["matches.scope.following"]
        XCTAssertTrue(following.waitForExistence(timeout: 3))
        waitUntilEnabled(following)
        following.tap()
        XCTAssertTrue(following.isSelected)

        let liveFixture = app.descendants(matching: .any)[
            "matches.fixture.fixture-live-1"
        ]
        scrollUntilHittable(liveFixture, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "matches.followReason.fixture-live-1"
            ].exists
        )
        waitUntilAbsent(
            app.descendants(matching: .any)[
                "matches.fixture.fixture-upcoming-1"
            ]
        )
        waitUntilAbsent(
            app.descendants(matching: .any)[
                "matches.fixture.fixture-cup-upcoming-1"
            ]
        )

        let finishedFixture = app.descendants(matching: .any)[
            "matches.fixture.fixture-finished-1"
        ]
        scrollUntilHittable(finishedFixture, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "matches.followReason.fixture-finished-1"
            ].exists
        )

        let liveStatus = app.buttons["matches.status.live"]
        scrollTowardTopUntilHittable(liveStatus, in: app)
        liveStatus.tap()
        XCTAssertTrue(liveStatus.isSelected)
        XCTAssertTrue(following.isSelected)
        waitUntilAbsent(finishedFixture)
        scrollUntilHittable(liveFixture, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "matches.followReason.fixture-live-1"
            ].exists
        )
    }

    func testProfileInterestEditorPreservesExistingSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()
        let edit = app.buttons["profile.editInterests"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        scrollUntilHittable(edit, in: app)
        edit.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.screen"]
                .waitForExistence(timeout: 3)
        )
        let preservedTeam = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(preservedTeam.waitForExistence(timeout: 3))
        XCTAssertEqual(preservedTeam.value as? String, "Selected")
        let preservedContinue = app.buttons["onboarding.continue"]
        waitUntilEnabled(preservedContinue)
    }

    func testUserCanOpenLiveMatchAndSeeVerifiedUpdateConnection() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let liveMatch = app.descendants(matching: .any)["match.card.fixture-live-1"]
        XCTAssertTrue(liveMatch.waitForExistence(timeout: 3))
        liveMatch.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.screen"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["match.live.status.connected"]
                .waitForExistence(timeout: 3)
        )

        for identifier in [
            "summary",
            "timeline",
            "lineups",
            "statistics",
            "standings",
            "headToHead"
        ] {
            XCTAssertTrue(
                app.buttons["matchCenter.tab.\(identifier)"]
                    .waitForExistence(timeout: 3)
            )
        }

        let tabs = app.scrollViews["matchCenter.tabs"]
        let lineups = app.buttons["matchCenter.tab.lineups"]
        scrollHorizontallyUntilHittable(lineups, in: tabs)
        lineups.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.lineup.player.home-1"]
                .waitForExistence(timeout: 3)
        )

        let statistics = app.buttons["matchCenter.tab.statistics"]
        scrollHorizontallyUntilHittable(statistics, in: tabs)
        statistics.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.statistic.possession"]
                .waitForExistence(timeout: 3)
        )

        let standings = app.buttons["matchCenter.tab.standings"]
        scrollHorizontallyUntilHittable(standings, in: tabs)
        standings.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.standings.loaded"]
                .waitForExistence(timeout: 3)
        )

        let headToHead = app.buttons["matchCenter.tab.headToHead"]
        scrollHorizontallyUntilHittable(headToHead, in: tabs)
        headToHead.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.headToHead.loaded"]
                .waitForExistence(timeout: 3)
        )
    }

    func testUserCanFilterTransferCenterAndOpenPlayer() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()

        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let entry = app.buttons["explore.transferCenter"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["transfer.center.screen"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["transfer.center.boundary"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["transfer.card.transfer-player-tariq"]
                .waitForExistence(timeout: 3)
        )

        let rumored = app.buttons["transfer.filter.rumored"]
        XCTAssertTrue(rumored.waitForExistence(timeout: 3))
        rumored.tap()
        let rumorCard = app.descendants(matching: .any)[
            "transfer.card.transfer-player-salem"
        ]
        XCTAssertTrue(rumorCard.waitForExistence(timeout: 3))
        rumorCard.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["player.detail"]
                .waitForExistence(timeout: 3)
        )
    }

    func testUserCanBrowseSeasonCalendarAndOpenCompetition() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()

        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let entry = app.buttons["explore.seasonCalendar"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["seasonCalendar.screen"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["seasonCalendar.boundary"]
                .waitForExistence(timeout: 3)
        )
        let draw = app.buttons["seasonCalendar.event.calendar-cup-draw"]
        XCTAssertTrue(draw.waitForExistence(timeout: 3))
        draw.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["competition.detail"]
                .waitForExistence(timeout: 3)
        )
    }

    func testUserCanOpenVideoMetadataFromExplore() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()

        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["explore.screen"].waitForExistence(timeout: 3))

        let videos = app.buttons["explore.category.videos"]
        XCTAssertTrue(videos.waitForExistence(timeout: 3))
        videos.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["video.featured.video-original-1"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["video.trending.1.video-highlight-1"]
                .waitForExistence(timeout: 3)
        )

        let sportsRail = app.descendants(matching: .any)["video.sports.scroll"]
        scrollUntilHittable(sportsRail, in: app)
        let esports = app.buttons["video.sport.esports"]
        scrollHorizontallyUntilHittable(esports, in: sportsRail)
        esports.tap()
        let esportsVideo = app.descendants(matching: .any)["video.card.video-esports-1"]
        scrollUntilHittable(esportsVideo, in: app)
        XCTAssertTrue(esportsVideo.exists)

        scrollTowardTopUntilHittable(sportsRail, in: app)
        sportsRail.swipeRight()
        let allSports = app.buttons["video.sport.all"]
        XCTAssertTrue(allSports.waitForExistence(timeout: 3))
        if !allSports.isHittable {
            sportsRail.swipeRight()
        }
        XCTAssertTrue(allSports.isHittable)
        allSports.tap()

        let liveFilter = app.buttons["video.filter.live"]
        XCTAssertTrue(liveFilter.waitForExistence(timeout: 3))
        scrollUntilHittable(liveFilter, in: app)
        liveFilter.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["video.card.video-live-1"]
                .waitForExistence(timeout: 3)
        )

        let filterRail = app.descendants(matching: .any)["video.filters.scroll"]
        if filterRail.exists {
            filterRail.swipeLeft()
        }
        let highlightFilter = app.buttons["video.filter.highlight"]
        XCTAssertTrue(highlightFilter.waitForExistence(timeout: 3))
        highlightFilter.tap()

        let videoCard = app.descendants(matching: .any)["video.card.video-highlight-1"]
        XCTAssertTrue(videoCard.waitForExistence(timeout: 3))
        videoCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["video.detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["video.availability"].exists)
        XCTAssertFalse(app.buttons["video.watch"].exists)
        XCTAssertFalse(app.buttons["video.poster.video-highlight-1.retry"].exists)

        let favorite = app.buttons["video.favorite"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 3))
        if favorite.label == "Remove from saved" {
            favorite.tap()
            XCTAssertTrue(app.buttons["Save video"].waitForExistence(timeout: 3))
        }
        favorite.tap()
        XCTAssertTrue(app.buttons["Remove from saved"].waitForExistence(timeout: 3))

        let descriptionToggle = app.buttons["video.description.toggle"]
        XCTAssertTrue(descriptionToggle.waitForExistence(timeout: 3))
        scrollTowardTopUntilHittable(descriptionToggle, in: app)
        XCTAssertEqual(descriptionToggle.label, "Show more")
        descriptionToggle.tap()
        XCTAssertTrue(app.buttons["Show less"].waitForExistence(timeout: 3))
        app.buttons["Show less"].tap()

        let editorialContext = app.descendants(matching: .any)["video.editorialContext"]
        scrollUntilHittable(editorialContext, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["video.publisher"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["video.program"].exists)

        let relatedReplay = app.descendants(matching: .any)["video.related.video-replay-1"]
        scrollUntilHittable(relatedReplay, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["video.related"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Saved videos"].waitForExistence(timeout: 3))
    }

    func testUserCanBrowseProgramsAndOpenAnAuthorizedEpisode() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let entry = app.buttons["video.programs.entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["video.programs.screen"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["video.programs.boundary"].exists)
        let football = app.buttons["video.programs.filter.football"]
        XCTAssertTrue(football.waitForExistence(timeout: 3))
        football.tap()

        let program = app.descendants(matching: .any)[
            "video.program.card.program-tactics-studio"
        ]
        XCTAssertTrue(program.waitForExistence(timeout: 3))
        program.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["video.program.detail"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["video.program.header"].exists)
        let episode = app.descendants(matching: .any)[
            "video.program.episode.video-original-1"
        ]
        scrollUntilHittable(episode, in: app)
        episode.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["video.detail"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["video.availability"].exists)
        XCTAssertFalse(app.buttons["video.watch"].exists)
    }

    func testUserCanOpenTeamDetailFromExplore() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()

        let onboardingTeam = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(onboardingTeam.waitForExistence(timeout: 3))
        onboardingTeam.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()

        let teams = app.buttons["explore.category.teams"]
        XCTAssertTrue(teams.waitForExistence(timeout: 3))
        teams.tap()

        let teamCard = app.descendants(matching: .any)["team.card.riyadh-falcons"]
        XCTAssertTrue(teamCard.waitForExistence(timeout: 3))
        teamCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["team.detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["team.context.previous"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["team.context.next"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["team.context.freshness"]
                .waitForExistence(timeout: 3)
        )

        let relatedArticle = app.descendants(matching: .any)["article.card.article-1"]
        scrollUntilHittable(relatedArticle, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["team.content.news"].exists)
        let relatedVideo = app.descendants(matching: .any)["video.card.video-highlight-1"]
        scrollUntilHittable(relatedVideo, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["team.content.videos"].exists)
    }

    func testContextualAlertsExplainFollowAudienceWithoutPromisingGuestDelivery() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let onboardingTeam = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(onboardingTeam.waitForExistence(timeout: 3))
        onboardingTeam.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let teams = app.buttons["explore.category.teams"]
        XCTAssertTrue(teams.waitForExistence(timeout: 3))
        teams.tap()
        let teamCard = app.descendants(matching: .any)["team.card.riyadh-falcons"]
        XCTAssertTrue(teamCard.waitForExistence(timeout: 3))
        teamCard.tap()

        let teamAlerts = app.buttons["team.alerts"]
        XCTAssertTrue(teamAlerts.waitForExistence(timeout: 3))
        teamAlerts.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["contextualAlerts.sheet"]
                .waitForExistence(timeout: 3)
        )
        let entityEligibility = app.descendants(matching: .any)[
            "contextualAlerts.eligible"
        ]
        XCTAssertTrue(entityEligibility.waitForExistence(timeout: 3))
        XCTAssertTrue(entityEligibility.label.contains("You follow this item"))
        XCTAssertTrue(app.descendants(matching: .any)["contextualAlerts.scope"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["notifications.accountRequired"].exists
        )
        XCTAssertFalse(app.buttons["notifications.enable"].exists)
        app.buttons["contextualAlerts.close"].tap()
        waitUntilAbsent(app.descendants(matching: .any)["contextualAlerts.sheet"])

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3))
        homeTab.tap()
        let liveMatch = app.descendants(matching: .any)["match.card.fixture-live-1"]
        XCTAssertTrue(liveMatch.waitForExistence(timeout: 3))
        liveMatch.tap()
        let matchAlerts = app.buttons["match.alerts"]
        XCTAssertTrue(matchAlerts.waitForExistence(timeout: 3))
        matchAlerts.tap()

        let fixtureEligibility = app.descendants(matching: .any)[
            "contextualAlerts.eligible"
        ]
        XCTAssertTrue(fixtureEligibility.waitForExistence(timeout: 3))
        XCTAssertTrue(
            fixtureEligibility.label.contains("Eligible because you follow a team")
        )
        XCTAssertTrue(app.descendants(matching: .any)["contextualAlerts.scope"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["notifications.accountRequired"].exists
        )
        XCTAssertFalse(app.buttons["notifications.enable"].exists)
    }

    func testProfileShowsHonestGuestAccountBoundaryInMockBuild() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["profile.authentication.guest"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.staticTexts["Sign in is not enabled in this build. Guest data remains available on this device."]
                .exists
        )
        XCTAssertFalse(app.buttons["profile.signInWithApple"].exists)
        XCTAssertFalse(app.buttons["profile.deleteAccount"].exists)

        let history = app.buttons["profile.watchHistory"]
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["history.screen"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["history.empty"].exists)
    }

    func testFollowingShowsHonestNotificationBoundaryForGuest() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let followingTab = app.tabBars.buttons["Following"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 3))
        followingTab.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["following.screen"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["notifications.accountRequired"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["notifications.enable"].exists)
    }

    func testFollowingTeamDashboardShowsPreviousAndNextAndOpensMatchCenter() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let followingTab = app.tabBars.buttons["Following"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 3))
        followingTab.tap()

        let dashboard = app.descendants(matching: .any)[
            "following.teamDashboard.riyadh-falcons"
        ]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 3))
        scrollUntilHittable(dashboard, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "following.teamDashboard.riyadh-falcons.previous.fixture-finished-1"
            ].waitForExistence(timeout: 3)
        )
        let next = app.descendants(matching: .any)[
            "following.teamDashboard.riyadh-falcons.next.fixture-team-next-1"
        ]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["matchCenter.screen"]
                .waitForExistence(timeout: 5)
        )
    }

    func testGuestCanSaveArticleSeeItInFollowingAndRemoveItWithoutLosingTeam() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["explore.screen"].waitForExistence(timeout: 3)
        )
        let articleCard = app.descendants(matching: .any)["article.card.article-1"]
        XCTAssertTrue(articleCard.waitForExistence(timeout: 3))
        scrollUntilHittable(articleCard, in: app)
        articleCard.tap()
        let save = app.buttons["article.favorite"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        waitUntilEnabled(save)
        if save.label == "Remove from saved" {
            save.tap()
            XCTAssertTrue(app.buttons["Save article"].waitForExistence(timeout: 3))
            waitUntilEnabled(save)
        }
        save.tap()
        XCTAssertTrue(app.buttons["Remove from saved"].waitForExistence(timeout: 3))

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 3))
        homeTab.tap()
        let latestNews = app.descendants(matching: .any)["home.latestNews"]
        XCTAssertTrue(latestNews.waitForExistence(timeout: 3))
        scrollUntilHittable(latestNews, in: app)
        let savedScope = app.buttons["home.newsScope.saved"]
        scrollUntilHittable(savedScope, in: app)
        savedScope.tap()
        XCTAssertTrue(savedScope.isSelected)
        XCTAssertTrue(
            app.descendants(matching: .any)["article.card.article-1"]
                .waitForExistence(timeout: 3)
        )
        waitUntilAbsent(
            app.descendants(matching: .any)["article.card.article-2"]
        )

        let followingTab = app.tabBars.buttons["Following"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 3))
        followingTab.tap()
        let savedArticle = app.descendants(matching: .any)["following.savedArticle.article-1"]
        XCTAssertTrue(savedArticle.waitForExistence(timeout: 3))
        scrollUntilHittable(savedArticle, in: app)
        savedArticle.tap()
        let remove = app.buttons["article.favorite"]
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        waitUntilEnabled(remove)
        remove.tap()
        XCTAssertTrue(app.buttons["Save article"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitUntilAbsent(savedArticle)
        let followedTeam = app.descendants(matching: .any)[
            "following.teamDashboard.riyadh-falcons"
        ]
        XCTAssertTrue(followedTeam.waitForExistence(timeout: 3))
        scrollUntilHittable(followedTeam, in: app)
    }

    func testArticleShowsModeratedCommunityWithDevelopmentReleaseGateLocked() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let articleCard = app.descendants(matching: .any)["article.card.article-1"]
        XCTAssertTrue(articleCard.waitForExistence(timeout: 3))
        scrollUntilHittable(articleCard, in: app)
        articleCard.tap()

        let community = app.descendants(matching: .any)["article.community"]
        XCTAssertTrue(community.waitForExistence(timeout: 3))
        let releaseGate = app.descendants(matching: .any)["community.releaseGate.locked"]
        scrollUntilHittable(releaseGate, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["community.comment.comment-demo-1"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["community.composer.locked"]
                .waitForExistence(timeout: 3)
        )
        let like = app.buttons["community.reaction.like"]
        XCTAssertTrue(like.exists)
        XCTAssertFalse(like.isEnabled)
        XCTAssertFalse(app.buttons["community.composer.submit"].exists)
    }

    func testGuestCanFollowPlayerAndCompetitionAndSeeMixedFollowingCards() {
        let app = XCUIApplication()
        app.launchArguments = ["-reset-onboarding", "-ui-test-reset-history"]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let onboardingTeam = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(onboardingTeam.waitForExistence(timeout: 3))
        onboardingTeam.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let exploreTab = app.tabBars.buttons["Explore"]
        XCTAssertTrue(exploreTab.waitForExistence(timeout: 3))
        exploreTab.tap()
        let competitions = app.buttons["explore.category.competitions"]
        XCTAssertTrue(competitions.waitForExistence(timeout: 3))
        competitions.tap()
        let competitionCard = app.descendants(matching: .any)[
            "competition.card.demo-premier-league"
        ]
        XCTAssertTrue(competitionCard.waitForExistence(timeout: 3))
        competitionCard.tap()
        let competitionFollow = app.buttons["competition.follow"]
        XCTAssertTrue(competitionFollow.waitForExistence(timeout: 3))
        competitionFollow.tap()
        waitUntilEnabled(competitionFollow)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Tariq")
        let playerResult = app.descendants(matching: .any)[
            "search.result.player:player-tariq"
        ]
        XCTAssertTrue(playerResult.waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)["search.summary"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["search.scopes.scroll"]
                .waitForExistence(timeout: 3)
        )
        let playerScope = app.buttons["search.scope.player"]
        XCTAssertTrue(playerScope.waitForExistence(timeout: 3))
        playerScope.tap()
        XCTAssertTrue(playerResult.waitForExistence(timeout: 3))
        playerResult.tap()
        let playerFollow = app.buttons["player.follow"]
        XCTAssertTrue(playerFollow.waitForExistence(timeout: 3))
        playerFollow.tap()
        waitUntilEnabled(playerFollow)
        let playerNews = app.descendants(matching: .any)["player.content.news"]
        scrollUntilHittable(playerNews, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["player.content.article.article-2"]
                .waitForExistence(timeout: 3)
        )
        let playerVideos = app.descendants(matching: .any)["player.content.videos"]
        scrollUntilHittable(playerVideos, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["player.content.video.video-interview-1"]
                .waitForExistence(timeout: 3)
        )

        let followingTab = app.tabBars.buttons["Following"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 3))
        followingTab.tap()
        let playerCard = app.descendants(matching: .any)[
            "following.entity.PLAYER.player-tariq"
        ]
        XCTAssertTrue(playerCard.waitForExistence(timeout: 3))
        scrollUntilHittable(playerCard, in: app)
        let removePlayer = app.buttons["following.unfollow.PLAYER.player-tariq"]
        XCTAssertTrue(removePlayer.waitForExistence(timeout: 3))
        removePlayer.tap()
        waitUntilAbsent(playerCard)

        let competitionFollowing = app.descendants(matching: .any)[
            "following.entity.COMPETITION.demo-premier-league"
        ]
        scrollUntilHittable(competitionFollowing, in: app)
        let teamFollowing = app.descendants(matching: .any)[
            "following.teamDashboard.riyadh-falcons"
        ]
        scrollUntilHittable(teamFollowing, in: app)
    }

    func testUserCanRemoveOneHistoryItemWithoutRemovingAnother() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-onboarding",
            "-ui-test-reset-history",
            "-ui-test-seed-history",
            "-ui-test-seed-public-cache"
        ]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()
        let history = app.buttons["profile.watchHistory"]
        XCTAssertTrue(history.waitForExistence(timeout: 3))
        history.tap()

        let removedItem = app.descendants(matching: .any)["history.item.video-highlight-1"]
        let retainedItem = app.descendants(matching: .any)["history.item.video-original-1"]
        XCTAssertTrue(removedItem.waitForExistence(timeout: 3))
        XCTAssertTrue(retainedItem.waitForExistence(timeout: 3))

        let removeButton = app.buttons["history.remove.video-highlight-1"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 3))
        removeButton.tap()
        let confirmButton = app.buttons["history.remove.confirm.video-highlight-1"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.tap()

        waitUntilAbsent(removedItem)
        XCTAssertTrue(retainedItem.exists)
    }

    func testGuestCanClearDevicePersonalizationFromPrivacyControls() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-onboarding",
            "-ui-test-reset-history",
            "-ui-test-seed-history"
        ]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()
        let privacy = app.buttons["profile.privacy"]
        XCTAssertTrue(privacy.waitForExistence(timeout: 3))
        privacy.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy.screen"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["privacy.deviceSummary"].exists)
        let clear = app.buttons["privacy.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        clear.tap()
        let confirm = app.buttons["privacy.clear.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy.empty"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["privacy.clear"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["privacy.clear.complete"].exists)

        let cacheSummary = app.descendants(matching: .any)["privacy.cache.summary"]
        XCTAssertTrue(cacheSummary.waitForExistence(timeout: 3))
        let clearCache = app.buttons["privacy.cache.clear"]
        scrollUntilHittable(clearCache, in: app)
        clearCache.tap()
        let confirmCacheClear = app.buttons["privacy.cache.clear.confirm"]
        XCTAssertTrue(confirmCacheClear.waitForExistence(timeout: 3))
        confirmCacheClear.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["privacy.cache.empty"].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(app.buttons["privacy.cache.clear"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["privacy.cache.clear.complete"].exists
        )
        XCTAssertTrue(app.descendants(matching: .any)["privacy.empty"].exists)
    }

    func testGuestCanArrangeAFreePredictionWithoutBeingOfferedAccountStorage() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-onboarding",
            "-ui-test-seed-public-cache"
        ]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let game = app.buttons["predictions.game.demo-global-cup-groups"]
        XCTAssertTrue(game.waitForExistence(timeout: 3))
        scrollUntilHittable(game, in: app)
        game.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["predictions.detail"]
                .waitForExistence(timeout: 3)
        )
        let moveJeddahUp = app.buttons[
            "predictions.move.up.demo-group-a.jeddah-waves"
        ]
        XCTAssertTrue(moveJeddahUp.waitForExistence(timeout: 3))
        XCTAssertTrue(moveJeddahUp.isEnabled)
        moveJeddahUp.tap()
        waitUntilDisabled(moveJeddahUp)

        let unavailable = app.descendants(matching: .any)[
            "predictions.account.unavailable"
        ]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 3))
        scrollUntilHittable(unavailable, in: app)
        XCTAssertFalse(app.buttons["predictions.save"].exists)
    }

    func testPremiumPreviewPurchasesVerifiedPassAndSuppressesEligibleAds() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-onboarding",
            "-ui-test-reset-history",
            "-ui-test-premium-preview"
        ]
        app.launch()

        let english = app.buttons["language.english"]
        XCTAssertTrue(english.waitForExistence(timeout: 3))
        english.tap()
        let team = app.buttons["team.riyadh-falcons"]
        XCTAssertTrue(team.waitForExistence(timeout: 3))
        team.tap()
        let continueButton = app.buttons["onboarding.continue"]
        waitUntilEnabled(continueButton)
        continueButton.tap()

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 3))
        profileTab.tap()
        let premiumEntry = app.descendants(matching: .any)["profile.premium"]
        scrollUntilHittable(premiumEntry, in: app)
        premiumEntry.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["premium.screen"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.descendants(matching: .any)["premium.pass"].exists)
        let monthlyOffer = app.buttons[
            "premium.offer.com.example.sportshub.preview.monthly"
        ]
        XCTAssertTrue(monthlyOffer.waitForExistence(timeout: 3))
        scrollUntilHittable(monthlyOffer, in: app)
        monthlyOffer.tap()

        let result = app.descendants(matching: .any)["premium.actionResult"]
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        let ownership = app.descendants(matching: .any)["premium.ownership"]
        scrollTowardTopUntilHittable(ownership, in: app)
        XCTAssertTrue(ownership.label.contains("suppressed"))
    }

    private func waitUntilEnabled(_ element: XCUIElement) {
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: element)
        waitForExpectations(timeout: 3)
    }

    private func waitUntilDisabled(_ element: XCUIElement) {
        let disabled = NSPredicate(format: "isEnabled == false")
        expectation(for: disabled, evaluatedWith: element)
        waitForExpectations(timeout: 3)
    }

    private func waitUntilAbsent(_ element: XCUIElement) {
        let absent = NSPredicate(format: "exists == false")
        expectation(for: absent, evaluatedWith: element)
        waitForExpectations(timeout: 3)
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func scrollTowardTopUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        for _ in 0..<8 where !element.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func scrollHorizontallyUntilHittable(
        _ element: XCUIElement,
        in scrollView: XCUIElement
    ) {
        for _ in 0..<4 where !element.isHittable {
            scrollView.swipeLeft()
        }
        XCTAssertTrue(element.isHittable)
    }
}
