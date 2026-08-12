package com.example.sportshub.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.sportshub.domain.AppLanguage
import com.example.sportshub.domain.Fixture
import com.example.sportshub.domain.FixtureState
import com.example.sportshub.domain.Team
import com.example.sportshub.ui.theme.DeepInk
import com.example.sportshub.ui.theme.SignalCyan
import com.example.sportshub.ui.theme.TimingGold
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    action: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        if (action != null && onAction != null) {
            AssistChip(onClick = onAction, label = { Text(action) })
        }
    }
}

@Composable
fun DemoDataBanner(language: AppLanguage, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier.fillMaxWidth().testTag("demo_data_banner"),
        color = TimingGold.copy(alpha = 0.18f),
        shape = RoundedCornerShape(14.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("●", color = TimingGold, fontSize = 16.sp)
            Spacer(Modifier.width(8.dp))
            Text(
                text(language, "بيانات تجريبية خيالية · لا تمثل نتائج حقيقية", "Fictional demo data · not real results"),
                style = MaterialTheme.typography.labelLarge,
                color = DeepInk,
            )
        }
    }
}

@Composable
fun TeamBadge(team: Team, modifier: Modifier = Modifier, size: Int = 48) {
    val background = Color(team.color)
    Box(
        modifier = modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(background),
        contentAlignment = Alignment.Center,
    ) {
        Text(team.monogram, color = Color.White, fontWeight = FontWeight.Black)
    }
}

@Composable
fun FixtureCard(
    fixture: Fixture,
    language: AppLanguage,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val stateColor = if (fixture.state == FixtureState.LIVE) Color(0xFFB3261E) else SignalCyan
    Card(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().testTag("fixture_${fixture.id}"),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(
                    fixture.competition.name.value(language),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(fixture.state.label(language), color = stateColor, fontWeight = FontWeight.Bold)
            }
            Row(
                Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                TeamColumn(fixture.homeTeam, language)
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        fixture.score ?: formatKickoff(fixture),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Black,
                    )
                    fixture.minute?.let { Text("$it′", color = stateColor) }
                }
                TeamColumn(fixture.awayTeam, language)
            }
            Text(
                fixture.venue.value(language),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun TeamColumn(team: Team, language: AppLanguage) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(104.dp)) {
        TeamBadge(team)
        Spacer(Modifier.height(6.dp))
        Text(
            team.name.value(language),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

fun formatKickoff(fixture: Fixture): String = fixture.kickoff
    .atZone(ZoneId.systemDefault())
    .format(DateTimeFormatter.ofPattern("HH:mm"))

@Composable
fun SelectionCard(
    title: String,
    subtitle: String,
    selected: Boolean,
    tag: String,
    onClick: () -> Unit,
    leading: @Composable () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(18.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MaterialTheme.colorScheme.surface)
            .border(if (selected) 2.dp else 1.dp, if (selected) SignalCyan else Color(0xFFD7DEE2), shape)
            .toggleable(value = selected, role = Role.Checkbox, onValueChange = { onClick() })
            .semantics { contentDescription = "$title, $subtitle" }
            .testTag(tag)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        leading()
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.Bold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(if (selected) "✓" else "+", color = if (selected) SignalCyan else DeepInk, fontSize = 22.sp)
    }
}
