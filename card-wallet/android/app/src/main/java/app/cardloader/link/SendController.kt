package app.cardloader.link

import app.cardloader.codec.Card
import app.cardloader.codec.Contract
import app.cardloader.codec.WatchAnswer

/** Runs something later on the main thread. */
interface Scheduler {
    fun postDelayed(delayMs: Long, action: () -> Unit)
    fun cancelAll()
}

/** The steps of one send, as they happen. */
data class SendProgress(
    val cardName: String,
    val id: Int,
    /** The message was accepted by Garmin Connect's service. */
    val handedOver: Boolean = false,
    /** Garmin Connect's report on the message; null while it is pending. */
    val delivery: Delivery? = null,
    /** The widget's answer to this message; null while it is pending. */
    val answer: WatchAnswer? = null,
    /** The 20 seconds passed without an answer. */
    val waitedLong: Boolean = false,
)

/**
 * Sends one card and follows it: handed to Garmin Connect, reached the watch, answered by the
 * widget. The answer is the only proof that the card was stored. The controller keeps listening
 * after the wait is over, until stop().
 */
class SendController(
    private val link: WatchLink,
    private val scheduler: Scheduler,
    private val onChange: (SendProgress?) -> Unit,
    private val newId: () -> Int = { Contract.newId() },
) {
    private var progress: SendProgress? = null

    fun start(card: Card, deviceId: Long) {
        stop()
        val id = newId()
        set(SendProgress(card.name, id))
        link.listen(deviceId) { payload ->
            val answer = WatchAnswer.parse(payload)
            if (answer != null && answer.id == id) update { it.copy(answer = answer) }
        }
        val handed = link.send(deviceId, card.toMessage(id)) { delivery -> update { it.copy(delivery = delivery) } }
        update { it.copy(handedOver = handed) }
        scheduler.postDelayed(WAIT_MS) { update { if (it.answer == null) it.copy(waitedLong = true) else it } }
    }

    fun openWidget(deviceId: Long, onResult: (OpenResult) -> Unit) = link.openWidget(deviceId, onResult)

    /** Stops listening and forgets the send. */
    fun stop() {
        scheduler.cancelAll()
        link.stopListening()
        set(null)
    }

    private fun set(value: SendProgress?) {
        progress = value
        onChange(value)
    }

    private fun update(change: (SendProgress) -> SendProgress) {
        val current = progress ?: return
        set(change(current))
    }

    companion object {
        const val WAIT_MS = 20_000L
    }
}
