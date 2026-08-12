package com.example.sportshub.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.sportshub.domain.AppLanguage
import com.example.sportshub.domain.Fixture
import com.example.sportshub.domain.FixtureFilter
import com.example.sportshub.domain.GetSportsSnapshotUseCase
import com.example.sportshub.domain.ObserveUserPreferencesUseCase
import com.example.sportshub.domain.SetLanguageUseCase
import com.example.sportshub.domain.SetOnboardingCompleteUseCase
import com.example.sportshub.domain.SportsSnapshot
import com.example.sportshub.domain.ToggleFollowedTeamUseCase
import com.example.sportshub.domain.VideoSport
import com.example.sportshub.domain.filterBy
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class AppTab { HOME, MATCHES, EXPLORE, FOLLOWING, PROFILE }

sealed interface Destination {
    data object Main : Destination
    data class FixtureDetails(val fixtureId: String) : Destination
    data object Programs : Destination
    data class ProgramDetails(val programId: String) : Destination
    data class VideoDetails(val programId: String, val videoId: String) : Destination
}

data class AppUiState(
    val language: AppLanguage = AppLanguage.ARABIC,
    val onboardingComplete: Boolean = false,
    val followedTeamIds: Set<String> = emptySet(),
    val snapshot: SportsSnapshot? = null,
    val loading: Boolean = true,
    val error: String? = null,
    val selectedTab: AppTab = AppTab.HOME,
    val destination: Destination = Destination.Main,
    val fixtureFilter: FixtureFilter = FixtureFilter.ALL,
    val programSport: VideoSport? = null,
    val reminderFixtureIds: Set<String> = emptySet(),
) {
    val filteredFixtures: List<Fixture>
        get() = snapshot?.fixtures.orEmpty().filterBy(fixtureFilter)
}

sealed interface AppEvent {
    data class SetLanguage(val language: AppLanguage) : AppEvent
    data object CompleteOnboarding : AppEvent
    data object SkipOnboarding : AppEvent
    data class ToggleTeam(val teamId: String) : AppEvent
    data class SelectTab(val tab: AppTab) : AppEvent
    data class OpenFixture(val fixtureId: String) : AppEvent
    data object OpenPrograms : AppEvent
    data class OpenProgram(val programId: String) : AppEvent
    data class OpenVideo(val programId: String, val videoId: String) : AppEvent
    data object Back : AppEvent
    data class SetFixtureFilter(val filter: FixtureFilter) : AppEvent
    data class SetProgramSport(val sport: VideoSport?) : AppEvent
    data class ToggleReminder(val fixtureId: String) : AppEvent
    data object Retry : AppEvent
    data object EditInterests : AppEvent
}

class AppViewModel(
    private val getSportsSnapshot: GetSportsSnapshotUseCase,
    private val observePreferences: ObserveUserPreferencesUseCase,
    private val setLanguage: SetLanguageUseCase,
    private val setOnboardingComplete: SetOnboardingCompleteUseCase,
    private val toggleFollowedTeam: ToggleFollowedTeamUseCase,
) : ViewModel() {
    private val _state = MutableStateFlow(AppUiState())
    val state: StateFlow<AppUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            observePreferences().collect { preferences ->
                _state.update {
                    it.copy(
                        language = preferences.language,
                        onboardingComplete = preferences.onboardingComplete,
                        followedTeamIds = preferences.followedTeamIds,
                    )
                }
            }
        }
        load()
    }

    fun onEvent(event: AppEvent) {
        when (event) {
            is AppEvent.SetLanguage -> viewModelScope.launch { setLanguage(event.language) }
            AppEvent.CompleteOnboarding -> {
                if (_state.value.followedTeamIds.isNotEmpty()) {
                    viewModelScope.launch { setOnboardingComplete(true) }
                }
            }
            AppEvent.SkipOnboarding -> viewModelScope.launch { setOnboardingComplete(true) }
            is AppEvent.ToggleTeam -> viewModelScope.launch { toggleFollowedTeam(event.teamId) }
            is AppEvent.SelectTab -> _state.update {
                it.copy(selectedTab = event.tab, destination = Destination.Main)
            }
            is AppEvent.OpenFixture -> _state.update {
                it.copy(destination = Destination.FixtureDetails(event.fixtureId))
            }
            AppEvent.OpenPrograms -> _state.update { it.copy(destination = Destination.Programs) }
            is AppEvent.OpenProgram -> _state.update {
                it.copy(destination = Destination.ProgramDetails(event.programId))
            }
            is AppEvent.OpenVideo -> _state.update {
                it.copy(destination = Destination.VideoDetails(event.programId, event.videoId))
            }
            AppEvent.Back -> _state.update { current ->
                current.copy(
                    destination = when (val destination = current.destination) {
                        is Destination.VideoDetails -> Destination.ProgramDetails(destination.programId)
                        is Destination.ProgramDetails -> Destination.Programs
                        else -> Destination.Main
                    },
                )
            }
            is AppEvent.SetFixtureFilter -> _state.update { it.copy(fixtureFilter = event.filter) }
            is AppEvent.SetProgramSport -> _state.update { it.copy(programSport = event.sport) }
            is AppEvent.ToggleReminder -> _state.update {
                val next = it.reminderFixtureIds.toMutableSet().apply {
                    if (!add(event.fixtureId)) remove(event.fixtureId)
                }
                it.copy(reminderFixtureIds = next)
            }
            AppEvent.Retry -> load()
            AppEvent.EditInterests -> viewModelScope.launch { setOnboardingComplete(false) }
        }
    }

    private fun load() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            getSportsSnapshot().fold(
                onSuccess = { snapshot -> _state.update { it.copy(snapshot = snapshot, loading = false) } },
                onFailure = { error ->
                    _state.update { it.copy(loading = false, error = error.message ?: "Unable to load") }
                },
            )
        }
    }

    companion object {
        fun factory(
            getSportsSnapshot: GetSportsSnapshotUseCase,
            observePreferences: ObserveUserPreferencesUseCase,
            setLanguage: SetLanguageUseCase,
            setOnboardingComplete: SetOnboardingCompleteUseCase,
            toggleFollowedTeam: ToggleFollowedTeamUseCase,
        ): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T = AppViewModel(
                getSportsSnapshot,
                observePreferences,
                setLanguage,
                setOnboardingComplete,
                toggleFollowedTeam,
            ) as T
        }
    }
}
