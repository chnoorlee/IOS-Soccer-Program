package com.example.sportshub.data

import com.example.sportshub.domain.VideoSport
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DemoSportsRepositoryTest {
    @Test
    fun programMembershipIsExplicitUniqueAndNonPlayable() = runBlocking {
        val snapshot = DemoSportsRepository.getSnapshot().getOrThrow()
        val episodeIds = snapshot.programs.flatMap { program -> program.episodes.map { it.id } }

        assertEquals(4, snapshot.programs.size)
        assertEquals(episodeIds.size, episodeIds.toSet().size)
        assertTrue(snapshot.programs.all { it.episodes.isNotEmpty() })
        assertTrue(snapshot.programs.flatMap { it.episodes }.none { it.isPlayable })
        assertTrue(snapshot.programs.flatMap { it.episodes }.all { it.unavailableReason.english.isNotBlank() })
    }

    @Test
    fun catalogContainsAllDeclaredSportsWithoutProtectedMedia() = runBlocking {
        val snapshot = DemoSportsRepository.getSnapshot().getOrThrow()

        assertEquals(VideoSport.entries.toSet(), snapshot.programs.map { it.sport }.toSet())
        assertFalse(snapshot.articles.any { it.source.isBlank() })
    }
}

