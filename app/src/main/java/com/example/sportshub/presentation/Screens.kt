package com.example.sportshub.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.sportshub.domain.AppLanguage
import com.example.sportshub.domain.Article
import com.example.sportshub.domain.Fixture
import com.example.sportshub.domain.FixtureFilter
import com.example.sportshub.domain.SportsVideo
import com.example.sportshub.domain.VideoProgram
import com.example.sportshub.domain.VideoSport
import com.example.sportshub.ui.theme.Canvas
import com.example.sportshub.ui.theme.DeepInk
import com.example.sportshub.ui.theme.SignalCyan
import com.example.sportshub.ui.theme.TimingGold

@Composable
fun OnboardingScreen(state: AppUiState, onEvent: (AppEvent) -> Unit) {
    val snapshot = checkNotNull(state.snapshot)
    Scaffold(containerColor = Canvas) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).testTag("onboarding_screen"),
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            item {
                Text("SPORTSHUB", color = SignalCyan, fontWeight = FontWeight.Black, letterSpacing = 2.sp)
                Spacer(Modifier.height(12.dp))
                Text(
                    text(state.language, "رياضتك، في مكان واحد", "Your sport, in one place"),
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Black,
                )
                Text(
                    text(
                        state.language,
                        "اختر لغتك وفريقاً واحداً على الأقل. يمكنك تعديل اختياراتك لاحقاً.",
                        "Choose your language and at least one team. You can edit this later.",
                    ),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            item { LanguageSelector(state.language, onEvent) }
            item {
                SectionHeader(text(state.language, "اختر الفرق", "Choose teams"))
            }
            items(snapshot.teams, key = { it.id }) { team ->
                SelectionCard(
                    title = team.name.value(state.language),
                    subtitle = text(state.language, "فريق تجريبي خيالي", "Fictional demo team"),
                    selected = team.id in state.followedTeamIds,
                    tag = "onboarding_team_${team.id}",
                    onClick = { onEvent(AppEvent.ToggleTeam(team.id)) },
                    leading = { TeamBadge(team) },
                )
            }
            item {
                Button(
                    onClick = { onEvent(AppEvent.CompleteOnboarding) },
                    enabled = state.followedTeamIds.isNotEmpty(),
                    modifier = Modifier.fillMaxWidth().height(52.dp).testTag("onboarding_continue"),
                ) {
                    Text(text(state.language, "متابعة", "Continue"), fontWeight = FontWeight.Bold)
                }
                TextButton(
                    onClick = { onEvent(AppEvent.SkipOnboarding) },
                    modifier = Modifier.fillMaxWidth().height(48.dp).testTag("onboarding_skip"),
                ) {
                    Text(text(state.language, "التخطي الآن", "Skip for now"))
                }
            }
        }
    }
}

@Composable
private fun LanguageSelector(language: AppLanguage, onEvent: (AppEvent) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        FilterChip(
            selected = language == AppLanguage.ARABIC,
            onClick = { onEvent(AppEvent.SetLanguage(AppLanguage.ARABIC)) },
            label = { Text("العربية") },
            modifier = Modifier.weight(1f).height(48.dp).testTag("language_arabic"),
        )
        FilterChip(
            selected = language == AppLanguage.ENGLISH,
            onClick = { onEvent(AppEvent.SetLanguage(AppLanguage.ENGLISH)) },
            label = { Text("English") },
            modifier = Modifier.weight(1f).height(48.dp).testTag("language_english"),
        )
    }
}

@Composable
fun MainShell(state: AppUiState, onEvent: (AppEvent) -> Unit) {
    when (state.destination) {
        Destination.Main -> MainTabs(state, onEvent)
        is Destination.FixtureDetails -> FixtureDetailsScreen(state, state.destination.fixtureId, onEvent)
        Destination.Programs -> ProgramsScreen(state, onEvent)
        is Destination.ProgramDetails -> ProgramDetailsScreen(state, state.destination.programId, onEvent)
        is Destination.VideoDetails -> VideoDetailsScreen(state, state.destination.programId, state.destination.videoId, onEvent)
    }
}

@Composable
private fun MainTabs(state: AppUiState, onEvent: (AppEvent) -> Unit) {
    Scaffold(
        containerColor = Canvas,
        bottomBar = {
            NavigationBar(modifier = Modifier.navigationBarsPadding()) {
                AppTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = tab == state.selectedTab,
                        onClick = { onEvent(AppEvent.SelectTab(tab)) },
                        icon = { Text(tabSymbol(tab), fontWeight = FontWeight.Black) },
                        label = { Text(appTabLabel(tab, state.language), maxLines = 1) },
                        modifier = Modifier.testTag("tab_${tab.name.lowercase()}"),
                    )
                }
            }
        },
    ) { padding ->
        when (state.selectedTab) {
            AppTab.HOME -> HomeScreen(state, onEvent, padding)
            AppTab.MATCHES -> MatchesScreen(state, onEvent, padding)
            AppTab.EXPLORE -> ExploreScreen(state, onEvent, padding)
            AppTab.FOLLOWING -> FollowingScreen(state, onEvent, padding)
            AppTab.PROFILE -> ProfileScreen(state, onEvent, padding)
        }
    }
}

private fun tabSymbol(tab: AppTab): String = when (tab) {
    AppTab.HOME -> "⌂"
    AppTab.MATCHES -> "●"
    AppTab.EXPLORE -> "◇"
    AppTab.FOLLOWING -> "★"
    AppTab.PROFILE -> "◎"
}

@Composable
private fun HomeScreen(state: AppUiState, onEvent: (AppEvent) -> Unit, padding: PaddingValues) {
    val snapshot = checkNotNull(state.snapshot)
    val relevantFixture = snapshot.fixtures.firstOrNull { fixture ->
        fixture.homeTeam.id in state.followedTeamIds || fixture.awayTeam.id in state.followedTeamIds
    } ?: snapshot.fixtures.first()
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(padding).testTag("home_screen"),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item { AppHeader(state.language) }
        item { DemoDataBanner(state.language) }
        item {
            SectionHeader(text(state.language, "المباراة الأهم", "Your match"))
            Spacer(Modifier.height(10.dp))
            FixtureCard(relevantFixture, state.language, { onEvent(AppEvent.OpenFixture(relevantFixture.id)) })
        }
        item {
            SectionHeader(text(state.language, "آخر الأخبار", "Latest news"))
        }
        items(snapshot.articles, key = { it.id }) { article -> ArticleCard(article, state.language) }
        item { Spacer(Modifier.height(8.dp)) }
    }
}

@Composable
private fun AppHeader(language: AppLanguage) {
    Row(
        Modifier.fillMaxWidth().statusBarsPadding(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column {
            Text("SPORTSHUB", color = SignalCyan, fontWeight = FontWeight.Black, letterSpacing = 2.sp)
            Text(text(language, "صباح الرياضة", "A new day in sport"), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black)
        }
        Surface(color = DeepInk, shape = RoundedCornerShape(16.dp)) {
            Text("SH", modifier = Modifier.padding(12.dp), color = Color.White, fontWeight = FontWeight.Black)
        }
    }
}

@Composable
private fun ArticleCard(article: Article, language: AppLanguage) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Row(Modifier.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(
                Modifier.size(width = 92.dp, height = 104.dp)
                    .background(
                        Brush.linearGradient(listOf(DeepInk, SignalCyan)),
                        RoundedCornerShape(14.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) { Text("SH", color = Color.White, fontWeight = FontWeight.Black, fontSize = 22.sp) }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(article.category.value(language), color = SignalCyan, style = MaterialTheme.typography.labelLarge)
                Text(article.title.value(language), fontWeight = FontWeight.Bold, maxLines = 3, overflow = TextOverflow.Ellipsis)
                Text(article.summary.value(language), style = MaterialTheme.typography.bodySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(
                    "${article.source} · ${article.minutesAgo} ${text(language, "د", "min")}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun MatchesScreen(state: AppUiState, onEvent: (AppEvent) -> Unit, padding: PaddingValues) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(padding).testTag("matches_screen"),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            ScreenTitle(state.language, "المباريات", "Matches")
            DemoDataBanner(state.language, Modifier.padding(top = 12.dp))
        }
        item {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FixtureFilter.entries.forEach { filter ->
                    FilterChip(
                        selected = state.fixtureFilter == filter,
                        onClick = { onEvent(AppEvent.SetFixtureFilter(filter)) },
                        label = { Text(filter.label(state.language)) },
                        modifier = Modifier.testTag("fixture_filter_${filter.name.lowercase()}"),
                    )
                }
            }
        }
        if (state.filteredFixtures.isEmpty()) {
            item { EmptyCard(text(state.language, "لا توجد مباريات ضمن هذا النطاق", "No matches in this filter")) }
        } else {
            items(state.filteredFixtures, key = { it.id }) { fixture ->
                FixtureCard(fixture, state.language, { onEvent(AppEvent.OpenFixture(fixture.id)) })
            }
        }
    }
}

@Composable
private fun ExploreScreen(state: AppUiState, onEvent: (AppEvent) -> Unit, padding: PaddingValues) {
    val snapshot = checkNotNull(state.snapshot)
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(padding).testTag("explore_screen"),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item { ScreenTitle(state.language, "اكتشف", "Explore") }
        item {
            Surface(color = Color.White, shape = RoundedCornerShape(18.dp), shadowElevation = 1.dp) {
                Text(
                    "⌕  ${text(state.language, "ابحث عن فريق أو خبر أو فيديو", "Search teams, news and video")}",
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        item {
            Card(
                onClick = { onEvent(AppEvent.OpenPrograms) },
                modifier = Modifier.fillMaxWidth().testTag("explore_programs"),
                colors = CardDefaults.cardColors(containerColor = DeepInk),
            ) {
                Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(text(state.language, "البرامج الأصلية", "Original programs"), color = TimingGold, fontWeight = FontWeight.Bold)
                    Text(text(state.language, "مكتبة البرامج والحلقات", "Programs & episodes"), color = Color.White, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black)
                    Text(
                        text(state.language, "${snapshot.programs.size} برامج خيالية · علاقات حلقات صريحة", "${snapshot.programs.size} fictional programs · explicit episode links"),
                        color = Color.White.copy(alpha = .8f),
                    )
                    Text(text(state.language, "فتح المكتبة ←", "Open library →"), color = SignalCyan, fontWeight = FontWeight.Bold)
                }
            }
        }
        item {
            SectionHeader(text(state.language, "مسارات الاستكشاف", "Explore lanes"))
            Spacer(Modifier.height(10.dp))
            ExploreLane("◫", text(state.language, "مركز الانتقالات", "Transfer center"), text(state.language, "نموذج عرض فقط", "Presentation preview"))
            Spacer(Modifier.height(10.dp))
            ExploreLane("▦", text(state.language, "تقويم الموسم", "Season calendar"), text(state.language, "محطات الموسم المهمة", "Key season milestones"))
        }
    }
}

@Composable
private fun ExploreLane(symbol: String, title: String, subtitle: String) {
    Surface(color = Color.White, shape = RoundedCornerShape(18.dp)) {
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(symbol, fontSize = 28.sp, color = SignalCyan)
            Spacer(Modifier.width(14.dp))
            Column { Text(title, fontWeight = FontWeight.Bold); Text(subtitle, style = MaterialTheme.typography.bodySmall) }
        }
    }
}

@Composable
private fun FollowingScreen(state: AppUiState, onEvent: (AppEvent) -> Unit, padding: PaddingValues) {
    val snapshot = checkNotNull(state.snapshot)
    val followed = snapshot.teams.filter { it.id in state.followedTeamIds }
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(padding).testTag("following_screen"),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item { ScreenTitle(state.language, "متابعاتي", "Following") }
        if (followed.isEmpty()) {
            item { EmptyCard(text(state.language, "لا تتابع أي فريق بعد. عد إلى حسابي لتعديل اهتماماتك.", "You are not following a team yet. Edit interests from Profile.")) }
        } else {
            item { SectionHeader(text(state.language, "الفرق", "Teams")) }
            items(followed, key = { it.id }) { team ->
                SelectionCard(
                    team.name.value(state.language),
                    text(state.language, "متابَع · اضغط للإلغاء", "Following · tap to remove"),
                    true,
                    "following_team_${team.id}",
                    { onEvent(AppEvent.ToggleTeam(team.id)) },
                    { TeamBadge(team) },
                )
                val fixture = snapshot.fixtures.firstOrNull { it.homeTeam.id == team.id || it.awayTeam.id == team.id }
                if (fixture != null) {
                    Spacer(Modifier.height(8.dp))
                    FixtureCard(fixture, state.language, { onEvent(AppEvent.OpenFixture(fixture.id)) })
                }
            }
        }
    }
}

@Composable
private fun ProfileScreen(state: AppUiState, onEvent: (AppEvent) -> Unit, padding: PaddingValues) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(padding).testTag("profile_screen"),
        contentPadding = PaddingValues(horizontal = 18.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item { ScreenTitle(state.language, "حسابي", "Profile") }
        item {
            ProfileHero(state.language)
        }
        item {
            SectionHeader(text(state.language, "اللغة", "Language"))
            Spacer(Modifier.height(8.dp))
            LanguageSelector(state.language, onEvent)
        }
        item {
            SettingsCard(
                title = text(state.language, "تعديل الاهتمامات", "Edit interests"),
                detail = text(state.language, "الفرق التي تتابعها", "Teams you follow"),
                onClick = { onEvent(AppEvent.EditInterests) },
                tag = "edit_interests",
            )
            Spacer(Modifier.height(10.dp))
            SettingsCard(
                title = text(state.language, "الخصوصية وبيانات الجهاز", "Privacy & device data"),
                detail = text(state.language, "لا توجد بيانات حساب أو وسائط حقيقية", "No account data or real media is stored"),
            )
            Spacer(Modifier.height(10.dp))
            SettingsCard(
                title = text(state.language, "حول نسخة Android", "About the Android build"),
                detail = "1.0 · Jetpack Compose · API 36",
            )
        }
        item { DemoDataBanner(state.language) }
    }
}

@Composable
private fun ProfileHero(language: AppLanguage) {
    Surface(color = DeepInk, shape = RoundedCornerShape(22.dp)) {
        Row(Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
            Surface(color = SignalCyan, shape = RoundedCornerShape(18.dp)) {
                Text("SH", modifier = Modifier.padding(16.dp), color = Color.White, fontWeight = FontWeight.Black)
            }
            Spacer(Modifier.width(14.dp))
            Column {
                Text(text(language, "ضيف سبورتس هب", "SportsHub guest"), color = Color.White, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleLarge)
                Text(text(language, "الحالة المحلية فقط", "Local-only profile"), color = Color.White.copy(alpha = .7f))
            }
        }
    }
}

@Composable
private fun SettingsCard(title: String, detail: String, onClick: (() -> Unit)? = null, tag: String = title) {
    Card(
        onClick = onClick ?: {},
        enabled = onClick != null,
        modifier = Modifier.fillMaxWidth().testTag(tag),
        colors = CardDefaults.cardColors(
            containerColor = Color.White,
            disabledContainerColor = Color.White,
            disabledContentColor = DeepInk,
        ),
    ) {
        Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) { Text(title, fontWeight = FontWeight.Bold); Text(detail, style = MaterialTheme.typography.bodySmall) }
            Text("›", fontSize = 26.sp, color = SignalCyan)
        }
    }
}

@Composable
private fun FixtureDetailsScreen(state: AppUiState, fixtureId: String, onEvent: (AppEvent) -> Unit) {
    val snapshot = checkNotNull(state.snapshot)
    val fixture = snapshot.fixtures.first { it.id == fixtureId }
    val events = snapshot.eventsByFixture[fixtureId].orEmpty()
    val stats = snapshot.statsByFixture[fixtureId].orEmpty()
    var detailTab by rememberSaveable(fixtureId) { mutableIntStateOf(0) }
    Scaffold(
        containerColor = Canvas,
        topBar = { DetailTopBar(text(state.language, "مركز المباراة", "Match center"), onEvent) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).testTag("fixture_detail_screen"),
            contentPadding = PaddingValues(18.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item { DemoDataBanner(state.language) }
            item { FixtureCard(fixture, state.language, {}) }
            item {
                Surface(color = Color.White, shape = RoundedCornerShape(18.dp)) {
                    Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(text(state.language, "تذكير محلي", "Local reminder"), fontWeight = FontWeight.Bold)
                            Text(text(state.language, "تجريبي ولا يطلب إذن الإشعارات", "Demo only; no notification permission is requested"), style = MaterialTheme.typography.bodySmall)
                        }
                        Switch(
                            checked = fixtureId in state.reminderFixtureIds,
                            onCheckedChange = { onEvent(AppEvent.ToggleReminder(fixtureId)) },
                            modifier = Modifier.testTag("fixture_reminder"),
                        )
                    }
                }
            }
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(text(state.language, "الملخص", "Summary"), text(state.language, "الأحداث", "Events"), text(state.language, "الإحصائيات", "Stats")).forEachIndexed { index, label ->
                        FilterChip(selected = detailTab == index, onClick = { detailTab = index }, label = { Text(label) }, modifier = Modifier.weight(1f))
                    }
                }
            }
            when (detailTab) {
                0 -> item {
                    InfoCard(text(state.language, "الملعب", "Venue"), fixture.venue.value(state.language))
                    Spacer(Modifier.height(10.dp))
                    InfoCard(text(state.language, "الحالة", "Status"), fixture.state.label(state.language))
                }
                1 -> if (events.isEmpty()) {
                    item { EmptyCard(text(state.language, "لا توجد أحداث منشورة", "No published events")) }
                } else {
                    items(events, key = { it.id }) { event ->
                        Surface(color = Color.White, shape = RoundedCornerShape(16.dp)) {
                            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.Top) {
                                Text("${event.minute}′", color = SignalCyan, fontWeight = FontWeight.Black, modifier = Modifier.width(48.dp))
                                Column { Text(event.title.value(state.language), fontWeight = FontWeight.Bold); Text(event.detail.value(state.language)) }
                            }
                        }
                    }
                }
                else -> items(stats) { stat ->
                    Surface(color = Color.White, shape = RoundedCornerShape(14.dp)) {
                        Row(Modifier.fillMaxWidth().padding(14.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(stat.homeValue, fontWeight = FontWeight.Black)
                            Text(stat.label.value(state.language), color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(stat.awayValue, fontWeight = FontWeight.Black)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProgramsScreen(state: AppUiState, onEvent: (AppEvent) -> Unit) {
    val programs = checkNotNull(state.snapshot).programs.filter { state.programSport == null || it.sport == state.programSport }
    Scaffold(
        containerColor = Canvas,
        topBar = { DetailTopBar(text(state.language, "مكتبة البرامج", "Program library"), onEvent) },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 18.dp)) {
            DemoDataBanner(state.language, Modifier.padding(top = 12.dp))
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                FilterChip(selected = state.programSport == null, onClick = { onEvent(AppEvent.SetProgramSport(null)) }, label = { Text(text(state.language, "الكل", "All")) })
                VideoSport.entries.forEach { sport ->
                    FilterChip(selected = state.programSport == sport, onClick = { onEvent(AppEvent.SetProgramSport(sport)) }, label = { Text(sport.label(state.language)) })
                }
            }
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val oneColumn = maxWidth < 600.dp || LocalDensity.current.fontScale > 1.3f
                LazyVerticalGrid(
                    columns = GridCells.Fixed(if (oneColumn) 1 else 2),
                    contentPadding = PaddingValues(bottom = 24.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    gridItems(programs, key = { it.id }) { program ->
                        ProgramCard(program, state.language) { onEvent(AppEvent.OpenProgram(program.id)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProgramCard(program: VideoProgram, language: AppLanguage, onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().testTag("program_${program.id}"),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Row(Modifier.height(188.dp)) {
            Box(Modifier.width(7.dp).fillMaxHeight().background(SignalCyan))
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(program.sport.label(language), color = SignalCyan, style = MaterialTheme.typography.labelLarge)
                Text(program.title.value(language), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black)
                Text(program.description.value(language), style = MaterialTheme.typography.bodyMedium, maxLines = 4, overflow = TextOverflow.Ellipsis)
                Text(text(language, "${program.episodes.size} حلقات", "${program.episodes.size} episodes"), color = TimingGold, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun ProgramDetailsScreen(state: AppUiState, programId: String, onEvent: (AppEvent) -> Unit) {
    val program = checkNotNull(state.snapshot).programs.first { it.id == programId }
    Scaffold(
        containerColor = Canvas,
        topBar = { DetailTopBar(program.title.value(state.language), onEvent) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).testTag("program_detail_screen"),
            contentPadding = PaddingValues(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Surface(color = DeepInk, shape = RoundedCornerShape(24.dp)) {
                    Column(Modifier.fillMaxWidth().padding(22.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(program.sport.label(state.language), color = TimingGold, fontWeight = FontWeight.Bold)
                        Text(program.title.value(state.language), color = Color.White, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black)
                        Text(program.description.value(state.language), color = Color.White.copy(alpha = .82f))
                    }
                }
            }
            item { SectionHeader(text(state.language, "الحلقات", "Episodes")) }
            items(program.episodes, key = { it.id }) { video ->
                VideoCard(video, state.language) { onEvent(AppEvent.OpenVideo(program.id, video.id)) }
            }
        }
    }
}

@Composable
private fun VideoCard(video: SportsVideo, language: AppLanguage, onClick: () -> Unit) {
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth().testTag("video_${video.id}")) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(width = 92.dp, height = 74.dp).background(Brush.linearGradient(listOf(DeepInk, SignalCyan)), RoundedCornerShape(12.dp)),
                contentAlignment = Alignment.Center,
            ) { Text("▶", color = Color.White, fontSize = 22.sp) }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(video.type.label(language), color = SignalCyan, style = MaterialTheme.typography.labelLarge)
                Text(video.title.value(language), fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(if (video.durationMinutes == 0) "—" else "${video.durationMinutes} min", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun VideoDetailsScreen(state: AppUiState, programId: String, videoId: String, onEvent: (AppEvent) -> Unit) {
    val program = checkNotNull(state.snapshot).programs.first { it.id == programId }
    val video = program.episodes.first { it.id == videoId }
    Scaffold(
        containerColor = Canvas,
        topBar = { DetailTopBar(text(state.language, "تفاصيل الفيديو", "Video details"), onEvent) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).testTag("video_detail_screen"),
            contentPadding = PaddingValues(18.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                Box(
                    Modifier.fillMaxWidth().height(220.dp).background(Brush.linearGradient(listOf(DeepInk, SignalCyan)), RoundedCornerShape(24.dp)),
                    contentAlignment = Alignment.Center,
                ) { Text("SPORTSHUB\nDEMO", color = Color.White, fontWeight = FontWeight.Black, fontSize = 28.sp) }
            }
            item {
                Text(video.type.label(state.language), color = SignalCyan, fontWeight = FontWeight.Bold)
                Text(video.title.value(state.language), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black)
                Text(video.description.value(state.language), style = MaterialTheme.typography.bodyLarge)
            }
            item {
                Surface(color = TimingGold.copy(alpha = .18f), shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.fillMaxWidth().padding(16.dp)) {
                        Text(text(state.language, "غير قابل للتشغيل", "Playback unavailable"), fontWeight = FontWeight.Black)
                        Text(video.unavailableReason.value(state.language))
                        Spacer(Modifier.height(6.dp))
                        Text(text(state.language, "وجود الحلقة لا يمنح حقوق البث.", "Program membership does not grant playback rights."), style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            item { InfoCard(text(state.language, "البرنامج", "Program"), program.title.value(state.language)) }
        }
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun DetailTopBar(title: String, onEvent: (AppEvent) -> Unit) {
    TopAppBar(
        title = { Text(title, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        navigationIcon = {
            TextButton(onClick = { onEvent(AppEvent.Back) }, modifier = Modifier.testTag("navigate_back")) { Text("‹", fontSize = 30.sp) }
        },
        colors = TopAppBarDefaults.topAppBarColors(containerColor = Canvas),
    )
}

@Composable
private fun ScreenTitle(language: AppLanguage, arabic: String, english: String) {
    Column(Modifier.statusBarsPadding()) {
        Text("SPORTSHUB", color = SignalCyan, fontWeight = FontWeight.Black, letterSpacing = 2.sp)
        Text(text(language, arabic, english), style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun EmptyCard(message: String) {
    Surface(color = Color.White, shape = RoundedCornerShape(18.dp)) {
        Text(message, modifier = Modifier.fillMaxWidth().padding(24.dp), style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun InfoCard(title: String, value: String) {
    Surface(color = Color.White, shape = RoundedCornerShape(16.dp)) {
        Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(title, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, fontWeight = FontWeight.Bold)
        }
    }
}
