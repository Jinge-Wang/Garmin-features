package app.cardloader.ui

import app.cardloader.link.DeviceState
import app.cardloader.link.WatchDevice
import app.cardloader.link.WatchState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TextsTest {
    @Test
    fun homeStates() {
        assertEquals("Garmin Connect is not installed", Texts.watchStatus(WatchState.GarminConnectMissing).title)
        assertEquals("No watch is paired", Texts.watchStatus(WatchState.Ready(emptyList(), null)).title)
        val d = WatchDevice(1, "fenix 6X Pro", DeviceState.NOT_CONNECTED)
        assertEquals("fenix 6X Pro is not connected", Texts.watchStatus(WatchState.Ready(listOf(d), 1)).title)
        val c = d.copy(state = DeviceState.CONNECTED)
        assertEquals("fenix 6X Pro is connected", Texts.watchStatus(WatchState.Ready(listOf(c), 1)).title)
        assertTrue(Texts.canSend(WatchState.Ready(listOf(c), 1)))
        assertFalse(Texts.canSend(WatchState.GarminConnectMissing))
    }

    @Test
    fun qrWarningThresholds() {
        // 197 / (n + 2): n = 61 -> 3 px (no warning); n = 65 -> 2 px (warning).
        assertNull(Texts.qrWarning(61))
        assertNotNull(Texts.qrWarning(65))
    }

    @Test
    fun barNoteOnlyForOtherSymbologies() {
        assertNull(Texts.barNote(true))
        assertTrue(Texts.barNote(false)!!.contains("Code 128"))
    }
}
