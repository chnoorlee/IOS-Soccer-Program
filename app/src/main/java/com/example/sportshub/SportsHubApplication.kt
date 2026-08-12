package com.example.sportshub

import android.app.Application
import com.example.sportshub.data.SharedPreferencesUserPreferencesRepository

class SportsHubApplication : Application() {
    val preferencesRepository: SharedPreferencesUserPreferencesRepository by lazy {
        SharedPreferencesUserPreferencesRepository(
            getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE),
        )
    }

    companion object {
        const val PREFERENCES_NAME = "sportshub_preferences"
    }
}

