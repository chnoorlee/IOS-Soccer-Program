package com.example.sportshub.presentation

import androidx.compose.runtime.Composable
import com.example.sportshub.domain.AppLanguage
import com.example.sportshub.domain.FixtureFilter
import com.example.sportshub.domain.FixtureState
import com.example.sportshub.domain.VideoSport
import com.example.sportshub.domain.VideoType

fun text(language: AppLanguage, arabic: String, english: String): String =
    if (language == AppLanguage.ARABIC) arabic else english

fun FixtureState.label(language: AppLanguage): String = when (this) {
    FixtureState.UPCOMING -> text(language, "قريباً", "Upcoming")
    FixtureState.LIVE -> text(language, "مباشر", "Live")
    FixtureState.HALF_TIME -> text(language, "استراحة", "Half time")
    FixtureState.FINISHED -> text(language, "انتهت", "Finished")
    FixtureState.POSTPONED -> text(language, "مؤجلة", "Postponed")
    FixtureState.CANCELLED -> text(language, "ملغاة", "Cancelled")
}

fun FixtureFilter.label(language: AppLanguage): String = when (this) {
    FixtureFilter.ALL -> text(language, "الكل", "All")
    FixtureFilter.LIVE -> text(language, "مباشر", "Live")
    FixtureFilter.UPCOMING -> text(language, "قادمة", "Upcoming")
    FixtureFilter.FINISHED -> text(language, "النتائج", "Results")
}

fun VideoSport.label(language: AppLanguage): String = when (this) {
    VideoSport.FOOTBALL -> text(language, "كرة القدم", "Football")
    VideoSport.BASKETBALL -> text(language, "كرة السلة", "Basketball")
    VideoSport.ESPORTS -> text(language, "رياضات إلكترونية", "Esports")
}

fun VideoType.label(language: AppLanguage): String = when (this) {
    VideoType.LIVE -> text(language, "مباشر", "Live")
    VideoType.HIGHLIGHT -> text(language, "ملخص", "Highlights")
    VideoType.REPLAY -> text(language, "إعادة", "Replay")
    VideoType.ORIGINAL -> text(language, "أصلي", "Original")
    VideoType.INTERVIEW -> text(language, "مقابلة", "Interview")
}

@Composable
fun appTabLabel(tab: AppTab, language: AppLanguage): String = when (tab) {
    AppTab.HOME -> text(language, "الرئيسية", "Home")
    AppTab.MATCHES -> text(language, "المباريات", "Matches")
    AppTab.EXPLORE -> text(language, "اكتشف", "Explore")
    AppTab.FOLLOWING -> text(language, "متابعاتي", "Following")
    AppTab.PROFILE -> text(language, "حسابي", "Profile")
}

