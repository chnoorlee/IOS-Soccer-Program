package com.example.sportshub.domain

import java.time.Instant

enum class AppLanguage { ARABIC, ENGLISH }

data class BilingualText(
    val arabic: String,
    val english: String,
) {
    fun value(language: AppLanguage): String =
        if (language == AppLanguage.ARABIC) arabic else english
}

data class Team(
    val id: String,
    val name: BilingualText,
    val monogram: String,
    val color: Long,
)

data class Competition(
    val id: String,
    val name: BilingualText,
)

enum class FixtureState { UPCOMING, LIVE, HALF_TIME, FINISHED, POSTPONED, CANCELLED }

data class Fixture(
    val id: String,
    val competition: Competition,
    val homeTeam: Team,
    val awayTeam: Team,
    val kickoff: Instant,
    val state: FixtureState,
    val minute: Int? = null,
    val homeScore: Int? = null,
    val awayScore: Int? = null,
    val venue: BilingualText,
) {
    val score: String?
        get() = if (homeScore != null && awayScore != null) "$homeScore – $awayScore" else null
}

data class Article(
    val id: String,
    val title: BilingualText,
    val summary: BilingualText,
    val source: String,
    val category: BilingualText,
    val minutesAgo: Int,
    val corrected: Boolean = false,
)

enum class VideoSport { FOOTBALL, BASKETBALL, ESPORTS }

enum class VideoType { LIVE, HIGHLIGHT, REPLAY, ORIGINAL, INTERVIEW }

data class SportsVideo(
    val id: String,
    val title: BilingualText,
    val description: BilingualText,
    val type: VideoType,
    val durationMinutes: Int,
    val isPlayable: Boolean,
    val unavailableReason: BilingualText,
)

data class VideoProgram(
    val id: String,
    val title: BilingualText,
    val description: BilingualText,
    val sport: VideoSport,
    val episodes: List<SportsVideo>,
)

data class MatchEvent(
    val id: String,
    val minute: Int,
    val title: BilingualText,
    val detail: BilingualText,
)

data class MatchStat(
    val label: BilingualText,
    val homeValue: String,
    val awayValue: String,
)

data class SportsSnapshot(
    val teams: List<Team>,
    val fixtures: List<Fixture>,
    val articles: List<Article>,
    val programs: List<VideoProgram>,
    val eventsByFixture: Map<String, List<MatchEvent>>,
    val statsByFixture: Map<String, List<MatchStat>>,
)

data class UserPreferences(
    val language: AppLanguage = AppLanguage.ARABIC,
    val onboardingComplete: Boolean = false,
    val followedTeamIds: Set<String> = emptySet(),
)

