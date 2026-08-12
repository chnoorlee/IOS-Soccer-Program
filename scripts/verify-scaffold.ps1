$ErrorActionPreference = 'Stop'

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDirectory '..')).Path

$requiredFiles = @(
    'project.yml',
    'DECISIONS.md',
    'MATCH-LIVE-CONTRACT.md',
    'MATCH-CONTEXT-CONTRACT.md',
    'MATCH-LINEUP-STATS-CONTRACT.md',
    'LINK-ROUTING-CONTRACT.md',
    'MULTI-ENTITY-FOLLOWS-CONTRACT.md',
    'MULTI-INTEREST-ONBOARDING-CONTRACT.md',
    'EXPLAINABLE-HOME-CONTRACT.md',
    'HOME-NEWS-DISCOVERY-CONTRACT.md',
    'HOME-MATCH-FILTER-CONTRACT.md',
    'MATCHES-DISCOVERY-CONTRACT.md',
    'MATCHES-DATE-SEARCH-CONTRACT.md',
    'MATCHES-FOLLOWING-CONTRACT.md',
    'CONTEXTUAL-ALERTS-CONTRACT.md',
    'MATCH-NOTIFICATION-PREFERENCES-CONTRACT.md',
    'COMPETITION-FIXTURES-CONTRACT.md',
    'VIDEO-DISCOVERY-CONTRACT.md',
    'VIDEO-DETAIL-EDITORIAL-CONTRACT.md',
    'VIDEO-POSTER-MEDIA-CONTRACT.md',
    'VIDEO-PROGRAM-HUB-CONTRACT.md',
    'TEAM-CONTEXT-CONTRACT.md',
    'FIXTURE-CONTENT-CONTRACT.md',
    'FOLLOWING-TEAM-DASHBOARD-CONTRACT.md',
    'PREDICTION-GAMES-CONTRACT.md',
    'BROADCAST-GUIDE-CONTRACT.md',
    'ARTICLE-COMMUNITY-CONTRACT.md',
    'ARTICLE-VISUAL-BRIEF-CONTRACT.md',
    'ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md',
    'ARTICLE-HERO-MEDIA-CONTRACT.md',
    'TRANSFER-CENTER-CONTRACT.md',
    'SEASON-CALENDAR-CONTRACT.md',
    'HISTORICAL-SEASONS-CONTRACT.md',
    'SUBSCRIPTION-AD-FREE-CONTRACT.md',
    'ENTITY-EDITORIAL-CONTENT-CONTRACT.md',
    'ARABIC-SEARCH-CONTRACT.md',
    'WIDGET-LIVE-ACTIVITY-CONTRACT.md',
    'api\openapi.yaml',
    'api\README.md',
    'SportsHub\App\SportsHubApp.swift',
    'SportsHub\App\SportsHubAppDelegate.swift',
    'SportsHub\App\AppEnvironment.swift',
    'SportsHub\App\RootView.swift',
    'SportsHub\App\SportsHubLinkCoordinator.swift',
    'SportsHub\Core\Navigation\SportsHubLink.swift',
    'SportsHub\Core\Data\SportsDataProviding.swift',
    'SportsHub\Core\Data\ArabicSearchNormalizer.swift',
    'SportsHub\Core\Data\MockSportsDataProvider.swift',
    'SportsHub\Core\Data\RemoteSportsDataProvider.swift',
    'SportsHub\Core\Data\SportsDataDTOs.swift',
    'SportsHub\Core\Data\FileSportsDataCache.swift',
    'SportsHub\Core\Data\PublicContentFreshness.swift',
    'SportsHub\Core\Data\MatchLiveTimeline.swift',
    'SportsHub\Core\Data\LocalPersonalizationSportsDataProvider.swift',
    'SportsHub\Core\Data\PersonalVideoStateStore.swift',
    'SportsHub\Core\Data\SessionPersonalizationSportsDataProvider.swift',
    'SportsHub\Core\Community\CommunityConfiguration.swift',
    'SportsHub\Core\Media\ArticleMediaConfiguration.swift',
    'SportsHub\Core\Media\ArticleHeroImageDecoder.swift',
    'SportsHub\Core\Commerce\PremiumSubscriptionModels.swift',
    'SportsHub\Core\Commerce\PremiumSubscriptionModel.swift',
    'SportsHub\Core\Commerce\StoreKitSubscriptionStoreClient.swift',
    'SportsHub\Core\SystemExperience\WidgetMatchSnapshotCoordinator.swift',
    'SportsHub\Core\SystemExperience\MatchLiveActivityCoordinator.swift',
    'SportsHub\Core\Authentication\AuthenticationModels.swift',
    'SportsHub\Core\Authentication\AuthSessionStore.swift',
    'SportsHub\Core\Authentication\AuthenticationClient.swift',
    'SportsHub\Core\Authentication\AuthenticationManager.swift',
    'SportsHub\Core\Networking\HTTPClient.swift',
    'SportsHub\Core\Networking\AccessTokenProvider.swift',
    'SportsHub\Core\Networking\URLSessionHTTPClient.swift',
    'SportsHub\Core\Notifications\NotificationPermissionCoordinator.swift',
    'SportsHub\Core\Notifications\NotificationSettingsModel.swift',
    'SportsHub\Features\Onboarding\OnboardingView.swift',
    'SportsHub\Features\Home\HomeView.swift',
    'SportsHub\Features\Home\HomePersonalization.swift',
    'SportsHub\Features\Home\HomeNewsPresentation.swift',
    'SportsHub\Features\Home\HomeMatchPresentation.swift',
    'SportsHub\Features\Explore\SearchResultsPresentation.swift',
    'SportsHub\Features\Transfers\TransferCenterPresentation.swift',
    'SportsHub\Features\Transfers\TransferCenterView.swift',
    'SportsHub\Features\Calendar\SeasonCalendarPresentation.swift',
    'SportsHub\Features\Calendar\SeasonCalendarView.swift',
    'SportsHub\Features\Matches\MatchesView.swift',
    'SportsHub\Features\Matches\MatchesPresentation.swift',
    'SportsHub\Features\Matches\MatchesDateRail.swift',
    'SportsHub\Features\Matches\MatchesSearchPresentation.swift',
    'SportsHub\Features\Matches\MatchesCalendarSheet.swift',
    'SportsHub\Features\Matches\MatchesSearchView.swift',
    'SportsHub\Features\Matches\MatchesFollowReasonLabel.swift',
    'SportsHub\Features\MatchCenter\MatchCenterView.swift',
    'SportsHub\Features\MatchCenter\MatchLiveStatusView.swift',
    'SportsHub\Features\Teams\TeamDetailView.swift',
    'SportsHub\Features\Teams\TeamContextPresentation.swift',
    'SportsHub\Features\Players\PlayerDetailView.swift',
    'SportsHub\Features\Competitions\CompetitionDetailView.swift',
    'SportsHub\Features\Competitions\CompetitionFixturesPresentation.swift',
    'SportsHub\Features\Competitions\CompetitionLinkDestinationView.swift',
    'SportsHub\Features\Competitions\StandingsTableView.swift',
    'SportsHub\Features\Shared\EntityEditorialContentSection.swift',
    'SportsHub\Features\News\ArticleDetailView.swift',
    'SportsHub\Features\News\ArticleVisualBriefView.swift',
    'SportsHub\Features\News\ArticleEngagementSummaryView.swift',
    'SportsHub\Features\News\ArticleHeroMediaView.swift',
    'SportsHub\Features\News\ArticleCommunitySection.swift',
    'SportsHub\Features\Video\VideoCard.swift',
    'SportsHub\Features\Video\VideoEditorialCards.swift',
    'SportsHub\Features\Video\VideoPosterMediaView.swift',
    'SportsHub\Features\Video\VideoDiscoveryPresentation.swift',
    'SportsHub\Features\Video\VideoDetailView.swift',
    'SportsHub\Features\Video\VideoProgramViews.swift',
    'SportsHub\Features\Video\PlaybackView.swift',
    'SportsHub\Features\Profile\AppleSignInControl.swift',
    'SportsHub\Features\Profile\AccountDeletionView.swift',
    'SportsHub\Features\Profile\PrivacyDataView.swift',
    'SportsHub\Features\Profile\WatchHistoryView.swift',
    'SportsHub\Features\Profile\SubscriptionView.swift',
    'SportsHub\Features\Predictions\PredictionDraft.swift',
    'SportsHub\Features\Predictions\PredictionGamesSection.swift',
    'SportsHub\Features\Predictions\PredictionGameView.swift',
    'SportsHub\Features\Following\NotificationSettingsCard.swift',
    'SportsHub\Features\Following\FollowingView.swift',
    'SportsHub\Features\Following\FollowingTeamSnapshotCard.swift',
    'SportsHub\DesignSystem\ContextualAlertSettingsButton.swift',
    'SportsHub\DesignSystem\SportsFollowButton.swift',
    'SportsHub\DesignSystem\SportsShareButton.swift',
    'SportsHub\Shared\AppEvents.swift',
    'SportsHub\Shared\FixtureFollowMatcher.swift',
    'SportsHub\Shared\ContextualAlertPresentation.swift',
    'SportsHub\Shared\PublicContentStatusView.swift',
    'SportsHub\Shared\WidgetMatchSnapshot.swift',
    'SportsHub\Shared\MatchActivityAttributes.swift',
    'SportsHub\Resources\ar.lproj\Localizable.strings',
    'SportsHub\Resources\en.lproj\Localizable.strings',
    'SportsHub\Resources\SportsHub.entitlements',
    'SportsHubWidgets\SportsHubWidgets.swift',
    'SportsHubWidgets\NextMatchWidget.swift',
    'SportsHubWidgets\MatchLiveActivityWidget.swift',
    'SportsHubWidgets\SportsHubWidgets.entitlements',
    'SportsHubTests\MockSportsDataProviderTests.swift',
    'SportsHubTests\MatchLiveTimelineTests.swift',
    'SportsHubTests\MatchContextContractTests.swift',
    'SportsHubTests\PersonalVideoStateStoreTests.swift',
    'SportsHubTests\RemoteSportsDataProviderTests.swift',
    'SportsHubTests\TransferCenterContractTests.swift',
    'SportsHubTests\SeasonCalendarContractTests.swift',
    'SportsHubTests\HistoricalSeasonCatalogContractTests.swift',
    'SportsHubTests\PremiumSubscriptionContractTests.swift',
    'SportsHubTests\ArticleCommunityTests.swift',
    'SportsHubTests\ArticleVisualBriefContractTests.swift',
    'SportsHubTests\ArticleEngagementSummaryContractTests.swift',
    'SportsHubTests\ArticleHeroMediaContractTests.swift',
    'SportsHubTests\FileSportsDataCacheTests.swift',
    'SportsHubTests\PublicContentFreshnessTests.swift',
    'SportsHubTests\AuthenticationTests.swift',
    'SportsHubTests\NotificationSettingsModelTests.swift',
    'SportsHubTests\NotificationPreferencesContractTests.swift',
    'SportsHubTests\MultiEntityFollowContractTests.swift',
    'SportsHubTests\HomePersonalizationTests.swift',
    'SportsHubTests\HomeNewsPresentationTests.swift',
    'SportsHubTests\HomeMatchPresentationTests.swift',
    'SportsHubTests\MatchesPresentationTests.swift',
    'SportsHubTests\MatchesDateRailTests.swift',
    'SportsHubTests\MatchesSearchPresentationTests.swift',
    'SportsHubTests\FixtureFollowMatcherTests.swift',
    'SportsHubTests\ContextualAlertPresentationTests.swift',
    'SportsHubTests\CompetitionFixturesPresentationTests.swift',
    'SportsHubTests\VideoDiscoveryPresentationTests.swift',
    'SportsHubTests\VideoEditorialDiscoveryPresentationTests.swift',
    'SportsHubTests\VideoEditorialDiscoveryContractTests.swift',
    'SportsHubTests\VideoDetailEditorialContractTests.swift',
    'SportsHubTests\VideoPosterMediaContractTests.swift',
    'SportsHubTests\VideoProgramHubContractTests.swift',
    'SportsHubTests\TeamContextPresentationTests.swift',
    'SportsHubTests\TeamContextContractTests.swift',
    'SportsHubTests\FixtureContentContractTests.swift',
    'SportsHubTests\PredictionGamesContractTests.swift',
    'SportsHubTests\PredictionRemoteProviderTests.swift',
    'SportsHubTests\FixtureBroadcastContractTests.swift',
    'SportsHubTests\EntityEditorialContentContractTests.swift',
    'SportsHubTests\ArabicSearchContractTests.swift',
    'SportsHubTests\WidgetMatchSnapshotTests.swift',
    'SportsHubTests\MatchLiveActivityContractTests.swift',
    'SportsHubTests\SportsHubLinkTests.swift',
    'SportsHubUITests\OnboardingJourneyTests.swift'
)

$missingFiles = @()
foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $missingFiles += $relativePath
    }
}

if ($missingFiles.Count -gt 0) {
    throw "Missing required files: $($missingFiles -join ', ')"
}

function Get-LocalizationKeys {
    param([Parameter(Mandatory)][string]$Path)

    $keys = @()
    foreach ($line in Get-Content -LiteralPath $Path -Encoding utf8) {
        if ($line -match '^\s*"([^"]+)"\s*=') {
            $keys += $Matches[1]
        }
    }
    return $keys | Sort-Object -Unique
}

$englishPath = Join-Path $projectRoot 'SportsHub\Resources\en.lproj\Localizable.strings'
$arabicPath = Join-Path $projectRoot 'SportsHub\Resources\ar.lproj\Localizable.strings'
$englishKeys = Get-LocalizationKeys -Path $englishPath
$arabicKeys = Get-LocalizationKeys -Path $arabicPath

$missingInArabic = Compare-Object $englishKeys $arabicKeys |
    Where-Object SideIndicator -eq '<=' |
    ForEach-Object InputObject
$missingInEnglish = Compare-Object $englishKeys $arabicKeys |
    Where-Object SideIndicator -eq '=>' |
    ForEach-Object InputObject

if ($missingInArabic) {
    throw "Arabic localization is missing: $($missingInArabic -join ', ')"
}
if ($missingInEnglish) {
    throw "English localization is missing: $($missingInEnglish -join ', ')"
}

$requiredLiveLocalizationKeys = @(
    'match.live.connectingTitle',
    'match.live.connectingBody',
    'match.live.waitingTitle',
    'match.live.waitingBody',
    'match.live.lastChecked',
    'match.live.connectedTitle',
    'match.live.lastUpdate',
    'match.live.retryingTitle',
    'match.live.retryingBody',
    'match.live.pausedTitle',
    'match.live.pausedBody',
    'match.live.endedTitle',
    'match.live.endedBody',
    'match.live.stoppedTitle',
    'match.live.stoppedBody',
    'match.live.unavailableTitle',
    'match.live.unavailableBody',
    'match.live.timelineCorrectedAnnouncement',
    'match.live.scoreUpdatedAnnouncement'
)
$missingLiveLocalizationKeys = $requiredLiveLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingLiveLocalizationKeys) {
    throw "Live-match localization is missing: $($missingLiveLocalizationKeys -join ', ')"
}

$requiredLinkLocalizationKeys = @(
    'share.match.fallbackFormat',
    'link.unsupported.title',
    'link.unsupported.body',
    'accessibility.sharesArticle',
    'accessibility.sharesMatch',
    'accessibility.sharesVideo',
    'accessibility.sharesTeam',
    'accessibility.sharesPlayer',
    'accessibility.sharesCompetition'
)
$missingLinkLocalizationKeys = $requiredLinkLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingLinkLocalizationKeys) {
    throw "Sharing-link localization is missing: $($missingLinkLocalizationKeys -join ', ')"
}

$requiredVideoDiscoveryLocalizationKeys = @(
    'video.filterTitle',
    'video.filter.all',
    'video.featured',
    'video.trending',
    'video.trending.rank',
    'video.sportTitle',
    'video.sport.all',
    'video.sport.football',
    'video.sport.basketball',
    'video.sport.esports',
    'video.sport.motorsport',
    'video.sport.combat',
    'video.sport.archery',
    'video.library',
    'video.type.live',
    'video.type.replay',
    'video.type.highlight',
    'video.type.original',
    'video.type.interview',
    'accessibility.filtersVideos',
    'accessibility.filtersVideoSports'
)
$missingVideoDiscoveryLocalizationKeys = $requiredVideoDiscoveryLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingVideoDiscoveryLocalizationKeys) {
    throw "Video discovery localization is missing: $($missingVideoDiscoveryLocalizationKeys -join ', ')"
}

$requiredVideoDetailLocalizationKeys = @(
    'video.about',
    'video.publisher',
    'video.program',
    'video.related',
    'video.showMore',
    'video.showLess',
    'video.poster.unavailable',
    'video.poster.retry',
    'video.poster.creditFormat'
)
$missingVideoDetailLocalizationKeys = $requiredVideoDetailLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingVideoDetailLocalizationKeys) {
    throw "Video detail localization is missing: $($missingVideoDetailLocalizationKeys -join ', ')"
}

$requiredVideoProgramLocalizationKeys = @(
    'video.programs.title',
    'video.programs.entryBody',
    'video.programs.entryHint',
    'video.programs.boundaryTitle',
    'video.programs.boundaryBody',
    'video.programs.filterTitle',
    'video.programs.allSports',
    'video.programs.filterHint',
    'video.programs.featured',
    'video.programs.emptyTitle',
    'video.programs.emptyBody',
    'video.programs.loadMore',
    'video.programs.moreFailed',
    'video.programs.refreshFailed',
    'video.programs.retry',
    'video.programs.episodes',
    'video.programs.noEpisodesTitle',
    'video.programs.noEpisodesBody',
    'video.programs.openHint',
    'video.programs.openFromVideoHint'
)
$missingVideoProgramLocalizationKeys = $requiredVideoProgramLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingVideoProgramLocalizationKeys) {
    throw "Video program localization is missing: $($missingVideoProgramLocalizationKeys -join ', ')"
}

$requiredTeamContextLocalizationKeys = @(
    'team.matchSnapshot',
    'team.previousMatch',
    'team.nextMatch',
    'team.noPreviousMatch',
    'team.noNextMatch',
    'team.latestContent',
    'team.relatedNews',
    'team.noRelatedNews',
    'team.relatedVideos',
    'team.noRelatedVideos'
)
$missingTeamContextLocalizationKeys = $requiredTeamContextLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingTeamContextLocalizationKeys) {
    throw "Team context localization is missing: $($missingTeamContextLocalizationKeys -join ', ')"
}

$requiredEntityEditorialLocalizationKeys = @(
    'competition.latest',
    'competition.latestContent',
    'competition.relatedNews',
    'competition.noRelatedNews',
    'competition.relatedVideos',
    'competition.noRelatedVideos',
    'player.latestContent',
    'player.relatedNews',
    'player.noRelatedNews',
    'player.relatedVideos',
    'player.noRelatedVideos'
)
$missingEntityEditorialLocalizationKeys = $requiredEntityEditorialLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingEntityEditorialLocalizationKeys) {
    throw "Entity editorial localization is missing: $($missingEntityEditorialLocalizationKeys -join ', ')"
}

$requiredFollowLocalizationKeys = @(
    'following.followedInterests',
    'following.noFollowedInterests',
    'following.loadingInterests',
    'following.unavailableInterest',
    'following.unfollowHint',
    'following.type.team',
    'following.type.player',
    'following.type.competition',
    'accessibility.opensCompetition',
    'accessibility.followEntity',
    'accessibility.unfollowEntity',
    'accessibility.updating'
)
$missingFollowLocalizationKeys = $requiredFollowLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingFollowLocalizationKeys) {
    throw "Multi-entity follow localization is missing: $($missingFollowLocalizationKeys -join ', ')"
}

$requiredNotificationPreferenceLocalizationKeys = @(
    'notifications.event.breakingNews',
    'notifications.event.lineup',
    'notifications.event.kickoff',
    'notifications.event.goal',
    'notifications.event.yellowCard',
    'notifications.event.redCard',
    'notifications.event.substitution',
    'notifications.event.halfTime',
    'notifications.event.fullTime'
)
$missingNotificationPreferenceLocalizationKeys = $requiredNotificationPreferenceLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingNotificationPreferenceLocalizationKeys) {
    throw "Notification-preference localization is missing: $($missingNotificationPreferenceLocalizationKeys -join ', ')"
}
if ('notifications.event.card' -in $englishKeys) {
    throw 'The user-facing aggregate card notification preference must remain removed.'
}

$requiredContextualAlertLocalizationKeys = @(
    'contextualAlerts.manage',
    'contextualAlerts.buttonHint',
    'contextualAlerts.title',
    'contextualAlerts.close',
    'contextualAlerts.globalTitle',
    'contextualAlerts.globalBody',
    'contextualAlerts.updatingAudience',
    'contextualAlerts.eligible.entity',
    'contextualAlerts.eligible.fixture.team',
    'contextualAlerts.eligible.fixture.competition',
    'contextualAlerts.eligible.fixture.teamAndCompetition',
    'contextualAlerts.ineligible.entityTitle',
    'contextualAlerts.ineligible.entityBody',
    'contextualAlerts.ineligible.fixtureTitle',
    'contextualAlerts.ineligible.fixtureBody',
    'contextualAlerts.followChoices'
)
$missingContextualAlertLocalizationKeys = $requiredContextualAlertLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingContextualAlertLocalizationKeys) {
    throw "Contextual-alert localization is missing: $($missingContextualAlertLocalizationKeys -join ', ')"
}

$requiredCompetitionFixtureLocalizationKeys = @(
    'competition.fixtures',
    'competition.fixtures.live',
    'competition.fixtures.upcoming',
    'competition.fixtures.results',
    'competition.fixtures.other',
    'competition.sectionHint'
)
$missingCompetitionFixtureLocalizationKeys = $requiredCompetitionFixtureLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingCompetitionFixtureLocalizationKeys) {
    throw "Competition-fixture localization is missing: $($missingCompetitionFixtureLocalizationKeys -join ', ')"
}

$requiredOnboardingLocalizationKeys = @(
    'onboarding.chooseTeams',
    'onboarding.choosePlayers',
    'onboarding.chooseCompetitions',
    'onboarding.skip',
    'onboarding.skipHint',
    'onboarding.catalogErrorBody',
    'onboarding.teamsLoadFailed',
    'onboarding.playersLoadFailed',
    'onboarding.competitionsLoadFailed',
    'profile.editInterests',
    'profile.editInterestsHint',
    'accessibility.interestSelected',
    'accessibility.interestNotSelected'
)
$missingOnboardingLocalizationKeys = $requiredOnboardingLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingOnboardingLocalizationKeys) {
    throw "Multi-interest onboarding localization is missing: $($missingOnboardingLocalizationKeys -join ', ')"
}

$requiredHomeLocalizationKeys = @(
    'home.followedInterests',
    'home.loadingInterests',
    'home.editInterests',
    'home.editInterestsHint',
    'home.noFollowedInterests',
    'home.relatedMatches',
    'home.relatedMatchesExplanation',
    'home.noRelatedMatches',
    'home.reason.team',
    'home.reason.competition',
    'home.reason.teamAndCompetition',
    'home.latestNews',
    'home.news.scope.all',
    'home.news.scope.saved',
    'home.news.scopeHint',
    'home.news.category.all',
    'home.news.categoryHint',
    'home.news.loadingSaved',
    'home.news.savedLoadFailed',
    'home.news.savedLoadFailedBody',
    'home.news.noSaved',
    'home.news.noLatest',
    'home.matches.filterTitle',
    'home.matches.filterHint',
    'home.matches.filter.all',
    'home.matches.filter.live',
    'home.matches.filter.upcoming',
    'home.matches.filter.finished',
    'home.matches.filter.postponed',
    'home.matches.filter.cancelled',
    'home.matches.noRelatedForFilter'
)
$missingHomeLocalizationKeys = $requiredHomeLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingHomeLocalizationKeys) {
    throw "Explainable Home localization is missing: $($missingHomeLocalizationKeys -join ', ')"
}

$requiredArticleVisualBriefLocalizationKeys = @(
    'article.format.story',
    'article.format.visualBrief',
    'article.visual.heroDescription',
    'article.visual.sourceNote'
)
$missingArticleVisualBriefLocalizationKeys = $requiredArticleVisualBriefLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingArticleVisualBriefLocalizationKeys) {
    throw "Article Visual Brief localization is missing: $($missingArticleVisualBriefLocalizationKeys -join ', ')"
}

$requiredArticleEngagementLocalizationKeys = @(
    'article.engagement.reactionsFormat',
    'article.engagement.commentsFormat'
)
$missingArticleEngagementLocalizationKeys = $requiredArticleEngagementLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingArticleEngagementLocalizationKeys) {
    throw "Article engagement localization is missing: $($missingArticleEngagementLocalizationKeys -join ', ')"
}

$requiredArticleHeroMediaLocalizationKeys = @(
    'article.heroMedia.unavailable',
    'article.heroMedia.retry',
    'article.heroMedia.creditFormat'
)
$missingArticleHeroMediaLocalizationKeys = $requiredArticleHeroMediaLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingArticleHeroMediaLocalizationKeys) {
    throw "Article hero-media localization is missing: $($missingArticleHeroMediaLocalizationKeys -join ', ')"
}

$requiredMatchesLocalizationKeys = @(
    'matches.dateFilterTitle',
    'matches.dayHint',
    'matches.statusFilterTitle',
    'matches.statusFilterHint',
    'matches.competitionFilterTitle',
    'matches.allCompetitions',
    'matches.competitionFilterHint',
    'matches.competitionDetails',
    'matches.noLiveFixtures',
    'matches.noLiveFixturesForCompetition',
    'matches.searchTitle',
    'matches.searchButtonHint',
    'matches.calendarTitle',
    'matches.calendarButtonHint',
    'matches.calendarDate',
    'matches.calendarDateHint',
    'matches.calendarTodayHint',
    'matches.cancel',
    'matches.applyDate',
    'matches.searchPrompt',
    'matches.searchScope',
    'matches.closeSearch',
    'matches.clearSearch',
    'matches.searchStart',
    'matches.searchStartBody',
    'matches.searchMoreCharacters',
    'matches.searchMoreCharactersBody',
    'matches.searchNoResults',
    'matches.searchNoResultsBody',
    'matches.searchResults',
    'matches.scopeFilterTitle',
    'matches.scope.all',
    'matches.scope.following',
    'matches.scopeFilterHint',
    'matches.followingLoadingHint',
    'matches.followingFailedHint',
    'matches.loadingFollows',
    'matches.followsLoadFailed',
    'matches.followsLoadFailedBody',
    'matches.retryFollows',
    'matches.noMatchableFollows',
    'matches.noMatchableFollowsBody',
    'matches.noFollowingFixtures',
    'matches.noFollowingFixturesBody',
    'matches.noFollowingFixturesForCompetition',
    'matches.noFollowingFixturesForCompetitionBody',
    'matches.reason.team',
    'matches.reason.competition',
    'matches.reason.teamAndCompetition'
)
$missingMatchesLocalizationKeys = $requiredMatchesLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingMatchesLocalizationKeys) {
    throw "Matches discovery localization is missing: $($missingMatchesLocalizationKeys -join ', ')"
}

$requiredSearchLocalizationKeys = @(
    'search.tooManyCharacters',
    'search.tooManyCharactersBody',
    'search.resultsFor',
    'search.loaded',
    'search.resultsLoadedFormat',
    'search.filterTitle',
    'search.scopeHint',
    'search.scope.all',
    'search.scope.article',
    'search.scope.video',
    'search.scope.team',
    'search.scope.player',
    'search.scope.competition'
)
$missingSearchLocalizationKeys = $requiredSearchLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingSearchLocalizationKeys) {
    throw "Arabic-first search localization is missing: $($missingSearchLocalizationKeys -join ', ')"
}
$searchFormatPaths = @($englishPath, $arabicPath)
foreach ($searchFormatPath in $searchFormatPaths) {
    $searchFormatLines = @(
        Get-Content -LiteralPath $searchFormatPath -Encoding utf8 |
            Where-Object { $_.StartsWith('"search.resultsLoadedFormat"') }
    )
    if ($searchFormatLines.Count -ne 1) {
        throw "Search result-count localization must occur once in $searchFormatPath"
    }
    $searchFormatSource = $searchFormatLines[0]
    foreach ($placeholder in @('%1$lld', '%2$@')) {
        if (-not $searchFormatSource.Contains($placeholder)) {
            throw "Search result-count localization is missing placeholder $placeholder in $searchFormatPath"
        }
    }
}

$requiredPredictionLocalizationKeys = @(
    'predictions.title',
    'predictions.homeTitle',
    'predictions.loading',
    'predictions.emptyTitle',
    'predictions.emptyBody',
    'predictions.loadFailedTitle',
    'predictions.loadFailedBody',
    'predictions.state.open',
    'predictions.state.locked',
    'predictions.state.settled',
    'predictions.state.cancelled',
    'predictions.lockLabel',
    'predictions.nonWager',
    'predictions.nonWagerLong',
    'predictions.instructionsTitle',
    'predictions.instructionsBody',
    'predictions.qualifyingCount',
    'predictions.qualifies',
    'predictions.notQualifying',
    'predictions.moveUpAccessibility',
    'predictions.moveDownAccessibility',
    'predictions.moveHint',
    'predictions.entryTitle',
    'predictions.entryLoading',
    'predictions.entryFailedTitle',
    'predictions.entryFailedBody',
    'predictions.accountUnavailable',
    'predictions.signInBody',
    'predictions.save',
    'predictions.saved',
    'predictions.saveFailed',
    'predictions.lockRejected',
    'predictions.lockedBody',
    'predictions.settledBody',
    'predictions.cancelledBody',
    'predictions.rulesTitle',
    'predictions.rulesSummary',
    'predictions.openRules',
    'predictions.demoRules'
)
$missingPredictionLocalizationKeys = $requiredPredictionLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingPredictionLocalizationKeys) {
    throw "Prediction-game localization is missing: $($missingPredictionLocalizationKeys -join ', ')"
}

$requiredBroadcastLocalizationKeys = @(
    'match.broadcast.title',
    'match.broadcast.rightsNotice',
    'match.broadcast.emptyBody',
    'match.broadcast.rescheduleBody',
    'match.broadcast.commentator',
    'match.broadcast.audioLanguage',
    'match.broadcast.moreOptions'
)
$missingBroadcastLocalizationKeys = $requiredBroadcastLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingBroadcastLocalizationKeys) {
    throw "Broadcast-guide localization is missing: $($missingBroadcastLocalizationKeys -join ', ')"
}

$widgetEnglishKeys = Get-LocalizationKeys -Path (Join-Path $projectRoot 'SportsHubWidgets\en.lproj\Localizable.strings')
$widgetArabicKeys = Get-LocalizationKeys -Path (Join-Path $projectRoot 'SportsHubWidgets\ar.lproj\Localizable.strings')
if (Compare-Object $widgetEnglishKeys $widgetArabicKeys) {
    throw 'Widget localization keys differ between English and Arabic.'
}
$requiredWidgetSurfaceKeys = @(
    'widget.description',
    'widget.noMatch',
    'widget.loadFailed',
    'widget.refreshRequired',
    'widget.state.live',
    'widget.state.halfTime',
    'widget.accessibility.matchFormat',
    'activity.openHint',
    'activity.updatedFormat',
    'activity.accessibilityFormat'
)
$missingWidgetSurfaceKeys = $requiredWidgetSurfaceKeys |
    Where-Object { $_ -notin $widgetEnglishKeys }
if ($missingWidgetSurfaceKeys) {
    throw "Widget/Live Activity localization is missing: $($missingWidgetSurfaceKeys -join ', ')"
}

$requiredLiveSurfaceLocalizationKeys = @(
    'match.activity.title',
    'match.activity.active',
    'match.activity.inactive',
    'match.activity.localUpdatesOnly',
    'match.activity.start',
    'match.activity.stop',
    'match.activity.error.disabled',
    'match.activity.error.invalidData',
    'match.activity.error.request'
)
$missingLiveSurfaceLocalizationKeys = $requiredLiveSurfaceLocalizationKeys |
    Where-Object { $_ -notin $englishKeys }
if ($missingLiveSurfaceLocalizationKeys) {
    throw "Match Live Activity localization is missing: $($missingLiveSurfaceLocalizationKeys -join ', ')"
}

$swiftFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'SportsHub') -Recurse -File -Filter '*.swift'
$swiftFiles += Get-ChildItem -LiteralPath (Join-Path $projectRoot 'SportsHubWidgets') -Recurse -File -Filter '*.swift'
$swiftContent = $swiftFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName -Encoding utf8 }
$allSwiftContent = $swiftContent -join "`n"

$forbiddenBrandPattern = '(?i)\b(GOAT|Koora\s*Break|SEC\s*Sports|Jdwal)\b'
if ($allSwiftContent -match $forbiddenBrandPattern) {
    throw 'Reference-app branding was found in product source files.'
}

$unsafePattern = '(?m)\b(try!|as!|fatalError\s*\(|preconditionFailure\s*\()'
if ($allSwiftContent -match $unsafePattern) {
    throw 'An unsafe Swift construct was found in product source files.'
}

$conflictingFramePattern = '(?s)\.frame\((?=[^)]*\bwidth\s*:)(?=[^)]*\b(?:minHeight|idealHeight|maxHeight)\s*:)|(?s)\.frame\((?=[^)]*\bheight\s*:)(?=[^)]*\b(?:minWidth|idealWidth|maxWidth)\s*:)'
if ($allSwiftContent -match $conflictingFramePattern) {
    throw 'A SwiftUI frame call mixes fixed and flexible overload labels.'
}

$networkPattern = '(?i)https?://'
if ($allSwiftContent -match $networkPattern) {
    throw 'A hard-coded network URL was found before provider approval.'
}

$unfinishedPattern = '(?m)\b(TODO|FIXME)\b'
if ($allSwiftContent -match $unfinishedPattern) {
    throw 'An unfinished-code marker was found in product source files.'
}

$linkRouteSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Navigation\SportsHubLink.swift'
) -Encoding utf8
foreach ($collection in @('fixtures', 'articles', 'videos', 'teams', 'players', 'competitions')) {
    if (-not $linkRouteSource.Contains("`"$collection`"")) {
        throw "Deep-link policy is missing route collection $collection"
    }
}
$featureShareSource = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'SportsHub\Features') -Recurse -File -Filter '*.swift' |
    ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName -Encoding utf8 }
$featureShareCount = ([regex]::Matches(($featureShareSource -join "`n"), 'SportsShareButton\(')).Count
if ($featureShareCount -ne 6) {
    throw "Expected exactly six public-entity share entry points; found $featureShareCount"
}
$uncoordinatedShareLinks = $swiftFiles |
    Where-Object { $_.Name -ne 'SportsShareButton.swift' } |
    Where-Object {
        (Get-Content -Raw -LiteralPath $_.FullName -Encoding utf8).Contains('ShareLink(')
    }
if ($uncoordinatedShareLinks) {
    throw 'A ShareLink bypasses the validated public-link policy.'
}
$rootViewSource = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'SportsHub\App\RootView.swift') -Encoding utf8
foreach ($receiver in @('.onOpenURL', '.onContinueUserActivity')) {
    if (-not $rootViewSource.Contains($receiver)) {
        throw "RootView is missing URL receiver $receiver"
    }
}
$linkUITestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubUITests\OnboardingJourneyTests.swift'
) -Encoding utf8
if (-not $linkUITestSource.Contains('testFixtureDeepLinkWaitsForOnboardingAndOpensMatchCenter')) {
    throw 'The onboarding/deep-link UI journey is missing.'
}
if (-not $linkUITestSource.Contains('testGuestCanFollowPlayerAndCompetitionAndSeeMixedFollowingCards')) {
    throw 'The multi-entity Following UI journey is missing.'
}
foreach ($searchJourneyMarker in @(
    'search.summary',
    'search.scopes.scroll',
    'search.scope.player',
    'search.result.player:player-tariq'
)) {
    if (-not $linkUITestSource.Contains($searchJourneyMarker)) {
        throw "The Arabic-first search UI journey is missing $searchJourneyMarker"
    }
}
foreach ($videoDiscoveryMarker in @(
    'video.featured.video-original-1',
    'video.trending.1.video-highlight-1',
    'video.sport.esports',
    'video.card.video-esports-1',
    'video.filter.live',
    'video.filter.highlight',
    'video.card.video-live-1',
    'video.card.video-highlight-1'
)) {
    if (-not $linkUITestSource.Contains($videoDiscoveryMarker)) {
        throw "The video discovery UI journey is missing $videoDiscoveryMarker"
    }
}
foreach ($videoDetailMarker in @(
    'video.description.toggle',
    'video.editorialContext',
    'video.publisher',
    'video.program',
    'video.related.video-replay-1'
)) {
    if (-not $linkUITestSource.Contains($videoDetailMarker)) {
        throw "The video detail UI journey is missing $videoDetailMarker"
    }
}
foreach ($teamContextJourneyMarker in @(
    'team.context.previous',
    'team.context.next',
    'team.context.freshness',
    'article.card.article-1',
    'video.card.video-highlight-1'
)) {
    if (-not $linkUITestSource.Contains($teamContextJourneyMarker)) {
        throw "The team context UI journey is missing $teamContextJourneyMarker"
    }
}

$providerMethods = @(
    'teams',
    'players',
    'competitions',
    'teamDetails',
    'teamContent',
    'teamSquad',
    'playerDetails',
    'playerTransfers',
    'competitionStandings',
    'competitionLeaders',
    'competitionFixtures',
    'homeFeed',
    'fixtures',
    'fixtureDetails',
    'fixtureEventUpdates',
    'fixtureStandings',
    'fixtureHeadToHead',
    'articles',
    'articleDetails',
    'videoDiscovery',
    'videos',
    'videoDetails',
    'continueWatching',
    'watchHistory',
    'removeWatchHistoryItem',
    'clearWatchHistory',
    'watchProgress',
    'saveWatchProgress',
    'favoriteVideos',
    'videoFavorite',
    'setVideoFavorite',
    'follows',
    'setFollow',
    'notificationPreferences',
    'setNotificationPreference',
    'registerNotificationDevice',
    'predictionGames',
    'predictionEntry',
    'savePredictionEntry',
    'createPlaybackSession',
    'search'
)
foreach ($providerRelativePath in @(
    'SportsHub\Core\Data\MockSportsDataProvider.swift',
    'SportsHub\Core\Data\RemoteSportsDataProvider.swift',
    'SportsHub\Core\Data\FallbackSportsDataProvider.swift',
    'SportsHub\Core\Data\LocalPersonalizationSportsDataProvider.swift',
    'SportsHub\Core\Data\SessionPersonalizationSportsDataProvider.swift'
)) {
    $providerContent = Get-Content -Raw -LiteralPath (Join-Path $projectRoot $providerRelativePath) -Encoding utf8
    foreach ($method in $providerMethods) {
        if ($providerContent -notmatch "func\s+$method\s*\(") {
            throw "$providerRelativePath does not implement provider method $method"
        }
    }
}

$localizedInitializerPattern = '(?:Text|Button|Label|Section|navigationTitle|LabeledContent|ContentUnavailableView|ProgressView|configurationDisplayName|description)\(\s*"([^"]+\.[^"]+)"'
$referencedLocalizationKeys = [regex]::Matches($allSwiftContent, $localizedInitializerPattern) |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -match '^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$' } |
    Sort-Object -Unique
$knownLocalizationKeys = @($englishKeys) + @($widgetEnglishKeys) | Sort-Object -Unique
$unknownLocalizationKeys = $referencedLocalizationKeys | Where-Object { $_ -notin $knownLocalizationKeys }
if ($unknownLocalizationKeys) {
    throw "Source references unknown localization keys: $($unknownLocalizationKeys -join ', ')"
}

$projectSpec = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'project.yml') -Encoding utf8
foreach ($target in @('SportsHub:', 'SportsHubWidgets:', 'SportsHubTests:', 'SportsHubUITests:')) {
    if (-not $projectSpec.Contains($target)) {
        throw "project.yml does not declare target $target"
    }
}

foreach ($setting in @('SPORTS_API_BASE_URL:', 'SPORTS_AUTH_ENABLED:', 'SPORTS_COMMUNITY_ENABLED:', 'SPORTS_COMMUNITY_STANDARDS_URL:', 'SPORTS_COMMUNITY_SUPPORT_URL:', 'SPORTS_DATA_MODE:', 'SPORTS_PUBLIC_WEB_BASE_URL:', 'SPORTS_MEDIA_ALLOWED_HOSTS:', 'SPORTS_PREMIUM_MONTHLY_PRODUCT_ID:', 'SPORTS_PREMIUM_ANNUAL_PRODUCT_ID:', 'SPORTS_PREMIUM_PRIVACY_URL:', 'SPORTS_PREMIUM_TERMS_URL:', 'SPORTS_ADVERTISING_ENABLED:', 'SPORTS_APP_GROUP_ID:', 'CODE_SIGN_ENTITLEMENTS:', 'APS_ENVIRONMENT:')) {
    if (-not $projectSpec.Contains($setting)) {
        throw "project.yml does not declare setting $setting"
    }
}
if ($projectSpec -notmatch 'SPORTS_PUBLIC_WEB_BASE_URL:\s*""') {
    throw 'The repository must not fabricate a production public share domain.'
}
if ($projectSpec -notmatch 'SPORTS_MEDIA_ALLOWED_HOSTS:\s*""') {
    throw 'Article media hosts must fail closed until an authorized CDN is configured.'
}
if ($projectSpec -notmatch 'SPORTS_COMMUNITY_ENABLED:\s*false') {
    throw 'Community mutations must remain disabled in checked-in configuration.'
}
foreach ($communityURLSetting in @('SPORTS_COMMUNITY_STANDARDS_URL', 'SPORTS_COMMUNITY_SUPPORT_URL')) {
    if ($projectSpec -notmatch "$communityURLSetting`:\s*`"`"") {
        throw "$communityURLSetting must remain empty until a publisher-controlled URL exists."
    }
}
foreach ($premiumSetting in @(
    'SPORTS_PREMIUM_MONTHLY_PRODUCT_ID',
    'SPORTS_PREMIUM_ANNUAL_PRODUCT_ID',
    'SPORTS_PREMIUM_PRIVACY_URL',
    'SPORTS_PREMIUM_TERMS_URL'
)) {
    if ($projectSpec -notmatch "$premiumSetting`:\s*`"`"") {
        throw "$premiumSetting must remain empty until App Store Connect and publisher configuration exist."
    }
}
if ($projectSpec -notmatch 'SPORTS_ADVERTISING_ENABLED:\s*false') {
    throw 'Advertising must remain disabled in checked-in configuration.'
}
foreach ($widgetProjectMarker in @(
    'SportsHub/Shared/WidgetMatchSnapshot.swift',
    'SportsHubWidgets/SportsHubWidgets.entitlements',
    'group.com.example.sportshub.shared'
)) {
    if (-not $projectSpec.Contains($widgetProjectMarker)) {
        throw "project.yml is missing Widget/App Group marker $widgetProjectMarker"
    }
}

$apiContract = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'api\openapi.yaml') -Encoding utf8
foreach ($contractMarker in @('openapi: 3.1.0', '/home:', '/fixtures:', '/fixtures/{fixtureId}/events:', '/fixtures/{fixtureId}/standings:', '/fixtures/{fixtureId}/head-to-head:', '/teams:', '/players:', 'operationId: listPlayers', '/articles:', '/articles/{articleId}/comments:', '/articles/{articleId}/reaction:', '/community/comments/{commentId}/reports:', '/me/community-blocks/{authorId}:', '/videos:', '/playback-session:', '/auth/apple:', '/auth/refresh:', '/auth/logout:', '/me/guest-merge:', '/me/follows:', '/me/notification-preferences:', '/me/notification-devices/{installationId}:', '/me/watch-history:', '/me/watch-progress:', '/me/article-favorites:', '/me/article-favorites/{articleId}:', '/me/video-favorites:', 'deleteMyAccount', 'deleteMyWatchProgress', 'application/problem+json')) {
    if (-not $apiContract.Contains($contractMarker)) {
        throw "API contract is missing marker $contractMarker"
    }
}
foreach ($notificationPreferenceAPIMarker in @(
    'yellowCard: { type: boolean }',
    'redCard: { type: boolean }',
    'substitution: { type: boolean }',
    'deprecated: true',
    'Legacy aggregate that is true only when both granular card preferences are enabled.',
    'Legacy write that sets both yellowCard and redCard to the supplied value.'
)) {
    if (-not $apiContract.Contains($notificationPreferenceAPIMarker)) {
        throw "Notification-preference API contract is missing $notificationPreferenceAPIMarker"
    }
}
foreach ($articleVisualBriefAPIMarker in @(
    'ArticleFormat:',
    'enum: [STORY, VISUAL_BRIEF]',
    'ArticleVisualBrief:',
    'enum: [METRIC_GRID, COMPARISON, SEQUENCE]',
    'minItems: 1',
    'maxItems: 4',
    'const: VISUAL_BRIEF',
    'Required and non-null when format is VISUAL_BRIEF'
)) {
    if (-not $apiContract.Contains($articleVisualBriefAPIMarker)) {
        throw "Article Visual Brief API contract is missing $articleVisualBriefAPIMarker"
    }
}
foreach ($articleEngagementAPIMarker in @(
    'ArticleEngagementSummary:',
    'required: [totalReactions, publishedComments]',
    'maximum: 2000000000',
    'format, engagement, heroMedia]',
    'hide the summary rather than treating it as zero'
)) {
    if (-not $apiContract.Contains($articleEngagementAPIMarker)) {
        throw "Article engagement API contract is missing $articleEngagementAPIMarker"
    }
}
foreach ($articleHeroMediaAPIMarker in @(
    'ArticleHeroMedia:',
    'ArticleHeroAlternativeText:',
    'ArticleHeroCredit:',
    'enum: [image/jpeg, image/png, image/webp, image/heic, image/heif]',
    'Credentials, fragments and custom ports are forbidden.',
    'maxLength: 2048',
    'heroMedia:',
    'Required as an explicit object or null in current responses.'
)) {
    if (-not $apiContract.Contains($articleHeroMediaAPIMarker)) {
        throw "Article hero-media API contract is missing $articleHeroMediaAPIMarker"
    }
}
foreach ($videoPosterMediaAPIMarker in @(
    'VideoPosterMedia:',
    'VideoPosterAlternativeText:',
    'VideoPosterCredit:',
    'required: [id, type, title, poster, durationSeconds, isPlayable]',
    'It does not grant playback eligibility.'
)) {
    if (-not $apiContract.Contains($videoPosterMediaAPIMarker)) {
        throw "Video poster-media API contract is missing $videoPosterMediaAPIMarker"
    }
}
foreach ($competitionFixtureContractMarker in @(
    '/competitions/{competitionId}/fixtures:',
    'operationId: listCompetitionFixtures',
    'CompetitionFixtureListResponse:',
    'required: [competitionId, seasonId, data, page]',
    'globally ordered sequence'
)) {
    if (-not $apiContract.Contains($competitionFixtureContractMarker)) {
        throw "Competition fixture API contract is missing $competitionFixtureContractMarker"
    }
}
foreach ($historicalSeasonContractMarker in @(
    'SeasonSummary:',
    'currentSeasonId:',
    'maxItems: 50',
    'ordered by startDate',
    'exactly one matching entry has isCurrent true'
)) {
    if (-not $apiContract.Contains($historicalSeasonContractMarker)) {
        throw "Historical-season API contract is missing $historicalSeasonContractMarker"
    }
}
foreach ($teamContextContractMarker in @(
    '/teams/{teamId}/content:',
    'operationId: getTeamContent',
    'TeamContentResponse:',
    'Must echo the requested path teamId',
    'This response grants no playback entitlement'
)) {
    if (-not $apiContract.Contains($teamContextContractMarker)) {
        throw "Team context API contract is missing $teamContextContractMarker"
    }
}
foreach ($entityEditorialContractMarker in @(
    '/players/{playerId}/content:',
    'operationId: getPlayerContent',
    'PlayerContentResponse:',
    'Must echo the requested path playerId',
    '/competitions/{competitionId}/content:',
    'operationId: getCompetitionContent',
    'CompetitionContentResponse:',
    'Must echo the requested path competitionId',
    'season-independent, server-authoritative competition association'
)) {
    if (-not $apiContract.Contains($entityEditorialContractMarker)) {
        throw "Entity editorial API contract is missing $entityEditorialContractMarker"
    }
}
foreach ($videoDetailContractMarker in @(
    '/videos/{videoId}:',
    'VideoDetail:',
    'VideoProgram:',
    'relatedVideos:',
    'Complete server-authored order; IDs must be unique and exclude the current video.'
)) {
    if (-not $apiContract.Contains($videoDetailContractMarker)) {
        throw "Video detail API contract is missing $videoDetailContractMarker"
    }
}
foreach ($predictionContractMarker in @(
    '/prediction-games:',
    '/prediction-games/{gameId}/entries/me:',
    'operationId: listPredictionGames',
    'operationId: getMyPredictionEntry',
    'operationId: putMyPredictionEntry',
    'PredictionGroup:',
    'PredictionGroupRanking:',
    'qualifyingPositions:',
    'orderedTeamIds:'
)) {
    if (-not $apiContract.Contains($predictionContractMarker)) {
        throw "Prediction-game API contract is missing $predictionContractMarker"
    }
}

foreach ($broadcastContractMarker in @(
    'Broadcast:',
    'BroadcastLocalizedText:',
    'regionCode:',
    "pattern: '^[A-Z]{2}$'",
    'audioLanguageCode:',
    'maxItems: 12',
    'maxLength: 100',
    'intentionally contains no URL'
)) {
    if (-not $apiContract.Contains($broadcastContractMarker)) {
        throw "Broadcast-guide API contract is missing $broadcastContractMarker"
    }
}

$onboardingSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Onboarding\OnboardingView.swift'
) -Encoding utf8
foreach ($onboardingMarker in @(
    'onboarding.section.teams',
    'onboarding.section.players',
    'onboarding.section.competitions',
    'provider.teams()',
    'provider.players()',
    'provider.competitions()',
    'appModel.skipOnboarding()',
    'onboarding.player.',
    'onboarding.competition.',
    'accessibilityFocused($focusedError'
)) {
    if (-not $onboardingSource.Contains($onboardingMarker)) {
        throw "Onboarding UI is missing multi-interest marker $onboardingMarker"
    }
}

$onboardingUITestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubUITests\OnboardingJourneyTests.swift'
) -Encoding utf8
foreach ($journey in @(
    'testUserCanChoosePlayerAndCompetitionDuringOnboarding',
    'testUserCanSkipOnboardingWithoutCreatingInterests',
    'testProfileInterestEditorPreservesExistingSelection'
)) {
    if (-not $onboardingUITestSource.Contains($journey)) {
        throw "Onboarding UI journey is missing $journey"
    }
}

foreach ($competitionFixtureJourneyMarker in @(
    'testCompetitionDetailSwitchesToSeasonFixturesAndOpensMatchCenter',
    'competition.section.fixtures',
    'competition.fixtures.section.live',
    'competition.fixture.fixture-live-1',
    'matchCenter.screen'
)) {
    if (-not $onboardingUITestSource.Contains($competitionFixtureJourneyMarker)) {
        throw "Competition fixture UI journey is missing $competitionFixtureJourneyMarker"
    }
}
foreach ($historicalSeasonJourneyMarker in @(
    'testCompetitionArchiveKeepsHistoricalFixturesInTheirSelectedSeason',
    'competition.season.option.demo-season-2025-26',
    'competition.fixture.fixture-history-season-2025-26-final'
)) {
    if (-not $onboardingUITestSource.Contains($historicalSeasonJourneyMarker)) {
        throw "Historical-season UI journey is missing $historicalSeasonJourneyMarker"
    }
}

$competitionDetailSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Competitions\CompetitionDetailView.swift'
) -Encoding utf8
foreach ($competitionDetailMarker in @(
    'case standings',
    'case leaders',
    'case fixtures',
    'competition.section.',
    'competition.fixtures.section.',
    'competition.fixture.',
    'competition.seasonArchive.title',
    'competition.season.archive',
    'competition.season.option.',
    'MatchCenterView(fixtureID:',
    'competitionFixtures(',
    'activeRequestID == requestID',
    'contentRequest == request',
    'dynamicTypeSize.isAccessibilitySize',
    '.accessibilityAddTraits(isSelected ? .isSelected : [])',
    '.accessibilityFocused($loadErrorFocused)'
)) {
    if (-not $competitionDetailSource.Contains($competitionDetailMarker)) {
        throw "Competition detail is missing fixture marker $competitionDetailMarker"
    }
}

$competitionFixturePresentationTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\CompetitionFixturesPresentationTests.swift'
) -Encoding utf8
foreach ($competitionFixtureTestName in @(
    'testEveryFixtureAppearsExactlyOnceInItsSemanticSection',
    'testUpcomingAscendsAndResultsDescendWithStableIDTieBreaks',
    'testEmptyInputHasNoSyntheticSections'
)) {
    if (-not $competitionFixturePresentationTestSource.Contains($competitionFixtureTestName)) {
        throw "Competition fixture presentation coverage is missing $competitionFixtureTestName"
    }
}

$appModelTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\AppModelTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testOnboardingCompletionAcceptsEveryFollowType',
    'testOnboardingRequiresInterestUnlessUserExplicitlySkips',
    'testEditingInterestsPreservesExistingFollows'
)) {
    if (-not $appModelTestSource.Contains($testName)) {
        throw "AppModel onboarding coverage is missing $testName"
    }
}

$mockProviderTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\MockSportsDataProviderTests.swift'
) -Encoding utf8
if (-not $mockProviderTestSource.Contains('testPlayerCatalogReturnsStableProfiles')) {
    throw 'Mock player-catalog coverage is missing.'
}
if (-not $mockProviderTestSource.Contains(
    'testEveryFixtureCompetitionIsDiscoverableAndSupportsCompetitionData'
)) {
    throw 'Mock multi-competition fixture coverage is missing.'
}

$homeSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Home\HomeView.swift'
) -Encoding utf8
foreach ($homeMarker in @(
    'appModel.orderedFollows',
    'HomePersonalization(',
    'home.interest.',
    'home.relatedMatches',
    'home.importantMatches',
    'home.latestNews',
    'HomeMatchPresentation(',
    'home.matchFilters',
    'home.matchFilter.',
    'HomeMatchFilter.availableFilters(',
    'selectedMatchFilter = .all',
    'HomeNewsPresentation(',
    'home.newsScope.',
    'home.newsCategory.',
    'loadSavedArticles(',
    'savedNewsRequestID = nil',
    'savedArticles = nil',
    'dynamicTypeSize.isAccessibilitySize'
)) {
    if (-not $homeSource.Contains($homeMarker)) {
        throw "Home UI is missing explainable aggregation marker $homeMarker"
    }
}
if ($homeSource.Contains('home.forYou')) {
    throw 'Home still labels public articles as personalized content.'
}
if ($homeSource -match '(?i)\b(trending|exclusive|recommended|featured)\b') {
    throw 'Home claims an unsupported news ranking or editorial label.'
}

$homeTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\HomePersonalizationTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testTeamAndCompetitionRelationshipsAreExplainableAndStable',
    'testPlayerFollowNeverInfersFixtureRelationship',
    'testNoFollowsKeepsEveryFixtureInThePublicSection',
    'testRelatedAndPublicFixturesAreACompleteDisjointPartition'
)) {
    if (-not $homeTestSource.Contains($testName)) {
        throw "Explainable Home coverage is missing $testName"
    }
}

$homeNewsTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\HomeNewsPresentationTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testCategoriesUseStableFirstOccurrenceOrderWithoutInventingValues',
    'testAllCategoriesPreservesProviderOrderAndPartitionsFirstFromRest',
    'testCategorySelectionUsesExactKeyAndPreservesRelativeOrder',
    'testMissingSelectionNormalizesToAllCategories',
    'testEmptySourceHasNoCategoriesOrLeadingArticle',
    'testSavedSourceIsPresentedAsProvidedWithoutPublicFeedInference',
    'testAllScopeIgnoresSavedSource'
)) {
    if (-not $homeNewsTestSource.Contains($testName)) {
        throw "Home news discovery coverage is missing $testName"
    }
}

$homeMatchTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\HomeMatchPresentationTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testAllFilterPreservesPartitionsOrderAndReasons',
    'testLiveFilterIncludesLiveAndHalfTimeAcrossBothPartitions',
    'testAvailableFiltersUseCanonicalOrderAndCoverExceptionalStates',
    'testEveryNonLiveFilterMatchesOnlyItsExactState',
    'testUnavailableSelectionNormalizesToAllWithoutDroppingFixtures',
    'testFilteredPartitionsRemainCompleteAndDisjoint',
    'testFilteringPreservesCombinedFollowReason',
    'testFilterCanEmptyRelatedPartitionWithoutHidingGeneralResult',
    'testEmptyInputOffersOnlyAllAndNoFixtures'
)) {
    if (-not $homeMatchTestSource.Contains($testName)) {
        throw "Home match-filter coverage is missing $testName"
    }
}

foreach ($homeJourneyMarker in @(
    'home.interest.PLAYER.player-tariq',
    'home.interest.COMPETITION.demo-premier-league',
    'home.interests.empty',
    'home.latestNews',
    'testHomeNewsCategoryFilterUsesOnlyPayloadCategories',
    'home.newsCategory.category.statistics',
    'home.newsScope.saved',
    'home.news.empty.saved',
    'testHomeMatchStatusFilterPreservesFixtureIdentity',
    'home.matchFilter.live',
    'home.matchFilter.upcoming',
    'home.matchFilters.scroll'
)) {
    if (-not $onboardingUITestSource.Contains($homeJourneyMarker)) {
        throw "Home UI journey is missing $homeJourneyMarker"
    }
}

$matchesSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Matches\MatchesView.swift'
) -Encoding utf8
foreach ($matchesMarker in @(
    'MatchesDateRail.offsets',
    'MatchesPresentation(',
    'matches.days',
    'matches.status.',
    'matches.competition.',
    'matches.group.',
    'matches.fixture.',
    'matches.toolbar.search',
    'matches.toolbar.calendar',
    'MatchesCalendarSheet(',
    'MatchesSearchView(',
    'searchableFixtures',
    'selectedScope: MatchesScope',
    'matches.scopeFilters',
    'matches.scope.',
    'presentation.followReasonsByFixtureID',
    'MatchesFollowReasonLabel(',
    'followLoadRequestID = nil',
    'followsReady = false',
    'followSyncFailed = false',
    'matches.scope.error',
    'matches.scope.retry',
    'let failed = appModel.followError != nil',
    'followsReady = !failed',
    'accessibilityFocused($followErrorFocused)',
    'selectedScope = .all',
    'guard followLoadRequestID == requestID',
    'loadRequestID = nil',
    'fixtures = nil',
    'selectedCompetitionID = normalizedSelection',
    'dynamicTypeSize.isAccessibilitySize'
)) {
    if (-not $matchesSource.Contains($matchesMarker)) {
        throw "Matches UI is missing discovery marker $matchesMarker"
    }
}

$fixtureFollowSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Shared\FixtureFollowMatcher.swift'
) -Encoding utf8
foreach ($followMarker in @(
    'struct FixtureFollowMatcher',
    'follows.lazy.filter { $0.type == .team }',
    'follows.lazy.filter { $0.type == .competition }',
    'fixture.homeTeam.id',
    'fixture.awayTeam.id',
    'fixture.competition.id',
    'case (true, true): return .teamAndCompetition',
    'case (false, false): return nil'
)) {
    if (-not $fixtureFollowSource.Contains($followMarker)) {
        throw "Shared fixture-follow matcher is missing contract marker $followMarker"
    }
}

$fixtureFollowTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\FixtureFollowMatcherTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testTeamFollowMatchesEitherSideAndPreservesUnrelatedFixtures',
    'testCompetitionAndCombinedReasonsAreExact',
    'testPlayerOnlyFollowIsNotMatchable'
)) {
    if (-not $fixtureFollowTestSource.Contains($testName)) {
        throw "Shared fixture-follow coverage is missing $testName"
    }
}

$matchesDateSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Matches\MatchesDateRail.swift'
) -Encoding utf8
foreach ($dateMarker in @(
    'Array(-2...2)',
    'calendar.startOfDay(for:',
    'calendar.date(',
    'recenter:',
    'relativeDay(for date:'
)) {
    if (-not $matchesDateSource.Contains($dateMarker)) {
        throw "Matches date rail is missing calendar marker $dateMarker"
    }
}

$matchesSearchSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Matches\MatchesSearchPresentation.swift'
) -Encoding utf8
foreach ($searchMarker in @(
    'MatchesSearchState',
    'normalizedQuery.count >= 2',
    'fixture.homeTeam.nameArabic',
    'fixture.awayTeam.nameEnglish',
    'fixture.competition.nameArabic',
    'fixture.venueEnglish',
    'ArabicSearchNormalizer.normalize(value)'
)) {
    if (-not $matchesSearchSource.Contains($searchMarker)) {
        throw "Matches search model is missing contract marker $searchMarker"
    }
}

$matchesSearchViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Matches\MatchesSearchView.swift'
) -Encoding utf8
foreach ($searchViewMarker in @(
    'followReasonsByFixtureID: [String: FixtureFollowReason]',
    'followReasonsByFixtureID[fixture.id]',
    'matches.search.followReason.'
)) {
    if (-not $matchesSearchViewSource.Contains($searchViewMarker)) {
        throw "Matches search UI is missing followed-reason marker $searchViewMarker"
    }
}

$matchesTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\MatchesPresentationTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testAvailableCompetitionsAndGroupsFollowFirstPayloadAppearance',
    'testLiveFilterIncludesLiveAndHalfTimeAndKeepsCompetitionRailStable',
    'testCompetitionSelectionIsComposedWithStatusFilter',
    'testUnavailableCompetitionSelectionNormalizesToAllCompetitions',
    'testFirstCompetitionSnapshotLabelsGroupWithoutChangingFixtureIdentity',
    'testGroupsAreCompleteAndDisjoint',
    'testEmptyReasonsCoverDateStatusAndCompetitionContexts',
    'testExistingCompetitionWithNoMatchingStatusRemainsSelected',
    'testFollowingScopeExplainsTeamCompetitionAndBothReasons',
    'testFollowingScopeComposesWithLiveAndCompetitionWithoutChangingRail',
    'testPlayerOnlyFollowProducesNoMatchableFollowsEmptyState',
    'testFollowedInterestWithoutVisibleFixtureUsesContextualEmptyReasons',
    'testAllScopeIsBackwardCompatibleAndDoesNotClaimReasons'
)) {
    if (-not $matchesTestSource.Contains($testName)) {
        throw "Matches discovery coverage is missing $testName"
    }
}

foreach ($matchesFollowingJourneyMarker in @(
    'testMatchesFollowingScopeUsesExplicitTeamRelationshipAndComposesWithLive',
    'matches.scope.following',
    'matches.followReason.fixture-live-1',
    'matches.followReason.fixture-finished-1'
)) {
    if (-not $onboardingUITestSource.Contains($matchesFollowingJourneyMarker)) {
        throw "Matches Following UI journey is missing $matchesFollowingJourneyMarker"
    }
}


$matchesDateTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\MatchesDateRailTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testRailProducesFiveLocalCalendarDaysAcrossDST',
    'testRailSelectionKeepsCenterAndNormalizesTheSelectedDay',
    'testCalendarSelectionRecentersTheFiveDayRail',
    'testRelativeLabelsUseActualReferenceDayInsteadOfRailOffset'
)) {
    if (-not $matchesDateTestSource.Contains($testName)) {
        throw "Matches arbitrary-date coverage is missing $testName"
    }
}

$matchesSearchTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\MatchesSearchPresentationTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testEmptyAndSingleCharacterQueriesDoNotSearch',
    'testEnglishTeamSearchIsCaseInsensitiveAndKeepsOriginalID',
    'testArabicSearchIgnoresDiacriticsAndCommonAlefVariants',
    'testCompetitionAndMonogramFieldsAreSearchable',
    'testVenueAndAwayTeamFieldsAreSearchable',
    'testResultsPreserveCandidateOrderAndNeverDuplicateAFixture',
    'testStatusAndCompetitionFiltersAreAppliedBeforeTextSearch',
    'testUnmatchedQueryProducesExplicitEmptyState'
)) {
    if (-not $matchesSearchTestSource.Contains($testName)) {
        throw "Matches scoped-search coverage is missing $testName"
    }
}

foreach ($matchesJourneyMarker in @(
    'testMatchesCombineFiveDayCompetitionAndLiveFilters',
    'for offset in -2...2',
    'matches.day.\(offset)',
    'matches.group.demo-premier-league',
    'matches.group.demo-cup',
    'matches.competition.demo-cup',
    'matches.fixture.fixture-cup-upcoming-1',
    'matches.status.live',
    'matches.status.all',
    'matches.empty.liveInCompetition',
    'matches.empty.date'
)) {
    if (-not $onboardingUITestSource.Contains($matchesJourneyMarker)) {
        throw "Matches UI journey is missing $matchesJourneyMarker"
    }
}

foreach ($matchesDateSearchJourneyMarker in @(
    'testMatchesCalendarAndScopedSearchEntryPoints',
    'matches.toolbar.calendar',
    'matches.calendar.sheet',
    'matches.calendar.datePicker',
    'matches.calendar.today',
    'matches.calendar.apply',
    'matches.toolbar.search',
    'matches.search.sheet',
    'matches.search.field',
    'matches.search.result.fixture-live-1',
    'matches.search.clear',
    'matches.search.empty'
)) {
    if (-not $onboardingUITestSource.Contains($matchesDateSearchJourneyMarker)) {
        throw "Matches date/search UI journey is missing $matchesDateSearchJourneyMarker"
    }
}

$remoteProviderTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\RemoteSportsDataProviderTests.swift'
) -Encoding utf8
foreach ($testName in @(
    'testPlayerCatalogUsesBoundedPublicCacheableRequest',
    'testPlayerCatalogRejectsDuplicateIdentifiersBeforeCaching',
    'testCompetitionFixturesValidateScopeAndPaginateInStableOrder',
    'testCompetitionFixturesRejectMismatchedEchoBeforeCaching',
    'testCompetitionFixturesRejectCrossPageOrderingFailures',
    'testCompetitionFixturesRejectCrossPageDuplicateIDs',
    'testCompetitionFixturesLaterPageFailureFallsBackToCompleteDemoSchedule'
)) {
    if (-not $remoteProviderTestSource.Contains($testName)) {
        throw "Remote player-catalog coverage is missing $testName"
    }
}

$remoteProviderSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\RemoteSportsDataProvider.swift'
) -Encoding utf8
foreach ($videoEditorialRemoteMarker in @(
    'VideoDiscoveryResponseDTO.self',
    'pathComponents: ["videos", "discovery"]',
    'resource: .videoDiscovery'
)) {
    if (-not $remoteProviderSource.Contains($videoEditorialRemoteMarker)) {
        throw "Remote video discovery is missing contract marker $videoEditorialRemoteMarker"
    }
}
foreach ($videoEditorialRemoteTestName in @(
    'testVideoDiscoveryMapsEditorialContractAndRevalidatesWithETag',
    'testVideoDiscoveryRejectsDanglingEditorialReferenceBeforeCaching',
    'testVideoDiscoveryFailureFallsBackToOneCompleteDemoSnapshot'
)) {
    if (-not $remoteProviderTestSource.Contains($videoEditorialRemoteTestName)) {
        throw "Remote video discovery coverage is missing $videoEditorialRemoteTestName"
    }
}

foreach ($videoDetailRemoteMarker in @(
    'VideoDetailResponseDTO.self',
    'pathComponents: ["videos", id]',
    'domain(expectedVideoID: id)'
)) {
    if (-not $remoteProviderSource.Contains($videoDetailRemoteMarker)) {
        throw "Remote video detail is missing contract marker $videoDetailRemoteMarker"
    }
}
if (-not $remoteProviderTestSource.Contains(
    'testVideoDetailsRejectMismatchedPathIdentifierBeforeCaching'
)) {
    throw 'Remote video detail response identity coverage is missing.'
}

$videoDetailContractTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\VideoDetailEditorialContractTests.swift'
) -Encoding utf8
foreach ($videoDetailContractTestName in @(
    'testValidDetailMapsEditorialContextAndPreservesRelatedOrderAndRights',
    'testDetailResponseMustMatchRequestedPathIdentifier',
    'testRelatedVideosRejectDuplicateAndSelfReferences',
    'testRelatedVideosAreBounded',
    'testExpandableDescriptionUsesAnExplicitStableThreshold'
)) {
    if (-not $videoDetailContractTestSource.Contains($videoDetailContractTestName)) {
        throw "Video detail contract coverage is missing $videoDetailContractTestName"
    }
}

$videoDetailSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Video\VideoDetailView.swift'
) -Encoding utf8
foreach ($videoDetailSourceMarker in @(
    'ExpandableVideoDescription(',
    'video.editorialContext',
    'details.relatedVideos',
    'video.related.',
    'VideoDescriptionPresentation.lineLimit('
)) {
    if (-not $videoDetailSource.Contains($videoDetailSourceMarker)) {
        throw "Video detail UI is missing contract marker $videoDetailSourceMarker"
    }
}

$videoEditorialContractTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\VideoEditorialDiscoveryContractTests.swift'
) -Encoding utf8
foreach ($videoEditorialContractTestName in @(
    'testEmptyResponseIsValidOnlyWithoutEditorialReferences',
    'testDuplicateItemIdentifiersFailClosed',
    'testDanglingFeaturedIdentifierFailsClosed',
    'testDuplicateOrDanglingTrendingIdentifiersFailClosed',
    'testFeaturedAndTrendingSurfacesMustBeDisjoint',
    'testTrendingListIsBounded',
    'testItemListIsBounded'
)) {
    if (-not $videoEditorialContractTestSource.Contains($videoEditorialContractTestName)) {
        throw "Video editorial contract coverage is missing $videoEditorialContractTestName"
    }
}

$videoEditorialPresentationTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\VideoEditorialDiscoveryPresentationTests.swift'
) -Encoding utf8
foreach ($videoEditorialPresentationTestName in @(
    'testEmptyFeedHasOnlyAllTypeAndNoEditorialOrLibraryContent',
    'testEditorialHeroAndTrendingUseExplicitIdentifiersAndRankOrder',
    'testLibraryFiltersDoNotRewriteGlobalEditorialSurfaces',
    'testSportsUseCanonicalOrderAndOnlyIncludePresentValues',
    'testUnavailableSportAndTypeSelectionsNormalizeToAll',
    'testSportAndTypeIntersectionPreservesProviderOrderAndPlaybackRights'
)) {
    if (-not $videoEditorialPresentationTestSource.Contains($videoEditorialPresentationTestName)) {
        throw "Video editorial presentation coverage is missing $videoEditorialPresentationTestName"
    }
}

foreach ($competitionFixtureRemoteMarker in @(
    'PublicContentResource.competitionFixtures(',
    'CompetitionFixtureListResponseDTO.self',
    'validatedIDs.insert(fixture.id).inserted',
    'maximumCompetitionFixtureCount',
    'seenCursors.insert(nextValidatedCursor).inserted',
    'previous.id >= fixture.id',
    '.refreshFailed(at: now())'
)) {
    if (-not $remoteProviderSource.Contains($competitionFixtureRemoteMarker)) {
        throw "Remote competition fixtures are missing contract marker $competitionFixtureRemoteMarker"
    }
}

$teamDetailSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Teams\TeamDetailView.swift'
) -Encoding utf8
foreach ($teamContextMarker in @(
    'TeamContextPresentation(details:',
    'team.context.previous',
    'team.context.next',
    'team.content.news',
    'team.content.videos',
    'async let core: Void = loadCore()',
    'contentRequestID == requestID'
)) {
    if (-not $teamDetailSource.Contains($teamContextMarker)) {
        throw "Team detail is missing context marker $teamContextMarker"
    }
}

$teamContextContractTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\TeamContextContractTests.swift'
) -Encoding utf8
foreach ($teamContextTestName in @(
    'testTeamDetailRejectsAConflictingSnapshotForTheRequestedTeam',
    'testTeamDetailRejectsAnUnorderedNextWindow',
    'testTeamContentRejectsMisorderedArticlesAndDuplicateVideos'
)) {
    if (-not $teamContextContractTestSource.Contains($teamContextTestName)) {
        throw "Team context contract coverage is missing $teamContextTestName"
    }
}

foreach ($teamContextRemoteTestName in @(
    'testTeamContentMapsAuthoritativeScopeAndRevalidatesWithETag',
    'testTeamContentRejectsMismatchedEchoBeforeCaching',
    'testTeamDetailsRejectsLiveFixtureInNextWindowBeforeCaching'
)) {
    if (-not $remoteProviderTestSource.Contains($teamContextRemoteTestName)) {
        throw "Remote team context coverage is missing $teamContextRemoteTestName"
    }
}

$entityEditorialProductContract = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'ENTITY-EDITORIAL-CONTENT-CONTRACT.md'
) -Encoding utf8
foreach ($entityEditorialBoundary in @(
    'Association is Provider-authored',
    '15-minute stale-if-error window',
    'season-independent Latest section',
    'two-lane editorial desk',
    'presence grants no playback or subscription'
)) {
    if (-not $entityEditorialProductContract.Contains($entityEditorialBoundary)) {
        throw "Entity editorial product contract is missing $entityEditorialBoundary"
    }
}

$entityEditorialModels = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Shared\Models.swift'
) -Encoding utf8
foreach ($entityEditorialModelMarker in @('struct PlayerContent:', 'struct CompetitionContent:')) {
    if (-not $entityEditorialModels.Contains($entityEditorialModelMarker)) {
        throw "Entity editorial domain model is missing $entityEditorialModelMarker"
    }
}

$entityEditorialDTOs = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SportsDataDTOs.swift'
) -Encoding utf8
foreach ($entityEditorialDTOMarker in @(
    'struct PlayerContentDataDTO:',
    'struct CompetitionContentDataDTO:',
    'validatedEntityEditorialContent(',
    'data.articles.order',
    'data.videos.id'
)) {
    if (-not $entityEditorialDTOs.Contains($entityEditorialDTOMarker)) {
        throw "Entity editorial DTO validation is missing $entityEditorialDTOMarker"
    }
}

$entityEditorialView = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Shared\EntityEditorialContentSection.swift'
) -Encoding utf8
foreach ($entityEditorialViewMarker in @(
    'struct EntityEditorialContentSection:',
    'competition.content',
    'player.content',
    'newspaper.fill',
    'play.rectangle.fill',
    'AppTheme.warm'
)) {
    if (-not $entityEditorialView.Contains($entityEditorialViewMarker)) {
        throw "Entity editorial UI is missing $entityEditorialViewMarker"
    }
}

$competitionDetailSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Competitions\CompetitionDetailView.swift'
) -Encoding utf8
$playerDetailSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Players\PlayerDetailView.swift'
) -Encoding utf8
foreach ($competitionEditorialMarker in @(
    'case latest',
    'EntityEditorialContentSection(',
    '.competitionContent(id: competition.id)'
)) {
    if (-not $competitionDetailSource.Contains($competitionEditorialMarker)) {
        throw "Competition editorial UI is missing $competitionEditorialMarker"
    }
}
foreach ($playerEditorialMarker in @(
    'statisticsSection(details.statistics)',
    'editorialContentSection',
    'transfersSection',
    'loadPlayerContent()',
    '.playerContent(id: playerID)'
)) {
    if (-not $playerDetailSource.Contains($playerEditorialMarker)) {
        throw "Player editorial UI is missing $playerEditorialMarker"
    }
}

$entityEditorialContractTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\EntityEditorialContentContractTests.swift'
) -Encoding utf8
foreach ($entityEditorialTestName in @(
    'testPlayerAndCompetitionContentMapExactScopeAndPreserveVideoOrder',
    'testPlayerAndCompetitionContentRejectMismatchedScopeEchoes',
    'testEntityContentRejectsOversizedDuplicateAndMisorderedWindows',
    'testEntityContentUsesArticleIDAsStableTimestampTieBreaker'
)) {
    if (-not $entityEditorialContractTests.Contains($entityEditorialTestName)) {
        throw "Entity editorial contract coverage is missing $entityEditorialTestName"
    }
}
foreach ($entityEditorialRemoteTestName in @(
    'testPlayerAndCompetitionContentUseExactPathsAndPlayerETagRevalidation',
    'testCompetitionContentRejectsMismatchedEchoBeforeCaching'
)) {
    if (-not $remoteProviderTestSource.Contains($entityEditorialRemoteTestName)) {
        throw "Remote entity editorial coverage is missing $entityEditorialRemoteTestName"
    }
}
foreach ($entityEditorialJourneyMarker in @(
    'competition.section.latest',
    'competition.content.article.article-1',
    'competition.content.video.video-highlight-1',
    'player.content.article.article-2',
    'player.content.video.video-interview-1'
)) {
    if (-not $onboardingUITestSource.Contains($entityEditorialJourneyMarker)) {
        throw "Entity editorial UI journey is missing $entityEditorialJourneyMarker"
    }
}

$fixtureContentContractTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\FixtureContentContractTests.swift'
) -Encoding utf8
foreach ($fixtureContentTestName in @(
    'testValidFixtureContentPreservesProviderOrderAndPlaybackRights',
    'testFixtureContentResponseMustMatchRequestedPathIdentifier',
    'testFixtureContentRejectsDuplicateMomentAndVideoIdentifiers',
    'testFixtureContentRejectsDuplicateArticleIdentifiers',
    'testFixtureContentRejectsOutOfRangeMinuteAndOversizedWindows'
)) {
    if (-not $fixtureContentContractTestSource.Contains($fixtureContentTestName)) {
        throw "Fixture content contract coverage is missing $fixtureContentTestName"
    }
}

foreach ($fixtureContentRemoteMarker in @(
    'FixtureContentResponseDTO.self',
    'pathComponents: ["fixtures", id, "content"]',
    'resource: .fixtureContent(id: id)',
    'domain(expectedFixtureID: id)'
)) {
    if (-not $remoteProviderSource.Contains($fixtureContentRemoteMarker)) {
        throw "Remote fixture content is missing marker $fixtureContentRemoteMarker"
    }
}

foreach ($fixtureContentRemoteTestName in @(
    'testFixtureContentMapsAuthoritativeScopeAndRevalidatesWithETag',
    'testFixtureContentRejectsMismatchedEchoBeforeCaching'
)) {
    if (-not $remoteProviderTestSource.Contains($fixtureContentRemoteTestName)) {
        throw "Remote fixture content coverage is missing $fixtureContentRemoteTestName"
    }
}

$fixtureContentDTOs = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SportsDataDTOs.swift'
) -Encoding utf8
foreach ($fixtureContentDTOMarker in @(
    'struct FixtureContentResponseDTO',
    'fixtureID == expectedFixtureID',
    'Set(moments.map(\.video.id)).count == moments.count',
    'Set(articles.map(\.id)).count == articles.count',
    '!(0...200).contains(minute)'
)) {
    if (-not $fixtureContentDTOs.Contains($fixtureContentDTOMarker)) {
        throw "Fixture content DTO is missing marker $fixtureContentDTOMarker"
    }
}

$matchCenterSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\MatchCenter\MatchCenterView.swift'
) -Encoding utf8
foreach ($fixtureContentUIMarker in @(
    'matchCenter.content.moments',
    'matchCenter.moment.',
    'dynamicTypeSize.isAccessibilitySize',
    'FixtureContentMomentCard(moment:',
    'VideoDetailView(video: moment.video)',
    '.fixtureContent(id: fixtureID)'
)) {
    if (-not $matchCenterSource.Contains($fixtureContentUIMarker)) {
        throw "Match centre fixture content UI is missing marker $fixtureContentUIMarker"
    }
}

foreach ($fixtureContentJourneyMarker in @(
    'matchCenter.content.moments',
    'matchCenter.moment.moment-opening-goal',
    'video.availability'
)) {
    if (-not $onboardingUITestSource.Contains($fixtureContentJourneyMarker)) {
        throw "Fixture content UI journey is missing marker $fixtureContentJourneyMarker"
    }
}

foreach ($fixtureContentAPIMarker in @(
    '/fixtures/{fixtureId}/content:',
    'operationId: getFixtureContent',
    'FixtureContentMoment:',
    'FixtureContentResponse:'
)) {
    if (-not $apiContract.Contains($fixtureContentAPIMarker)) {
        throw "API contract is missing fixture content marker $fixtureContentAPIMarker"
    }
}

$followingDashboardSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Following\FollowingView.swift'
) -Encoding utf8
foreach ($followingDashboardMarker in @(
    'followedTeamsDashboardSection',
    'reloadTeamMatchSnapshots()',
    'teamMatchSnapshotRequestID == requestID',
    '.teamMatchSnapshots(ids:',
    'following.teamDashboard.error'
)) {
    if (-not $followingDashboardSource.Contains($followingDashboardMarker)) {
        throw "Following team dashboard is missing UI marker $followingDashboardMarker"
    }
}

$followingDashboardCardSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Following\FollowingTeamSnapshotCard.swift'
) -Encoding utf8
foreach ($followingDashboardCardMarker in @(
    'dynamicTypeSize.isAccessibilitySize',
    'MatchCenterView(fixtureID:',
    'TeamDetailView(team:',
    'following.teamDashboard.unfollow.',
    'frame(maxWidth: .infinity, minHeight: 44)'
)) {
    if (-not $followingDashboardCardSource.Contains($followingDashboardCardMarker)) {
        throw "Following team dashboard card is missing marker $followingDashboardCardMarker"
    }
}

foreach ($followingDashboardRemoteMarker in @(
    'TeamMatchSnapshotRequestLimits.maximumTeamsPerHTTPBatch',
    'TeamMatchSnapshotRequestLimits.maximumTeamsPerDashboard',
    'TeamMatchSnapshotListResponseDTO.self',
    'URLQueryItem(name: "teamId", value:',
    'requestTeamSnapshotIDs('
)) {
    if (-not $remoteProviderSource.Contains($followingDashboardRemoteMarker)) {
        throw "Remote team dashboard is missing contract marker $followingDashboardRemoteMarker"
    }
}

$teamContextDTOs = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SportsDataDTOs.swift'
) -Encoding utf8
foreach ($followingDashboardDTOMarker in @(
    'struct TeamMatchSnapshotListResponseDTO',
    'data.count == expectedTeamIDs.count',
    'team.id == expectedTeamID',
    'expectedState: .finished',
    'expectedState: .upcoming',
    'embeddedTeam == expectedTeam'
)) {
    if (-not $teamContextDTOs.Contains($followingDashboardDTOMarker)) {
        throw "Following team dashboard DTO is missing marker $followingDashboardDTOMarker"
    }
}

foreach ($followingDashboardTestName in @(
    'testTeamMatchSnapshotBatchPreservesRequestedOrderAndNullableSlots',
    'testTeamMatchSnapshotBatchRejectsMissingOrReorderedRows',
    'testTeamMatchSnapshotRejectsWrongStateAndConflictingTeamSnapshot'
)) {
    if (-not $teamContextContractTestSource.Contains($followingDashboardTestName)) {
        throw "Following team dashboard contract coverage is missing $followingDashboardTestName"
    }
}

foreach ($followingDashboardRemoteTestName in @(
    'testTeamMatchSnapshotsPreserveQueryOrderAndRevalidateWithETag',
    'testTeamMatchSnapshotsChunkRequestsAtTwentyWithoutReordering',
    'testTeamMatchSnapshotsRejectDuplicateIDsBeforeNetworking',
    'testTeamMatchSnapshotsRejectReorderedRowsBeforeCaching'
)) {
    if (-not $remoteProviderTestSource.Contains($followingDashboardRemoteTestName)) {
        throw "Following team dashboard remote coverage is missing $followingDashboardRemoteTestName"
    }
}

foreach ($followingDashboardJourneyMarker in @(
    'testFollowingTeamDashboardShowsPreviousAndNextAndOpensMatchCenter',
    'following.teamDashboard.riyadh-falcons.previous.fixture-finished-1',
    'following.teamDashboard.riyadh-falcons.next.fixture-team-next-1'
)) {
    if (-not $onboardingUITestSource.Contains($followingDashboardJourneyMarker)) {
        throw "Following team dashboard UI journey is missing $followingDashboardJourneyMarker"
    }
}

foreach ($followingDashboardAPIMarker in @(
    '/teams/match-snapshots:',
    'operationId: listTeamMatchSnapshots',
    'TeamMatchSnapshotListResponse:',
    'TeamMatchSnapshot:'
)) {
    if (-not $apiContract.Contains($followingDashboardAPIMarker)) {
        throw "API contract is missing following team dashboard marker $followingDashboardAPIMarker"
    }
}

foreach ($followContractMarker in @('FollowEntity:', 'FollowTeamEntity:', 'FollowPlayerEntity:', 'FollowCompetitionEntity:')) {
    if (-not $apiContract.Contains($followContractMarker)) {
        throw "API contract is missing multi-entity follow marker $followContractMarker"
    }
}

$followingSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Following\FollowingView.swift'
) -Encoding utf8
foreach ($followingMarker in @('appModel.orderedFollows', 'following.entity.', 'destination(for entity:', 'unavailableInterestLabel')) {
    if (-not $followingSource.Contains($followingMarker)) {
        throw "Following UI is missing multi-entity marker $followingMarker"
    }
}
foreach ($detailRelativePath in @(
    'SportsHub\Features\Teams\TeamDetailView.swift',
    'SportsHub\Features\Players\PlayerDetailView.swift',
    'SportsHub\Features\Competitions\CompetitionDetailView.swift'
)) {
    $detailSource = Get-Content -Raw -LiteralPath (Join-Path $projectRoot $detailRelativePath) -Encoding utf8
    if (-not $detailSource.Contains('SportsFollowButton(')) {
        throw "$detailRelativePath is missing its visible follow control"
    }
}

$contextualAlertSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\DesignSystem\ContextualAlertSettingsButton.swift'
) -Encoding utf8
foreach ($contextualAlertMarker in @(
    'enum ContextualAlertTarget',
    'target.presentation(follows: appModel.orderedFollows)',
    'NotificationSettingsCard()',
    'contextualAlerts.globalBody',
    '.team(fixture.homeTeam)',
    '.team(fixture.awayTeam)',
    '.competition(fixture.competition)',
    'appModel.isFollowMutationInProgress(',
    'presentation.eligibility.isEligible && !isSettlingFollow',
    'guard isEligibleForSettings else { return }',
    'contextualAlerts.updatingAudience',
    'contextualAlerts.followError',
    'contextualAlerts.sheet'
)) {
    if (-not $contextualAlertSource.Contains($contextualAlertMarker)) {
        throw "Contextual alert UI is missing contract marker $contextualAlertMarker"
    }
}
if ($contextualAlertSource.Contains('requestAuthorization(')) {
    throw 'Opening or following from a contextual alert entry must not request notification permission.'
}

$contextualPresentationSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Shared\ContextualAlertPresentation.swift'
) -Encoding utf8
foreach ($contextualPresentationMarker in @(
    '$0.type == entityType && $0.entityID == entityID',
    'FixtureFollowMatcher(follows: follows).reason(for: fixture)',
    'contextualAlerts.eligible.fixture.\(reason.rawValue)'
)) {
    if (-not $contextualPresentationSource.Contains($contextualPresentationMarker)) {
        throw "Contextual alert model is missing marker $contextualPresentationMarker"
    }
}

$contextualEntryMarkers = @{
    'SportsHub\Features\Teams\TeamDetailView.swift' = 'accessibilityIdentifier: "team.alerts"'
    'SportsHub\Features\Players\PlayerDetailView.swift' = 'accessibilityIdentifier: "player.alerts"'
    'SportsHub\Features\Competitions\CompetitionDetailView.swift' = 'accessibilityIdentifier: "competition.alerts"'
    'SportsHub\Features\MatchCenter\MatchCenterView.swift' = 'accessibilityIdentifier: "match.alerts"'
}
foreach ($entry in $contextualEntryMarkers.GetEnumerator()) {
    $entrySource = Get-Content -Raw -LiteralPath (Join-Path $projectRoot $entry.Key) -Encoding utf8
    if (-not $entrySource.Contains($entry.Value)) {
        throw "$($entry.Key) is missing contextual alert entry $($entry.Value)"
    }
}

$contextualAlertTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\ContextualAlertPresentationTests.swift'
) -Encoding utf8
foreach ($contextualAlertTest in @(
    'testEntityEligibilityRequiresExactCompoundIdentity',
    'testEveryFollowEntityTypeCanBecomeEligible',
    'testFixtureEligibilityExplainsTeamCompetitionAndCombinedReasons',
    'testPlayerOnlyFollowNeverMakesFixtureEligible',
    'testNoFollowsLeavesEntityAndFixtureIneligible'
)) {
    if (-not $contextualAlertTestSource.Contains($contextualAlertTest)) {
        throw "Contextual alert coverage is missing $contextualAlertTest"
    }
}

foreach ($contextualAlertJourneyMarker in @(
    'testContextualAlertsExplainFollowAudienceWithoutPromisingGuestDelivery',
    'team.alerts',
    'match.alerts',
    'contextualAlerts.eligible',
    'contextualAlerts.scope',
    'notifications.accountRequired',
    'XCTAssertFalse(app.buttons["notifications.enable"].exists)'
)) {
    if (-not $onboardingUITestSource.Contains($contextualAlertJourneyMarker)) {
        throw "Contextual alert UI journey is missing $contextualAlertJourneyMarker"
    }
}

$notificationPreferenceModelSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Shared\Models.swift'
) -Encoding utf8
foreach ($notificationPreferenceModelMarker in @(
    'case breakingNews',
    'case lineup',
    'case kickoff',
    'case goal',
    'case yellowCard',
    'case redCard',
    'case substitution',
    'case halfTime',
    'case fullTime'
)) {
    if (-not $notificationPreferenceModelSource.Contains($notificationPreferenceModelMarker)) {
        throw "Notification-preference model is missing $notificationPreferenceModelMarker"
    }
}
$notificationPreferenceEnumBlock = [regex]::Match(
    $notificationPreferenceModelSource,
    'enum NotificationPreferenceType[\s\S]*?\n}'
).Value
if ($notificationPreferenceEnumBlock.Contains('case card')) {
    throw 'NotificationPreferenceType must not expose the deprecated aggregate card category.'
}

$notificationPreferenceDTOSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SportsDataDTOs.swift'
) -Encoding utf8
foreach ($notificationPreferenceDTOMarker in @(
    'let card: Bool?',
    'let yellowCard: Bool?',
    'let redCard: Bool?',
    'let substitution: Bool?',
    'yellowCard: yellowCard ?? legacyCardPreference',
    'redCard: redCard ?? legacyCardPreference',
    'substitution: substitution ?? false',
    'substitution = type == .substitution ? enabled : nil'
)) {
    if (-not $notificationPreferenceDTOSource.Contains($notificationPreferenceDTOMarker)) {
        throw "Notification-preference DTO is missing migration marker $notificationPreferenceDTOMarker"
    }
}

$notificationPreferenceContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'MATCH-NOTIFICATION-PREFERENCES-CONTRACT.md'
) -Encoding utf8
foreach ($notificationPreferenceBoundary in @(
    'exactly the nine choices',
    '`substitution` is always `false`',
    'deprecated aggregate.',
    'does not claim a notification was delivered',
    'Xcode/real-device gates.'
)) {
    if (-not $notificationPreferenceContractSource.Contains($notificationPreferenceBoundary)) {
        throw "Notification-preference product contract is missing $notificationPreferenceBoundary"
    }
}

$notificationPreferenceTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\NotificationPreferencesContractTests.swift'
) -Encoding utf8
foreach ($notificationPreferenceTestMarker in @(
    'testLegacyCardPreferenceMigratesWithoutOptingIntoSubstitutions',
    'testGranularCardPreferencesOverrideLegacyAggregate',
    'testEveryPreferenceMutationChangesOnlyItsOwnCategory',
    'testGranularPatchEncodesExactlyOneField'
)) {
    if (-not $notificationPreferenceTestSource.Contains($notificationPreferenceTestMarker)) {
        throw "Notification-preference coverage is missing $notificationPreferenceTestMarker"
    }
}

$notificationRemoteTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\RemoteSportsDataProviderTests.swift'
) -Encoding utf8
foreach ($notificationRemoteTestMarker in @(
    'setNotificationPreference(.substitution, enabled: false)',
    'XCTAssertTrue(initial.yellowCard)',
    'XCTAssertTrue(initial.redCard)',
    'XCTAssertFalse(updated.substitution)',
    'XCTAssertEqual(patchJSON["substitution"] as? Bool, false)'
)) {
    if (-not $notificationRemoteTestSource.Contains($notificationRemoteTestMarker)) {
        throw "Remote notification-preference coverage is missing $notificationRemoteTestMarker"
    }
}

$notificationSettingsCardSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Following\NotificationSettingsCard.swift'
) -Encoding utf8
foreach ($notificationSettingsCardMarker in @(
    'ForEach(NotificationPreferenceType.allCases)',
    '.frame(minHeight: 44)',
    'notifications.preference.\(type.rawValue)'
)) {
    if (-not $notificationSettingsCardSource.Contains($notificationSettingsCardMarker)) {
        throw "Notification settings UI is missing $notificationSettingsCardMarker"
    }
}

$predictionContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'PREDICTION-GAMES-CONTRACT.md'
) -Encoding utf8
foreach ($predictionBoundary in @(
    'free, non-wager sports challenge',
    'odds, stakes, entry fees',
    '`no-store`',
    'server-authoritative',
    '44'
)) {
    if (-not $predictionContractSource.Contains($predictionBoundary)) {
        throw "Prediction-game product contract is missing $predictionBoundary"
    }
}

$predictionViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Predictions\PredictionGameView.swift'
) -Encoding utf8
foreach ($predictionViewMarker in @(
    'predictions.nonWagerLong',
    'direction: .up',
    'direction: .down',
    'direction == .up ? "up" : "down"',
    'game.isEditable(at: currentDate)',
    'entryState == .ready',
    'authentication.status.user?.id == user.id',
    'forAccountID: user.id',
    'predictions.account.unavailable'
)) {
    if (-not $predictionViewSource.Contains($predictionViewMarker)) {
        throw "Prediction-game UI is missing contract marker $predictionViewMarker"
    }
}

$predictionProviderProtocolSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SportsDataProviding.swift'
) -Encoding utf8
if (-not $predictionProviderProtocolSource.Contains('protocol IdentityScopedPredictionProviding')) {
    throw 'Prediction-game private provider is missing identity-scoped operations'
}

$predictionSessionProviderSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SessionPersonalizationSportsDataProvider.swift'
) -Encoding utf8
foreach ($identityBoundaryMarker in @(
    'IdentityScopedPredictionProviding',
    'identityBoundProvider(forAccountID: accountID)',
    'scoped.savePredictionEntry',
    'forAccountID: accountID'
)) {
    if (-not $predictionSessionProviderSource.Contains($identityBoundaryMarker)) {
        throw "Prediction-game account isolation is missing $identityBoundaryMarker"
    }
}

$predictionContractTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\PredictionGamesContractTests.swift'
) -Encoding utf8
foreach ($predictionTestMarker in @(
    'testDraftStartsInProviderOrderAndMovesOnePositionAtATime',
    'testEntryContractRequiresProviderGroupOrderAndAnExactTeamPermutation',
    'testMockProviderPersistsOnlyEditableCompleteEntries',
    'testFallbackProviderNeverSubstitutesDemoDataForAPrivateEntry',
    'testMockIdentityScopedEntriesDoNotLeakAcrossAccounts',
    'testIdentityScopedFallbackNeverSubstitutesDemoPrivateData'
)) {
    if (-not $predictionContractTests.Contains($predictionTestMarker)) {
        throw "Prediction-game contract coverage is missing $predictionTestMarker"
    }
}

$predictionRemoteTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\PredictionRemoteProviderTests.swift'
) -Encoding utf8
foreach ($predictionRemoteTestMarker in @(
    'testPublicGamesMapAndRevalidateWithETag',
    'testAuthenticatedEntryReadAndSaveAreNoStoreAndUseExactRankings',
    'testMissingTokenRejectsPrivateReadBeforeNetworking',
    'testExpectedAccountMismatchRejectsSaveBeforeNetworking',
    'testSaveRejectsAResponseThatDoesNotEchoSubmittedOrder'
)) {
    if (-not $predictionRemoteTests.Contains($predictionRemoteTestMarker)) {
        throw "Prediction-game remote coverage is missing $predictionRemoteTestMarker"
    }
}

foreach ($predictionJourneyMarker in @(
    'testGuestCanArrangeAFreePredictionWithoutBeingOfferedAccountStorage',
    'predictions.game.demo-global-cup-groups',
    'predictions.move.up.demo-group-a.jeddah-waves',
    'predictions.account.unavailable',
    'XCTAssertFalse(app.buttons["predictions.save"].exists)'
)) {
    if (-not $onboardingUITestSource.Contains($predictionJourneyMarker)) {
        throw "Prediction-game UI journey is missing $predictionJourneyMarker"
    }
}

$broadcastProductContract = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'BROADCAST-GUIDE-CONTRACT.md'
) -Encoding utf8
foreach ($broadcastBoundary in @(
    'read-only',
    'stream URL',
    'audioLanguageCode',
    '12 listings',
    'case- and diacritic-insensitive canonicalisation'
)) {
    if (-not $broadcastProductContract.Contains($broadcastBoundary)) {
        throw "Broadcast-guide product contract is missing $broadcastBoundary"
    }
}

$sharedModelsSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Shared\Models.swift'
) -Encoding utf8
foreach ($broadcastModelMarker in @(
    'struct FixtureBroadcast:',
    'let broadcasts: [FixtureBroadcast]',
    'decodeIfPresent(',
    'forKey: .broadcasts'
)) {
    if (-not $sharedModelsSource.Contains($broadcastModelMarker)) {
        throw "Broadcast-guide domain model is missing $broadcastModelMarker"
    }
}

$sportsDataDTOSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SportsDataDTOs.swift'
) -Encoding utf8
foreach ($broadcastDTOMarker in @(
    'struct FixtureBroadcastDTO:',
    'validatedFixtureBroadcasts(',
    'broadcasts.count <= 12',
    'validatedBroadcastLanguageCode(',
    '.controlCharacters',
    'en_US_POSIX'
)) {
    if (-not $sportsDataDTOSource.Contains($broadcastDTOMarker)) {
        throw "Broadcast-guide DTO validation is missing $broadcastDTOMarker"
    }
}

$fixtureCardSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Matches\FixtureCard.swift'
) -Encoding utf8
foreach ($fixtureBroadcastMarker in @(
    'fixture.broadcasts.',
    'match.broadcast.moreOptions',
    'dynamicTypeSize.isAccessibilitySize'
)) {
    if (-not $fixtureCardSource.Contains($fixtureBroadcastMarker)) {
        throw "Fixture broadcast summary is missing $fixtureBroadcastMarker"
    }
}

$matchCenterSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\MatchCenter\MatchCenterView.swift'
) -Encoding utf8
foreach ($matchBroadcastMarker in @(
    'matchCenter.broadcasts',
    'matchCenter.broadcast.',
    'match.broadcast.rightsNotice',
    'audioLanguageName(in:',
    'dynamicTypeSize.isAccessibilitySize'
)) {
    if (-not $matchCenterSource.Contains($matchBroadcastMarker)) {
        throw "Match-centre broadcast guide is missing $matchBroadcastMarker"
    }
}

$broadcastMockSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\MockSportsDataProvider.swift'
) -Encoding utf8
foreach ($broadcastMockMarker in @('demoBroadcasts', 'Demo Stadium Channel')) {
    if (-not $broadcastMockSource.Contains($broadcastMockMarker)) {
        throw "Broadcast mock data is missing $broadcastMockMarker"
    }
}

$broadcastContractTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\FixtureBroadcastContractTests.swift'
) -Encoding utf8
foreach ($broadcastTestMarker in @(
    'testWireListingsPreserveProviderOrderAndLocalizedMetadata',
    'testMissingWireArrayAndLegacyDomainSnapshotDecodeAsEmpty',
    'testWireContractRejectsInvalidRegionAndLanguageTags',
    'testWireContractRejectsBroadcastTextBoundsAndControlCharacters',
    'testWireContractRejectsDuplicatesOverflowAndCancelledListings'
)) {
    if (-not $broadcastContractTests.Contains($broadcastTestMarker)) {
        throw "Broadcast-guide contract coverage is missing $broadcastTestMarker"
    }
}

$remoteSportsDataTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\RemoteSportsDataProviderTests.swift'
) -Encoding utf8
foreach ($broadcastRemoteTestMarker in @(
    'testFixturesRejectInvalidBroadcastMetadataBeforeCaching',
    'fixtures[0].broadcasts.map',
    'XCTAssertEqual(storeCount, 0)'
)) {
    if (-not $remoteSportsDataTests.Contains($broadcastRemoteTestMarker)) {
        throw "Broadcast-guide remote coverage is missing $broadcastRemoteTestMarker"
    }
}

foreach ($broadcastJourneyMarker in @(
    'matchCenter.broadcasts',
    'matchCenter.broadcast.SA.0'
)) {
    if (-not $onboardingUITestSource.Contains($broadcastJourneyMarker)) {
        throw "Broadcast-guide UI journey is missing $broadcastJourneyMarker"
    }
}

$communityContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'ARTICLE-COMMUNITY-CONTRACT.md'
) -Encoding utf8
foreach ($communityContractMarker in @(
    'Apple App Review Guideline 1.2',
    'Cache-Control: no-store',
    'never cross the',
    'deployed moderation queue'
)) {
    if (-not $communityContractSource.Contains($communityContractMarker)) {
        throw "Article community contract is missing $communityContractMarker"
    }
}
$communityProviderSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SessionPersonalizationSportsDataProvider.swift'
) -Encoding utf8
foreach ($communityProviderMarker in @(
    'communityMutationsEnabled',
    'IdentityScopedCommunityProviding',
    'communityProviderForActiveAccount'
)) {
    if (-not $communityProviderSource.Contains($communityProviderMarker)) {
        throw "Community routing is missing $communityProviderMarker"
    }
}
$communityTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\ArticleCommunityTests.swift'
) -Encoding utf8
foreach ($communityTestMarker in @(
    'testCommentPageAcceptsOnlyPublishedUniqueComments',
    'testCommunityNeverCrossesRemoteToMockFallbackBoundary',
    'testSessionCommunityMutationFailsClosedWhenTokenIdentityDoesNotMatch',
    'testCommunityMutationGateFailsClosedAtTheDataRouter'
)) {
    if (-not $communityTestSource.Contains($communityTestMarker)) {
        throw "Community test coverage is missing $communityTestMarker"
    }
}
foreach ($communityJourneyMarker in @(
    'testArticleShowsModeratedCommunityWithDevelopmentReleaseGateLocked',
    'community.releaseGate.locked',
    'community.composer.locked'
)) {
    if (-not $onboardingUITestSource.Contains($communityJourneyMarker)) {
        throw "Community UI journey is missing $communityJourneyMarker"
    }
}

foreach ($plistRelativePath in @('SportsHub\Resources\Info.plist', 'SportsHubWidgets\Info.plist')) {
    $plistPath = Join-Path $projectRoot $plistRelativePath
    try {
        [xml](Get-Content -Raw -LiteralPath $plistPath -Encoding utf8) | Out-Null
    } catch {
        throw "Invalid plist XML: $plistRelativePath"
    }
}

foreach ($entitlementRelativePath in @(
    'SportsHub\Resources\SportsHub.entitlements',
    'SportsHubWidgets\SportsHubWidgets.entitlements'
)) {
    try {
        [xml](Get-Content -Raw -LiteralPath (Join-Path $projectRoot $entitlementRelativePath) -Encoding utf8) | Out-Null
    } catch {
        throw "Invalid plist XML: $entitlementRelativePath"
    }
}
$entitlements = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'SportsHub\Resources\SportsHub.entitlements') -Encoding utf8
if (-not $entitlements.Contains('<key>com.apple.developer.applesignin</key>')) {
    throw 'SportsHub entitlements do not declare Sign in with Apple.'
}
if (-not $entitlements.Contains('<key>aps-environment</key>')) {
    throw 'SportsHub entitlements do not declare the APNs environment.'
}
if (-not $entitlements.Contains('<key>com.apple.security.application-groups</key>')) {
    throw 'SportsHub entitlements do not declare the shared App Group.'
}
$widgetEntitlements = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubWidgets\SportsHubWidgets.entitlements'
) -Encoding utf8
if (-not $widgetEntitlements.Contains('<key>com.apple.security.application-groups</key>')) {
    throw 'Widget entitlements do not declare the shared App Group.'
}
if ($entitlements.Contains('applinks:')) {
    throw 'Associated Domains must not be claimed before a controlled public share domain is configured.'
}

$appPlist = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'SportsHub\Resources\Info.plist') -Encoding utf8
foreach ($plistKey in @('SportsAPIBaseURL', 'SportsAuthEnabled', 'SportsCommunityEnabled', 'SportsCommunityStandardsURL', 'SportsCommunitySupportURL', 'SportsDataMode', 'SportsPublicWebBaseURL', 'SportsMediaAllowedHosts', 'SportsPremiumMonthlyProductID', 'SportsPremiumAnnualProductID', 'SportsPremiumPrivacyURL', 'SportsPremiumTermsURL', 'SportsAdvertisingEnabled', 'SportsAppGroupIdentifier', 'NSSupportsLiveActivities', 'CFBundleURLTypes')) {
    if (-not $appPlist.Contains("<key>$plistKey</key>")) {
        throw "App Info.plist is missing $plistKey"
    }
}
if (-not $appPlist.Contains('<string>sportshub</string>')) {
    throw 'App Info.plist does not register the local deep-link scheme.'
}
$widgetPlist = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'SportsHubWidgets\Info.plist') -Encoding utf8
if (-not $widgetPlist.Contains('<key>SportsAppGroupIdentifier</key>')) {
    throw 'Widget Info.plist is missing SportsAppGroupIdentifier.'
}

$widgetSnapshotSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Shared\WidgetMatchSnapshot.swift'
) -Encoding utf8
$widgetCoordinatorSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\SystemExperience\WidgetMatchSnapshotCoordinator.swift'
) -Encoding utf8
$activityCoordinatorSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\SystemExperience\MatchLiveActivityCoordinator.swift'
) -Encoding utf8
$nextMatchWidgetSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubWidgets\NextMatchWidget.swift'
) -Encoding utf8
$activityWidgetSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubWidgets\MatchLiveActivityWidget.swift'
) -Encoding utf8
$matchCenterSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\MatchCenter\MatchCenterView.swift'
) -Encoding utf8
foreach ($marker in @(
    'schemaVersion',
    'maximumEncodedSize',
    'func isStale(at ',
    'deepLinkURL',
    'WidgetMatchSnapshotStore'
)) {
    if (-not $widgetSnapshotSource.Contains($marker)) {
        throw "Widget snapshot contract is missing $marker"
    }
}
foreach ($marker in @(
    'FixtureFollowMatcher',
    'reloadTimelines(ofKind:',
    'case .finished, .postponed, .cancelled: nil'
)) {
    if (-not $widgetCoordinatorSource.Contains($marker)) {
        throw "Widget coordinator is missing $marker"
    }
}
foreach ($marker in @(
    'pushType: nil',
    'areActivitiesEnabled',
    'activity.update(content)',
    'activity.end(content, dismissalPolicy:',
    'maximumActivityRuntime',
    'maximumUpcomingLeadInterval',
    'maximumKickoffGraceInterval'
)) {
    if (-not $activityCoordinatorSource.Contains($marker)) {
        throw "Live Activity lifecycle is missing $marker"
    }
}
foreach ($marker in @(
    'context.isStale',
    'activity.stale',
    'accessibilityLabel(context)'
)) {
    if (-not $activityWidgetSource.Contains($marker)) {
        throw "Live Activity presentation is missing $marker"
    }
}
foreach ($marker in @(
    'widgetURL(snapshot.deepLinkURL)',
    'widget.refreshRequired',
    'entry.loadFailed',
    'accessibilityLabel(for:'
)) {
    if (-not $nextMatchWidgetSource.Contains($marker)) {
        throw "Next-match Widget is missing $marker"
    }
}
foreach ($marker in @(
    'match.activity.toggle',
    'match.activity.localUpdatesOnly',
    'synchronizeLiveActivityIfNeeded'
)) {
    if (-not $matchCenterSource.Contains($marker)) {
        throw "Match-center Live Activity control is missing $marker"
    }
}
if ($nextMatchWidgetSource -match '(Riyadh Falcons|Jeddah Waves|sampleEntry)') {
    throw 'Next-match Widget still contains a fictional fixed match.'
}

$widgetContractTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\WidgetMatchSnapshotTests.swift'
) -Encoding utf8
$activityContractTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\MatchLiveActivityContractTests.swift'
) -Encoding utf8
foreach ($testMarker in @(
    'testSelectorUsesOnlyFollowsAndRanksLiveBeforeUpcoming',
    'testStoreRoundTripsAndRejectsUnknownSchema',
    'testCoordinatorReloadsAfterWriteAndClear',
    'testLanguageUpdatePreservesOriginalSnapshotAge'
)) {
    if (-not $widgetContractTests.Contains($testMarker)) {
        throw "Widget contract coverage is missing $testMarker"
    }
}
foreach ($journeyMarker in @(
    'match.activity.control',
    'match.activity.toggle'
)) {
    if (-not $onboardingUITestSource.Contains($journeyMarker)) {
        throw "Live Activity UI journey is missing $journeyMarker"
    }
}
foreach ($testMarker in @(
    'testEligibilityUsesFourHourLeadWindowAndRejectsTerminalStates',
    'testCoordinatorRequestsOnceThenSkipsUnchangedContent',
    'testCoordinatorUpdatesThenEndsWithFinalFinishedContent',
    'testExplicitStopFallsBackToLastValidContent',
    'testUpcomingPayloadBecomesStaleWithoutForegroundVerification',
    'testCoordinatorEndsWhenUpcomingFixtureMovesOutsideWindow',
    'testMalformedTerminalPayloadEndsImmediatelyWithoutFinalContent'
)) {
    if (-not $activityContractTests.Contains($testMarker)) {
        throw "Live Activity contract coverage is missing $testMarker"
    }
}

$transferContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'TRANSFER-CENTER-CONTRACT.md'
) -Encoding utf8
foreach ($marker in @(
    'GET /v1/transfers',
    'RUMORED',
    'Provider order is newest first',
    'fictional demo content',
    '44 by 44 point target'
)) {
    if (-not $transferContractSource.Contains($marker)) {
        throw "Transfer-center product contract is missing $marker"
    }
}
foreach ($marker in @(
    '/transfers:',
    'operationId: listTransferUpdates',
    'enum: [RUMORED, AGREED, COMPLETED]',
    "`$ref: '#/components/schemas/TransferListResponse'"
)) {
    if (-not $apiContract.Contains($marker)) {
        throw "Transfer-center API contract is missing $marker"
    }
}
$transferProviderSources = @(
    'SportsHub\Core\Data\MockSportsDataProvider.swift',
    'SportsHub\Core\Data\RemoteSportsDataProvider.swift',
    'SportsHub\Core\Data\FallbackSportsDataProvider.swift',
    'SportsHub\Core\Data\LocalPersonalizationSportsDataProvider.swift',
    'SportsHub\Core\Data\SessionPersonalizationSportsDataProvider.swift'
)
foreach ($relativePath in $transferProviderSources) {
    $providerSource = Get-Content -Raw -LiteralPath (Join-Path $projectRoot $relativePath) -Encoding utf8
    if (-not $providerSource.Contains('func transferUpdates(')) {
        throw "Transfer-center provider forwarding is missing in $relativePath"
    }
}
$transferPresentationSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Transfers\TransferCenterPresentation.swift'
) -Encoding utf8
foreach ($marker in @(
    'enum TransferCenterFilter:',
    'struct TransferCenterFeedState:',
    'expectedStatus:',
    'page.nextCursor',
    'data.order'
)) {
    if (-not $transferPresentationSource.Contains($marker)) {
        throw "Transfer-center pagination validation is missing $marker"
    }
}
$transferViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Transfers\TransferCenterView.swift'
) -Encoding utf8
foreach ($marker in @(
    'transfer.center.boundary',
    'transfer.filter.',
    'transfer.card.',
    'dynamicTypeSize.isAccessibilitySize',
    'PublicContentStatusView'
)) {
    if (-not $transferViewSource.Contains($marker)) {
        throw "Transfer-center presentation is missing $marker"
    }
}
$transferContractTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\TransferCenterContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'testFirstPageAndOlderPageAppendInProviderOrder',
    'testPageRejectsDuplicateIDsAndStatusMismatch',
    'testPageRejectsMissingOrIdenticalTeamRoute',
    'testAppendRejectsDuplicateTransferAndCursorLoop'
)) {
    if (-not $transferContractTests.Contains($marker)) {
        throw "Transfer-center contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testTransferCenterSendsStatusPaginationAndRecordsFreshness',
    'testTransferCenterRejectsMismatchedStatusBeforeCaching',
    'testTransferCenterRejectsUnorderedPageBeforeCaching'
)) {
    if (-not $remoteSportsDataTests.Contains($marker)) {
        throw "Transfer-center remote coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testUserCanFilterTransferCenterAndOpenPlayer',
    'explore.transferCenter',
    'transfer.filter.rumored',
    'transfer.card.transfer-player-salem'
)) {
    if (-not $onboardingUITestSource.Contains($marker)) {
        throw "Transfer-center UI journey is missing $marker"
    }
}

$seasonCalendarContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SEASON-CALENDAR-CONTRACT.md'
) -Encoding utf8
foreach ($marker in @(
    'GET /v1/season-calendar',
    'one atomic provider window',
    'at most 200 events',
    '24-hour stale-if-error window',
    'minimum 44-point target'
)) {
    if (-not $seasonCalendarContractSource.Contains($marker)) {
        throw "Season-calendar product contract is missing $marker"
    }
}
foreach ($marker in @(
    '/season-calendar:',
    'operationId: getSeasonCalendar',
    'SeasonCalendarResponse',
    'COMPETITION_MILESTONE',
    'INTERNATIONAL_BREAK'
)) {
    if (-not $apiContract.Contains($marker)) {
        throw "Season-calendar API contract is missing $marker"
    }
}
foreach ($relativePath in $transferProviderSources) {
    $providerSource = Get-Content -Raw -LiteralPath (Join-Path $projectRoot $relativePath) -Encoding utf8
    if (-not $providerSource.Contains('func seasonCalendar()')) {
        throw "Season-calendar provider forwarding is missing in $relativePath"
    }
}
$seasonCalendarPresentationSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Calendar\SeasonCalendarPresentation.swift'
) -Encoding utf8
foreach ($marker in @(
    'enum SeasonCalendarScope:',
    'struct SeasonCalendarPresentation',
    'availableKinds',
    'monthGroups',
    'calendar.events.order'
)) {
    if (-not $seasonCalendarPresentationSource.Contains($marker)) {
        throw "Season-calendar presentation validation is missing $marker"
    }
}
$seasonCalendarViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Calendar\SeasonCalendarView.swift'
) -Encoding utf8
foreach ($marker in @(
    'seasonCalendar.boundary',
    'seasonCalendar.scope.',
    'seasonCalendar.kind.',
    'dynamicTypeSize.isAccessibilitySize',
    'PublicContentStatusView'
)) {
    if (-not $seasonCalendarViewSource.Contains($marker)) {
        throw "Season-calendar view is missing $marker"
    }
}
$seasonCalendarTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\SeasonCalendarContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'testUpcomingScopeAndKindFilterPreserveProviderOrder',
    'testOngoingRangeRemainsUpcomingAndMonthsStayChronological',
    'testRejectsInvalidRangeDuplicateIDsAndOrder',
    'testRejectsInvalidDetailPairAndEventDuration'
)) {
    if (-not $seasonCalendarTests.Contains($marker)) {
        throw "Season-calendar contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testSeasonCalendarUsesAtomicPathAndRecordsFreshness',
    'testSeasonCalendarRejectsOutOfWindowEventBeforeCaching'
)) {
    if (-not $remoteSportsDataTests.Contains($marker)) {
        throw "Season-calendar remote coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testSeasonCalendarIsAtomicOrderedAndBounded',
    'testSeasonCalendarFallbackMarksWholeSnapshotAsDemo'
)) {
    if (-not $mockProviderTestSource.Contains($marker)) {
        throw "Season-calendar mock/fallback coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testUserCanBrowseSeasonCalendarAndOpenCompetition',
    'explore.seasonCalendar',
    'seasonCalendar.event.calendar-cup-draw'
)) {
    if (-not $onboardingUITestSource.Contains($marker)) {
        throw "Season-calendar UI journey is missing $marker"
    }
}

$historicalSeasonContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'HISTORICAL-SEASONS-CONTRACT.md'
) -Encoding utf8
foreach ($marker in @(
    'at most 50 entries',
    'ordered newest to oldest',
    'does not infer missing seasons',
    'late response cannot overwrite a newer selection'
)) {
    if (-not $historicalSeasonContractSource.Contains($marker)) {
        throw "Historical-season product contract is missing $marker"
    }
}
$historicalSeasonTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\HistoricalSeasonCatalogContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'testValidCatalogPreservesNewestFirstProviderOrderAndCurrentSeason',
    'testCatalogRejectsDuplicateSeasonIdentifiers',
    'testCatalogRejectsOldestFirstOrdering',
    'testEqualStartDatesRequireIdentifierAscendingTieBreak',
    'testCurrentSeasonIdentifierAndFlagMustResolveToTheSameEntry',
    'testCurrentSeasonIdentifierCannotReferenceAnOmittedCatalog',
    'testCatalogIsBounded'
)) {
    if (-not $historicalSeasonTests.Contains($marker)) {
        throw "Historical-season DTO coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testHistoricalSeasonArchiveIsDistinctAndMatchCenterAddressable',
    'fixture-history-season-2025-26-final',
    'MockSportsData.historicalSeason.id'
)) {
    if (-not $mockProviderTestSource.Contains($marker)) {
        throw "Historical-season mock coverage is missing $marker"
    }
}
foreach ($localizationKey in @(
    'competition.seasonArchive.title',
    'competition.seasonArchive.sourceNote',
    'competition.seasonArchive.current',
    'competition.seasonArchive.archived',
    'competition.seasonArchive.hint'
)) {
    if ($localizationKey -notin $englishKeys) {
        throw "Historical-season localization is missing $localizationKey"
    }
}

$subscriptionContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SUBSCRIPTION-AD-FREE-CONTRACT.md'
) -Encoding utf8
foreach ($marker in @(
    'support the independent product',
    'suppress SportsHub-controlled advertising',
    'locally verified StoreKit transaction',
    'AppStore.sync',
    'SPORTS_ADVERTISING_ENABLED: false'
)) {
    if (-not $subscriptionContractSource.Contains($marker)) {
        throw "Subscription product contract is missing $marker"
    }
}
$subscriptionModelsSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Commerce\PremiumSubscriptionModels.swift'
) -Encoding utf8
foreach ($marker in @(
    'monthly.period == SubscriptionPeriod(value: 1, unit: .month)',
    'annual.period == SubscriptionPeriod(value: 1, unit: .year)',
    'record.revocationDate == nil',
    '!record.isUpgraded',
    'advertisingEnabled && entitlement == nil'
)) {
    if (-not $subscriptionModelsSource.Contains($marker)) {
        throw "Subscription entitlement contract is missing $marker"
    }
}
$storeKitSubscriptionSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Commerce\StoreKitSubscriptionStoreClient.swift'
) -Encoding utf8
foreach ($marker in @(
    'Product.products(for:',
    'Transaction.currentEntitlements',
    'product.purchase()',
    'AppStore.sync()',
    'Transaction.updates'
)) {
    if (-not $storeKitSubscriptionSource.Contains($marker)) {
        throw "StoreKit subscription client is missing $marker"
    }
}
$subscriptionViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Profile\SubscriptionView.swift'
) -Encoding utf8
foreach ($marker in @(
    'premium.pass',
    'premium.ownership',
    'premium.restore',
    'premium.manage',
    'Text(verbatim: offer.displayName)',
    '.frame(maxWidth: .infinity, minHeight: 44)'
)) {
    if (-not $subscriptionViewSource.Contains($marker)) {
        throw "Subscription view is missing $marker"
    }
}
$subscriptionTests = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\PremiumSubscriptionContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'testConfigurationFailsClosedUntilBothProductsAndLegalLinksAreValid',
    'testOffersRequireExactMonthlyAndAnnualPeriodsInOneGroup',
    'testEntitlementRejectsExpiredRevokedUpgradedAndUnverifiedRecords',
    'testAdvertisingGateRequiresEnabledAdsAndNoPremiumEntitlement',
    'testModelLoadsDynamicOffersPurchasesAndRestoresVerifiedOwnership'
)) {
    if (-not $subscriptionTests.Contains($marker)) {
        throw "Subscription contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testPremiumPreviewPurchasesVerifiedPassAndSuppressesEligibleAds',
    '-ui-test-premium-preview',
    'premium.offer.com.example.sportshub.preview.monthly'
)) {
    if (-not $onboardingUITestSource.Contains($marker)) {
        throw "Subscription UI journey is missing $marker"
    }
}
foreach ($localizationKey in @(
    'premium.title',
    'premium.passTitle',
    'premium.adsDisabledBuild',
    'premium.benefit.rightsBody',
    'premium.action.pending',
    'premium.error.verification',
    'premium.restore',
    'premium.manage',
    'premium.renewalNotice'
)) {
    if ($localizationKey -notin $englishKeys) {
        throw "Subscription localization is missing $localizationKey"
    }
}

$articleVisualBriefContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'ARTICLE-VISUAL-BRIEF-CONTRACT.md'
) -Encoding utf8
foreach ($marker in @(
    'VISUAL_BRIEF',
    '1...4',
    'METRIC_GRID',
    'Dynamic Type',
    'Mock'
)) {
    if (-not $articleVisualBriefContractSource.Contains($marker)) {
        throw "Article Visual Brief contract is missing $marker"
    }
}
$articleVisualBriefViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\News\ArticleVisualBriefView.swift'
) -Encoding utf8
foreach ($marker in @(
    'ArticleVisualBriefView',
    'article.visualBrief',
    'dynamicTypeSize.isAccessibilitySize',
    '.accessibilityElement(children: .combine)',
    'article.visual.item.'
)) {
    if (-not $articleVisualBriefViewSource.Contains($marker)) {
        throw "Article Visual Brief view is missing $marker"
    }
}
$articleVisualBriefTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\ArticleVisualBriefContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'testLegacySavedArticleWithoutFormatMigratesToStory',
    'testLegacyArticlePayloadWithoutFormatMapsToStory',
    'testValidVisualBriefPreservesProviderSectionAndItemOrder',
    'testVisualBriefFormatRequiresStructuredPayload',
    'testComparisonRequiresExactlyTwoItems',
    'testDuplicateItemIDsAcrossSectionsAreRejected',
    'testDuplicateSectionIDsAreRejected',
    'testMetricAndSequenceSectionsRejectMoreThanSixItems',
    'testVisualValueLengthAndControlCharactersFailClosed'
)) {
    if (-not $articleVisualBriefTestSource.Contains($marker)) {
        throw "Article Visual Brief contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testVisualBriefArticleWithoutPayloadIsRejectedBeforeCaching',
    'article.visual.section.match-pulse',
    'article.visual.item.metric-shots'
)) {
    if (-not $remoteProviderTestSource.Contains($marker) -and
        -not $onboardingUITestSource.Contains($marker)) {
        throw "Article Visual Brief remote/UI coverage is missing $marker"
    }
}

$articleEngagementContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md'
) -Encoding utf8
foreach ($marker in @(
    'totalReactions',
    'publishedComments',
    'Missing means unavailable, not zero',
    'Cache-Control: no-store',
    'share analytics'
)) {
    if (-not $articleEngagementContractSource.Contains($marker)) {
        throw "Article engagement contract is missing $marker"
    }
}
$articleEngagementViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\News\ArticleEngagementSummaryView.swift'
) -Encoding utf8
foreach ($marker in @(
    'ArticleEngagementSummaryView',
    'dynamicTypeSize.isAccessibilitySize',
    'article.engagement.',
    '.accessibilityLabel',
    'formattedValue'
)) {
    if (-not $articleEngagementViewSource.Contains($marker)) {
        throw "Article engagement view is missing $marker"
    }
}
$articleEngagementTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\ArticleEngagementSummaryContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'testLegacySavedArticleWithoutEngagementKeepsSummaryUnavailable',
    'testLegacyAPIPayloadWithoutEngagementKeepsSummaryUnavailable',
    'testValidEngagementMapsExactPublicCounts',
    'testInvalidWireCountsFailClosedWithExactField',
    'testCorruptPersistedEngagementIsRejected'
)) {
    if (-not $articleEngagementTestSource.Contains($marker)) {
        throw "Article engagement contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testArticlesRejectInvalidEngagementBeforeCaching',
    'Reactions: 202',
    'Published comments: 3'
)) {
    if (-not $remoteProviderTestSource.Contains($marker) -and
        -not $onboardingUITestSource.Contains($marker)) {
        throw "Article engagement remote/UI coverage is missing $marker"
    }
}

$articleHeroMediaContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'ARTICLE-HERO-MEDIA-CONTRACT.md'
) -Encoding utf8
foreach ($marker in @(
    'SportsMediaAllowedHosts',
    '8 MiB',
    'rejects redirects',
    'Mock articles contain no third-party URL or photo',
    'Personal saved-article snapshots deliberately omit',
    'VoiceOver'
)) {
    if (-not $articleHeroMediaContractSource.Contains($marker)) {
        throw "Article hero-media contract is missing $marker"
    }
}
$articleHeroMediaModelSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Shared\Models.swift'
) -Encoding utf8
$articleHeroMediaDTOSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Data\SportsDataDTOs.swift'
) -Encoding utf8
$articleHeroMediaPipelineSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Media\ArticleMediaConfiguration.swift'
) -Encoding utf8
$articleHeroMediaViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\News\ArticleHeroMediaView.swift'
) -Encoding utf8
$articleHeroMediaDecoderSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Core\Media\ArticleHeroImageDecoder.swift'
) -Encoding utf8
foreach ($marker in @(
    'struct ArticleHeroMedia',
    'maximumByteCount',
    'heroMedia = nil'
)) {
    if (-not $articleHeroMediaModelSource.Contains($marker)) {
        throw "Article hero-media model is missing $marker"
    }
}
foreach ($marker in @(
    'struct ArticleHeroMediaDTO',
    'validatedEditorialMediaURL',
    'multipliedReportingOverflow',
    '1.2...2.4'
)) {
    if (-not $articleHeroMediaDTOSource.Contains($marker)) {
        throw "Article hero-media DTO is missing $marker"
    }
}
foreach ($marker in @(
    'ArticleMediaNoRedirectDelegate',
    'httpShouldSetCookies = false',
    'urlCredentialStorage = nil',
    'session.bytes(for: request)',
    'data.count < EditorialImageMediaPolicy.maximumByteCount',
    'allowedHosts.contains(host)'
)) {
    if (-not $articleHeroMediaPipelineSource.Contains($marker)) {
        throw "Article hero-media pipeline is missing $marker"
    }
}
if ($articleHeroMediaPipelineSource.Contains('forHTTPHeaderField: "Authorization"')) {
    throw 'Article hero-media requests must not carry an Authorization header.'
}
foreach ($marker in @(
    'ArticleHeroImageDecoder.shared.decode',
    'maximumDisplayPixelSize',
    'article.heroMedia.',
    '.accessibilityHidden(true)',
    '.frame(minHeight: 44)',
    'activeLoadID == loadID'
)) {
    if (-not $articleHeroMediaViewSource.Contains($marker)) {
        throw "Article hero-media view is missing $marker"
    }
}
foreach ($marker in @(
    'import ImageIO',
    'CGImageSourceCopyPropertiesAtIndex',
    'CGImageSourceGetType',
    'UTType(mimeType:',
    'CGImageSourceCreateThumbnailAtIndex',
    'ArticleHeroDisplayImage: @unchecked Sendable'
)) {
    if (-not $articleHeroMediaDecoderSource.Contains($marker)) {
        throw "Article hero-media decoder is missing $marker"
    }
}
$articleHeroMediaTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\ArticleHeroMediaContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'testValidHeroMediaMapsExactEditorialMetadata',
    'testMissingOrNullHeroMediaMigratesToOriginalCover',
    'testHeroMediaRejectsUnsafeURLMimeDimensionsAndText',
    'testSavedArticleSnapshotOmitsMediaURLAndDecodesWithoutMedia',
    'testMediaHostConfigurationRequiresExactExternalHost',
    'testImageResponseValidatorFailsClosedOnStatusMimeAndByteLimits',
    'testRedirectDelegateRejectsFollowUpRequest',
    'testDecoderVerifiesBodyTypeAndDimensionsBeforeDownsampling'
)) {
    if (-not $articleHeroMediaTestSource.Contains($marker)) {
        throw "Article hero-media contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testArticlesRejectUnsafeHeroMediaBeforeCaching',
    'hero-remote',
    'Image unavailable'
)) {
    if (-not $remoteProviderTestSource.Contains($marker) -and
        -not $onboardingUITestSource.Contains($marker)) {
        throw "Article hero-media remote/UI coverage is missing $marker"
    }
}

$videoProgramContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'VIDEO-PROGRAM-HUB-CONTRACT.md'
) -Encoding utf8
$videoProgramViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Video\VideoProgramViews.swift'
) -Encoding utf8
$videoProgramTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\VideoProgramHubContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'order is authoritative',
    'first-page failures may switch the entire visible resource',
    'programme object introduces no logo, remote artwork, host',
    'sizes use one logical leading-aligned column',
    'Xcode compilation, XCTest'
)) {
    if (-not $videoProgramContractSource.Contains($marker)) {
        throw "Video program product contract is missing $marker"
    }
}
foreach ($marker in @(
    'struct VideoProgramSummary:',
    'struct VideoProgramPage:',
    'struct VideoProgramEpisode:',
    'struct VideoProgramDetailsPage:'
)) {
    if (-not $articleHeroMediaModelSource.Contains($marker)) {
        throw "Video program domain model is missing $marker"
    }
}
foreach ($marker in @(
    'struct VideoProgramSummaryDTO:',
    'struct VideoProgramListResponseDTO:',
    'struct VideoProgramDetailResponseDTO:',
    'validateVideoProgramPage(',
    'validatedVideoProgramIdentifier(',
    'featuredVideo must be an explicit object or null',
    'publishedAt must be an explicit date or null'
)) {
    if (-not $articleHeroMediaDTOSource.Contains($marker)) {
        throw "Video program DTO validation is missing $marker"
    }
}
foreach ($marker in @(
    'func videoPrograms(',
    'func videoProgramDetails(',
    'VideoProgramListResponseDTO.self',
    'VideoProgramDetailResponseDTO.self',
    'resource: .videoPrograms(sport: sport)',
    'resource: .videoProgram(id: id)'
)) {
    if (-not $remoteProviderSource.Contains($marker)) {
        throw "Remote video program provider is missing $marker"
    }
}
foreach ($marker in @(
    '/video-programs:',
    '/video-programs/{programId}:',
    'VideoProgramListResponse:',
    'VideoProgramDetailResponse:',
    'maxLength: 2048',
    'maximum: 50'
)) {
    if (-not $apiContract.Contains($marker)) {
        throw "Video program API contract is missing $marker"
    }
}
foreach ($marker in @(
    'struct VideoProgramLibraryView:',
    'struct VideoProgramDetailView:',
    'dynamicTypeSize.isAccessibilitySize ? 1 : 2',
    'video.programs.boundary',
    'video.program.card.',
    'video.program.episode.',
    'video.programs.featured',
    '.accessibilityAddTraits(isSelected ? .isSelected : [])',
    'VideoPosterMediaView(video: featuredVideo'
)) {
    if (-not $videoProgramViewSource.Contains($marker)) {
        throw "Video program UI is missing $marker"
    }
}
foreach ($marker in @(
    'testListMapsProviderOrderSportAndExplicitFeaturedVideo',
    'testFeaturedVideoAndPublishedDateMustBeExplicitObjectOrNull',
    'testTextBoundariesAndControlCharactersFailClosed',
    'testDuplicateIdentifiersAndInvalidPagingFailClosed',
    'testDetailRejectsProgramMismatchAndDuplicateEpisodes',
    'testCrossPageProgramAndEpisodeDuplicatesFailClosed'
)) {
    if (-not $videoProgramTestSource.Contains($marker)) {
        throw "Video program contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testVideoProgramEndpointsPreserveQueriesOrderAndPublicCaching',
    'testVideoProgramDetailRejectsUnsafeOrMismatchedIdentifierBeforeCaching',
    'testVideoProgramLibraryFiltersPaginatesAndPreservesEpisodeMembership',
    'testVideoProgramFallbackIsFirstPageOnlyAndTerminatesPagination'
)) {
    if (-not $remoteProviderTestSource.Contains($marker) -and
        -not $mockProviderTestSource.Contains($marker)) {
        throw "Video program provider coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testUserCanBrowseProgramsAndOpenAnAuthorizedEpisode',
    'video.programs.entry',
    'video.program.card.program-tactics-studio',
    'video.program.episode.video-original-1'
)) {
    if (-not $onboardingUITestSource.Contains($marker)) {
        throw "Video program UI journey is missing $marker"
    }
}

$videoPosterContractSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'VIDEO-POSTER-MEDIA-CONTRACT.md'
) -Encoding utf8
$videoPosterViewSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHub\Features\Video\VideoPosterMediaView.swift'
) -Encoding utf8
$videoPosterTestSource = Get-Content -Raw -LiteralPath (
    Join-Path $projectRoot 'SportsHubTests\VideoPosterMediaContractTests.swift'
) -Encoding utf8
foreach ($marker in @(
    'Poster display rights do not grant video playback rights',
    'SportsMediaAllowedHosts',
    'Personal favorite/history/continue-watching snapshots omit',
    'Mock videos contain no third-party URL, photograph or frame',
    'VoiceOver'
)) {
    if (-not $videoPosterContractSource.Contains($marker)) {
        throw "Video poster-media contract is missing $marker"
    }
}
foreach ($marker in @(
    'struct VideoPosterMedia',
    'let poster: VideoPosterMedia?',
    'poster = nil'
)) {
    if (-not $articleHeroMediaModelSource.Contains($marker)) {
        throw "Video poster-media model is missing $marker"
    }
}
foreach ($marker in @(
    'struct VideoPosterMediaDTO',
    'poster?.domain(field:',
    'validatedEditorialMediaURL',
    '1.2...2.4'
)) {
    if (-not $articleHeroMediaDTOSource.Contains($marker)) {
        throw "Video poster-media DTO is missing $marker"
    }
}
foreach ($marker in @(
    'VideoPosterImagePipeline.shared.data',
    'VideoPosterImageDecoder.shared.decode',
    'video.poster.',
    '.accessibilityHidden(true)',
    '.frame(minHeight: 44)',
    'activeLoadID == loadID'
)) {
    if (-not $videoPosterViewSource.Contains($marker)) {
        throw "Video poster-media view is missing $marker"
    }
}
foreach ($marker in @(
    'testValidPosterMapsExactEditorialMetadataWithoutGrantingPlayback',
    'testMissingOrNullPosterMigratesToOriginalVideoArtwork',
    'testPosterRejectsUnsafeURLMimeDimensionsAndText',
    'testPersonalVideoSnapshotOmitsPosterURLAndDecodesWithoutPoster',
    'testPersonalStoreDropsPosterBeforeHoldingSnapshotInMemory',
    'testSharedDecoderVerifiesPosterBodyBeforeDownsampling'
)) {
    if (-not $videoPosterTestSource.Contains($marker)) {
        throw "Video poster-media contract coverage is missing $marker"
    }
}
foreach ($marker in @(
    'testVideosRejectUnsafePosterBeforeCaching',
    'poster-video-remote',
    'video.poster.video-highlight-1.retry'
)) {
    if (-not $remoteProviderTestSource.Contains($marker) -and
        -not $onboardingUITestSource.Contains($marker)) {
        throw "Video poster-media remote/UI coverage is missing $marker"
    }
}

$accessibilityIdentifierCount = ([regex]::Matches($allSwiftContent, '\.accessibilityIdentifier\(')).Count
$accessibilityLabelCount = ([regex]::Matches($allSwiftContent, '\.accessibilityLabel\(')).Count
if ($accessibilityIdentifierCount -lt 8 -or $accessibilityLabelCount -lt 3) {
    throw 'The initial slice does not include enough accessibility/test hooks.'
}

Write-Output 'SportsHub scaffold verification: PASS'
Write-Output "Required files: $($requiredFiles.Count)"
Write-Output "Shared localization keys: $($englishKeys.Count)"
Write-Output "Localized initializer keys checked: $($referencedLocalizationKeys.Count)"
Write-Output "Swift source files checked: $($swiftFiles.Count)"
Write-Output "Accessibility identifiers: $accessibilityIdentifierCount"
Write-Output "Accessibility labels: $accessibilityLabelCount"
Write-Output 'Boundary: this is a static Windows check, not an Xcode build.'
