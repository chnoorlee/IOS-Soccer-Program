package com.example.sportshub

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SportsHubJourneyTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Before
    fun resetPreferences() {
        composeRule.activity.getSharedPreferences(SportsHubApplication.PREFERENCES_NAME, 0)
            .edit()
            .clear()
            .commit()
        composeRule.activityRule.scenario.recreate()
        composeRule.waitForIdle()
    }

    @Test
    fun onboardingToMatchCenterJourney() {
        composeRule.onNodeWithTag("onboarding_screen").assertIsDisplayed()
        composeRule.onNodeWithTag("language_english").performClick()
        composeRule.onNodeWithTag("onboarding_team_riyadh-falcons").performClick()
        composeRule.onNodeWithTag("onboarding_continue").performClick()

        composeRule.onNodeWithTag("home_screen").assertIsDisplayed()
        composeRule.onNodeWithTag("tab_matches").performClick()
        composeRule.onNodeWithTag("matches_screen").assertIsDisplayed()
        composeRule.onNodeWithTag("fixture_fixture-live-1").performClick()
        composeRule.onNodeWithTag("fixture_detail_screen").assertIsDisplayed()
        composeRule.onNodeWithTag("fixture_reminder").performClick()
    }

    @Test
    fun exploreProgramEpisodeShowsPlaybackBoundary() {
        composeRule.onNodeWithTag("onboarding_skip").performClick()
        composeRule.onNodeWithTag("tab_explore").performClick()
        composeRule.onNodeWithTag("explore_programs").performClick()
        composeRule.onNodeWithTag("program_program-match-desk").performClick()
        composeRule.onNodeWithTag("program_detail_screen").assertIsDisplayed()
        composeRule.onNodeWithTag("video_video-live-1").performClick()
        composeRule.onNodeWithTag("video_detail_screen").assertIsDisplayed()
    }
}
