package com.example.sportshub.data

import android.content.SharedPreferences
import androidx.core.content.edit
import com.example.sportshub.domain.AppLanguage
import com.example.sportshub.domain.UserPreferences
import com.example.sportshub.domain.UserPreferencesRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class SharedPreferencesUserPreferencesRepository(
    private val preferences: SharedPreferences,
) : UserPreferencesRepository {
    private val mutex = Mutex()
    private val state = MutableStateFlow(read())
    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
        state.value = read()
    }

    init {
        preferences.registerOnSharedPreferenceChangeListener(listener)
    }

    override fun observe(): StateFlow<UserPreferences> = state.asStateFlow()

    override suspend fun setLanguage(language: AppLanguage) = update {
        preferences.edit(commit = true) { putString(KEY_LANGUAGE, language.name) }
    }

    override suspend fun setOnboardingComplete(complete: Boolean) = update {
        preferences.edit(commit = true) { putBoolean(KEY_ONBOARDING_COMPLETE, complete) }
    }

    override suspend fun toggleFollowedTeam(teamId: String) = update {
        val next = read().followedTeamIds.toMutableSet().apply {
            if (!add(teamId)) remove(teamId)
        }
        preferences.edit(commit = true) { putStringSet(KEY_FOLLOWED_TEAMS, next) }
    }

    private suspend fun update(block: () -> Unit) = mutex.withLock {
        block()
        state.value = read()
    }

    private fun read(): UserPreferences = UserPreferences(
        language = preferences.getString(KEY_LANGUAGE, AppLanguage.ARABIC.name)
            ?.let { value -> runCatching { AppLanguage.valueOf(value) }.getOrNull() }
            ?: AppLanguage.ARABIC,
        onboardingComplete = preferences.getBoolean(KEY_ONBOARDING_COMPLETE, false),
        followedTeamIds = preferences.getStringSet(KEY_FOLLOWED_TEAMS, emptySet()).orEmpty().toSet(),
    )

    private companion object {
        const val KEY_LANGUAGE = "language"
        const val KEY_ONBOARDING_COMPLETE = "onboarding_complete"
        const val KEY_FOLLOWED_TEAMS = "followed_team_ids"
    }
}
