package app.cardloader.link

import app.cardloader.codec.BarCard
import app.cardloader.codec.Contract
import app.cardloader.ui.Texts
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SendControllerTest {
    private class FakeLink : WatchLink {
        override val state: StateFlow<WatchState> = MutableStateFlow(WatchState.Starting)
        var listener: ((List<Any?>) -> Unit)? = null
        var delivery: ((Delivery) -> Unit)? = null
        var sent: Map<String, Any>? = null
        var stopped = 0
        var handOver = true
        override fun start() = Unit
        override fun refresh() = Unit
        override fun select(deviceId: Long) = Unit
        override fun listen(deviceId: Long, onPayload: (List<Any?>) -> Unit) { listener = onPayload }
        override fun stopListening() { stopped++; listener = null }
        override fun send(deviceId: Long, message: Map<String, Any>, onDelivery: (Delivery) -> Unit): Boolean {
            sent = message
            delivery = onDelivery
            return handOver
        }
        override fun openWidget(deviceId: Long, onResult: (OpenResult) -> Unit) = onResult(OpenResult.PROMPT_SHOWN)
        override fun shutdown() = Unit
    }

    private class FakeScheduler : Scheduler {
        var action: (() -> Unit)? = null
        var delay = 0L
        override fun postDelayed(delayMs: Long, action: () -> Unit) { this.action = action; delay = delayMs }
        override fun cancelAll() { action = null }
    }

    private val link = FakeLink()
    private val scheduler = FakeScheduler()
    private var last: SendProgress? = null
    private val controller = SendController(link, scheduler, { last = it }, newId = { 4242 })
    private val card = BarCard("Warehouse", "SAMPLE-CARD-0000")

    @Test
    fun theMessageCarriesTheContractsIdAndValidates() {
        controller.start(card, 1L)
        assertEquals(4242, link.sent!!["id"])
        assertEquals("", Contract.validate(link.sent))
        assertEquals(20_000L, scheduler.delay)
    }

    @Test
    fun storedPath() {
        controller.start(card, 1L)
        link.delivery!!(Delivery.SUCCESS)
        link.listener!!(listOf(mapOf("id" to 4242, "ok" to true, "why" to "")))
        val lines = Texts.resultLines(last!!)
        assertEquals(
            listOf("Handed to Garmin Connect", "Reached the watch", "Stored on the watch as Warehouse"),
            lines.map { it.text },
        )
        assertTrue(lines.all { it.mark == Texts.Mark.DONE })
    }

    @Test
    fun anAnswerForAnotherIdIsIgnored() {
        controller.start(card, 1L)
        link.listener!!(listOf(mapOf("id" to 99, "ok" to true, "why" to "")))
        assertNull(last!!.answer)
    }

    @Test
    fun refusedPathNamesTheReason() {
        controller.start(card, 1L)
        link.delivery!!(Delivery.SUCCESS)
        link.listener!!(listOf(mapOf("id" to 4242, "ok" to false, "why" to "shape")))
        val text = Texts.resultLines(last!!).last()
        assertEquals(Texts.Mark.FAILED, text.mark)
        assertTrue(text.text.startsWith("The widget refused it: "))
        assertTrue(text.text.contains("position squares"))
    }

    @Test
    fun noAnswerWithinTwentySecondsStillListens() {
        controller.start(card, 1L)
        link.delivery!!(Delivery.SUCCESS)
        scheduler.action!!()
        assertTrue(last!!.waitedLong)
        assertTrue(Texts.resultLines(last!!).last().text.contains("widget list, CARDS, START"))
        assertTrue("still listening", link.listener != null)
        link.listener!!(listOf(mapOf("id" to 4242, "ok" to true, "why" to "")))
        assertEquals("Stored on the watch as Warehouse", Texts.resultLines(last!!).last().text)
    }

    @Test
    fun deliveryFailureIsShownInPlainWords() {
        controller.start(card, 1L)
        link.delivery!!(Delivery.NOT_CONNECTED)
        val lines = Texts.resultLines(last!!)
        assertEquals("Did not reach the watch: it is not connected", lines[1].text)
        assertEquals(Texts.Mark.FAILED, lines[1].mark)
    }

    @Test
    fun aMessageThatCouldNotBeHandedOver() {
        link.handOver = false
        controller.start(card, 1L)
        link.delivery!!(Delivery.LINK_ERROR)
        assertFalse(last!!.handedOver)
        assertEquals("Not handed to Garmin Connect", Texts.resultLines(last!!)[0].text)
    }

    @Test
    fun stopForgetsTheSendAndStopsListening() {
        controller.start(card, 1L)
        controller.stop()
        assertNull(last)
        assertNull(link.listener)
        assertNull(scheduler.action)
    }
}
