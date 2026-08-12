package com.example.sportshub.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val DeepInk = Color(0xFF071C33)
val SignalCyan = Color(0xFF09A9B5)
val TimingGold = Color(0xFFF4B942)
val Canvas = Color(0xFFF7F8FA)

private val LightColors = lightColorScheme(
    primary = SignalCyan,
    onPrimary = Color.White,
    secondary = TimingGold,
    onSecondary = DeepInk,
    background = Canvas,
    onBackground = DeepInk,
    surface = Color.White,
    onSurface = DeepInk,
    surfaceVariant = Color(0xFFE6EDF0),
)

@Composable
fun SportsHubTheme(
    content: @Composable () -> Unit,
) {
    // The migrated visual system is intentionally light-only until every custom
    // SportsHub surface has a separately reviewed dark color token.
    MaterialTheme(colorScheme = LightColors, content = content)
}
