package com.example.sportshub

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.sportshub.data.DemoSportsRepository
import com.example.sportshub.domain.GetSportsSnapshotUseCase
import com.example.sportshub.domain.ObserveUserPreferencesUseCase
import com.example.sportshub.domain.SetLanguageUseCase
import com.example.sportshub.domain.SetOnboardingCompleteUseCase
import com.example.sportshub.domain.ToggleFollowedTeamUseCase
import com.example.sportshub.presentation.AppViewModel
import com.example.sportshub.presentation.SportsHubApp
import com.example.sportshub.ui.theme.SportsHubTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val preferencesRepository = (application as SportsHubApplication).preferencesRepository
        val factory = AppViewModel.factory(
            getSportsSnapshot = GetSportsSnapshotUseCase(DemoSportsRepository),
            observePreferences = ObserveUserPreferencesUseCase(preferencesRepository),
            setLanguage = SetLanguageUseCase(preferencesRepository),
            setOnboardingComplete = SetOnboardingCompleteUseCase(preferencesRepository),
            toggleFollowedTeam = ToggleFollowedTeamUseCase(preferencesRepository),
        )

        setContent {
            SportsHubTheme {
                val appViewModel: AppViewModel = viewModel(factory = factory)
                SportsHubApp(viewModel = appViewModel)
            }
        }
    }
}
