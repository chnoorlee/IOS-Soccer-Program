package com.example.sportshub.domain

import kotlinx.coroutines.flow.Flow

interface SportsRepository {
    suspend fun getSnapshot(): Result<SportsSnapshot>
}

interface UserPreferencesRepository {
    fun observe(): Flow<UserPreferences>
    suspend fun setLanguage(language: AppLanguage)
    suspend fun setOnboardingComplete(complete: Boolean)
    suspend fun toggleFollowedTeam(teamId: String)
}

class GetSportsSnapshotUseCase(private val repository: SportsRepository) {
    suspend operator fun invoke(): Result<SportsSnapshot> = repository.getSnapshot()
}

class ObserveUserPreferencesUseCase(private val repository: UserPreferencesRepository) {
    operator fun invoke(): Flow<UserPreferences> = repository.observe()
}

class SetLanguageUseCase(private val repository: UserPreferencesRepository) {
    suspend operator fun invoke(language: AppLanguage) = repository.setLanguage(language)
}

class SetOnboardingCompleteUseCase(private val repository: UserPreferencesRepository) {
    suspend operator fun invoke(complete: Boolean) = repository.setOnboardingComplete(complete)
}

class ToggleFollowedTeamUseCase(private val repository: UserPreferencesRepository) {
    suspend operator fun invoke(teamId: String) = repository.toggleFollowedTeam(teamId)
}

fun List<Fixture>.filterBy(stateFilter: FixtureFilter): List<Fixture> = when (stateFilter) {
    FixtureFilter.ALL -> this
    FixtureFilter.LIVE -> filter { it.state == FixtureState.LIVE || it.state == FixtureState.HALF_TIME }
    FixtureFilter.UPCOMING -> filter { it.state == FixtureState.UPCOMING }
    FixtureFilter.FINISHED -> filter { it.state == FixtureState.FINISHED }
}

enum class FixtureFilter { ALL, LIVE, UPCOMING, FINISHED }

