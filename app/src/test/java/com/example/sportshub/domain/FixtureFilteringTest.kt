package com.example.sportshub.domain

import com.example.sportshub.data.DemoSportsRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FixtureFilteringTest {
    private val fixtures = DemoSportsRepository.snapshot().fixtures

    @Test
    fun liveFilterOnlyIncludesLiveOrHalfTimeFixtures() {
        val result = fixtures.filterBy(FixtureFilter.LIVE)

        assertEquals(listOf("fixture-live-1"), result.map { it.id })
        assertTrue(result.all { it.state == FixtureState.LIVE || it.state == FixtureState.HALF_TIME })
    }

    @Test
    fun filtersPreserveProviderOrderAndIdentity() {
        val result = fixtures.filterBy(FixtureFilter.UPCOMING)

        assertEquals(listOf("fixture-upcoming-1", "fixture-cup-upcoming-1"), result.map { it.id })
    }
}

