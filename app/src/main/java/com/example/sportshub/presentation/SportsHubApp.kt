package com.example.sportshub.presentation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.sportshub.domain.AppLanguage

@Composable
fun SportsHubApp(viewModel: AppViewModel) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    SportsHubApp(state = state, onEvent = viewModel::onEvent)
}

@Composable
fun SportsHubApp(state: AppUiState, onEvent: (AppEvent) -> Unit) {
    val direction = if (state.language == AppLanguage.ARABIC) LayoutDirection.Rtl else LayoutDirection.Ltr
    CompositionLocalProvider(LocalLayoutDirection provides direction) {
        when {
            state.loading && state.snapshot == null -> LoadingScreen()
            state.error != null && state.snapshot == null -> ErrorScreen(state.language, state.error, onEvent)
            !state.onboardingComplete -> OnboardingScreen(state, onEvent)
            else -> MainShell(state, onEvent)
        }
    }
}

@Composable
private fun LoadingScreen() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
private fun ErrorScreen(language: AppLanguage, message: String, onEvent: (AppEvent) -> Unit) {
    Scaffold { padding ->
        Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
            androidx.compose.foundation.layout.Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(text(language, "تعذر تحميل البيانات", "Unable to load data"), style = MaterialTheme.typography.titleLarge)
                Text(message, style = MaterialTheme.typography.bodyMedium)
                TextButton(onClick = { onEvent(AppEvent.Retry) }) {
                    Text(text(language, "إعادة المحاولة", "Retry"))
                }
            }
        }
    }
}

