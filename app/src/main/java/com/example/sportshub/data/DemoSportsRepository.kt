package com.example.sportshub.data

import com.example.sportshub.domain.Article
import com.example.sportshub.domain.BilingualText
import com.example.sportshub.domain.Competition
import com.example.sportshub.domain.Fixture
import com.example.sportshub.domain.FixtureState
import com.example.sportshub.domain.MatchEvent
import com.example.sportshub.domain.MatchStat
import com.example.sportshub.domain.SportsRepository
import com.example.sportshub.domain.SportsSnapshot
import com.example.sportshub.domain.SportsVideo
import com.example.sportshub.domain.Team
import com.example.sportshub.domain.VideoProgram
import com.example.sportshub.domain.VideoSport
import com.example.sportshub.domain.VideoType
import java.time.Instant
import java.time.temporal.ChronoUnit

object DemoSportsRepository : SportsRepository {
    private val teams = listOf(
        Team("riyadh-falcons", BilingualText("صقور الرياض", "Riyadh Falcons"), "RF", 0xFF0B7A75),
        Team("jeddah-waves", BilingualText("أمواج جدة", "Jeddah Waves"), "JW", 0xFF1C5D99),
        Team("desert-stars", BilingualText("نجوم الصحراء", "Desert Stars"), "DS", 0xFFB7791F),
        Team("coast-united", BilingualText("اتحاد الساحل", "Coast United"), "CU", 0xFF8B3A62),
    )
    private val league = Competition("demo-league", BilingualText("الدوري التجريبي", "Demo League"))
    private val cup = Competition("demo-cup", BilingualText("كأس سبورتس هب", "SportsHub Cup"))

    override suspend fun getSnapshot(): Result<SportsSnapshot> = Result.success(snapshot())

    fun snapshot(now: Instant = Instant.now()): SportsSnapshot {
        val fixtures = listOf(
            Fixture(
                "fixture-live-1", league, teams[0], teams[1], now.minus(62, ChronoUnit.MINUTES),
                FixtureState.LIVE, 62, 1, 0, BilingualText("ملعب المدينة", "City Arena"),
            ),
            Fixture(
                "fixture-upcoming-1", league, teams[2], teams[3], now.plus(2, ChronoUnit.HOURS),
                FixtureState.UPCOMING, venue = BilingualText("ملعب الساحل", "Coast Stadium"),
            ),
            Fixture(
                "fixture-finished-1", league, teams[3], teams[0], now.minus(5, ChronoUnit.HOURS),
                FixtureState.FINISHED, 90, 2, 2, BilingualText("ملعب العاصمة", "Capital Ground"),
            ),
            Fixture(
                "fixture-cup-upcoming-1", cup, teams[1], teams[2], now.plus(4, ChronoUnit.HOURS),
                FixtureState.UPCOMING, venue = BilingualText("ملعب الكأس التجريبي", "Demo Cup Stadium"),
            ),
        )

        val matchDeskVideos = listOf(
            SportsVideo(
                "video-live-1", BilingualText("استوديو مباشر تجريبي", "Demo live studio"),
                BilingualText("بيانات وصفية فقط من دون بث مرخص.", "Metadata only; no licensed stream."),
                VideoType.LIVE, 0, false,
                BilingualText("البث غير متاح في النسخة التجريبية", "Streaming is unavailable in the demo"),
            ),
            SportsVideo(
                "video-highlight-1", BilingualText("ملخص الجولة التجريبي", "Demo round highlights"),
                BilingualText("ملخص خيالي بلا لقطات محمية.", "A fictional recap with no protected footage."),
                VideoType.HIGHLIGHT, 8, false,
                BilingualText("لا توجد حقوق تشغيل", "No playback rights are attached"),
            ),
            SportsVideo(
                "video-replay-1", BilingualText("إعادة المباراة التجريبية", "Demo match replay"),
                BilingualText("عنصر اختبار للعلاقة بين البرنامج والحلقة.", "A test item for the program-to-episode relationship."),
                VideoType.REPLAY, 94, false,
                BilingualText("لا توجد حقوق تشغيل", "No playback rights are attached"),
            ),
        )
        val tacticsVideo = SportsVideo(
            "video-original-1", BilingualText("قراءة المساحات", "Reading the spaces"),
            BilingualText("شرح تكتيكي خيالي وأصلي.", "An original, fictional tactical explainer."),
            VideoType.ORIGINAL, 12, false,
            BilingualText("فيديو توضيحي غير قابل للتشغيل", "The demo video cannot be played"),
        )
        val basketballVideo = SportsVideo(
            "video-basketball-1", BilingualText("مراجعة ليلة السلة", "Basketball night review"),
            BilingualText("حلقة سلة خيالية للعرض فقط.", "A fictional basketball episode for presentation only."),
            VideoType.ORIGINAL, 16, false,
            BilingualText("لا توجد وسائط مرخصة", "No licensed media is attached"),
        )
        val esportsVideo = SportsVideo(
            "video-esports-1", BilingualText("مختبر الأداء الرقمي", "Digital performance lab"),
            BilingualText("حلقة خيالية بلا لعبة أو علامة محمية.", "A fictional episode with no protected game or brand."),
            VideoType.INTERVIEW, 20, false,
            BilingualText("لا توجد وسائط مرخصة", "No licensed media is attached"),
        )

        return SportsSnapshot(
            teams = teams,
            fixtures = fixtures,
            articles = listOf(
                Article(
                    "article-1",
                    BilingualText("صقور الرياض يستعدون لاختبار جديد", "Riyadh Falcons prepare for a new test"),
                    BilingualText("تقرير خيالي يوضح شكل بطاقة الخبر من دون صور أو نصوص محمية.", "A fictional report demonstrating the news card without protected imagery or copy."),
                    "SportsHub Demo Desk", BilingualText("تحليل", "Analysis"), 42,
                ),
                Article(
                    "article-2",
                    BilingualText("خمسة أرقام قبل مباريات الليلة", "Five numbers before tonight's matches"),
                    BilingualText("بيانات محلية خيالية لاختبار القراءة.", "Fictional local data for testing the reading experience."),
                    "SportsHub Demo Desk", BilingualText("أرقام", "Numbers"), 95, corrected = true,
                ),
            ),
            programs = listOf(
                VideoProgram(
                    "program-tactics-studio", BilingualText("الاستوديو التكتيكي", "Tactics Studio"),
                    BilingualText("برنامج تحليلي خيالي دون فرق أو مسابقات حقيقية.", "A fictional analysis show without real teams or competitions."),
                    VideoSport.FOOTBALL, listOf(tacticsVideo),
                ),
                VideoProgram(
                    "program-match-desk", BilingualText("استوديو المباراة", "Match Desk"),
                    BilingualText("رف تجريبي يجمع الاستوديو والملخص والإعادة من دون بث مرخص.", "A demo shelf linking studio, highlights and replay metadata without licensed media."),
                    VideoSport.FOOTBALL, matchDeskVideos,
                ),
                VideoProgram(
                    "program-court-review", BilingualText("مراجعة الملعب", "Court Review"),
                    BilingualText("برنامج سلة خيالي لا يشير إلى دوري أو نادٍ حقيقي.", "A fictional basketball program tied to no real league or club."),
                    VideoSport.BASKETBALL, listOf(basketballVideo),
                ),
                VideoProgram(
                    "program-esports-lab", BilingualText("مختبر الرياضات الإلكترونية", "Esports Lab"),
                    BilingualText("برنامج خيالي بلا لعبة أو علامة تجارية أو بث محمي.", "A fictional esports show with no protected game, brand or broadcast."),
                    VideoSport.ESPORTS, listOf(esportsVideo),
                ),
            ),
            eventsByFixture = mapOf(
                "fixture-live-1" to listOf(
                    MatchEvent("event-kickoff", 0, BilingualText("انطلاق المباراة", "Kick-off"), BilingualText("بدأت المباراة", "The match started")),
                    MatchEvent("event-goal", 37, BilingualText("هدف", "Goal"), BilingualText("صقور الرياض · هدف تجريبي", "Riyadh Falcons · demo goal")),
                    MatchEvent("event-yellow", 54, BilingualText("بطاقة صفراء", "Yellow card"), BilingualText("أمواج جدة", "Jeddah Waves")),
                ),
            ),
            statsByFixture = fixtures.associate { fixture ->
                fixture.id to listOf(
                    MatchStat(BilingualText("الاستحواذ", "Possession"), "54%", "46%"),
                    MatchStat(BilingualText("التسديدات", "Shots"), "9", "7"),
                    MatchStat(BilingualText("الركنيات", "Corners"), "5", "3"),
                )
            },
        )
    }
}

