package app.cardloader.ui

import app.cardloader.codec.BarContent
import app.cardloader.codec.Contract
import app.cardloader.codec.ReadOutcome
import app.cardloader.link.DeviceState
import app.cardloader.link.Delivery
import app.cardloader.link.OpenResult
import app.cardloader.link.SendProgress
import app.cardloader.link.WatchState

/** The interface text that depends on state. Plain statements, no Android types. */
object Texts {
    class Status(val title: String, val detail: String?)

    fun watchStatus(state: WatchState): Status = when (state) {
        WatchState.Starting -> Status("Looking for Garmin Connect", null)
        WatchState.GarminConnectMissing ->
            Status("Garmin Connect is not installed", "Install Garmin Connect on this phone and pair the watch in it. Then open this app again.")
        WatchState.GarminConnectTooOld ->
            Status("Garmin Connect needs an update", "Update Garmin Connect on this phone, then open this app again.")
        WatchState.ServiceError ->
            Status("Garmin Connect did not answer", "Open Garmin Connect once, then come back to this app.")
        is WatchState.Ready -> {
            val watch = state.selected
            when {
                state.devices.isEmpty() -> Status("No watch is paired", "Pair the watch in Garmin Connect, then come back to this app.")
                watch == null -> Status("Choose a watch", null)
                watch.state == DeviceState.CONNECTED -> Status("${watch.name} is connected", null)
                watch.state == DeviceState.NOT_PAIRED -> Status("${watch.name} is not paired", "Pair the watch in Garmin Connect.")
                watch.state == DeviceState.NOT_CONNECTED ->
                    Status("${watch.name} is not connected", "Check that Bluetooth is on and the watch is near the phone.")
                else -> Status("${watch.name}: connection unknown", "Garmin Connect has not reported the state of the watch.")
            }
        }
    }

    /** True when a card can be handed to Garmin Connect for the selected watch. */
    fun canSend(state: WatchState): Boolean = state is WatchState.Ready && state.selected != null

    /** What to tell the user about a picture or a frame that did not give a usable code; null for a usable one. */
    fun notice(outcome: ReadOutcome): String? = when (outcome) {
        is ReadOutcome.Qr, is ReadOutcome.Bar -> null
        ReadOutcome.NotFound -> "No QR code or bar code was found. Try a sharper picture with the code fully in view."
        ReadOutcome.MultipleQr -> "The picture has more than one QR code. Crop it to the code you want and pick it again."
        is ReadOutcome.OtherCode -> "This is a ${outcome.name} code. The watch app shows QR codes and Code 128 bar codes only."
        is ReadOutcome.Refused -> outcome.message
    }

    fun qrSummary(n: Int): String {
        val version = (n - 17) / 4
        return "QR code, version $version, $n x $n modules"
    }

    fun qrOnWatch(n: Int): String = "On the watch each module is ${Contract.qrPixelsPerModule(n)} px wide."

    fun qrWarning(n: Int): String? =
        if (Contract.qrPixelsPerModule(n) < 3) "Modules under 3 px wide may not scan well from the watch screen." else null

    fun barSummary(content: String, symbology: String): String =
        "Bar code, ${content.length} characters, read as $symbology"

    fun barNote(isCode128: Boolean): String? =
        if (isCode128) null else "The watch will show the same content as a Code 128 bar code, which most scanners read. Test it at the scanner."

    fun barOnWatch(content: String): String = "On the watch each bar module is ${BarContent.barPixels(content, Contract.SCREEN)} px wide."

    fun delivery(d: Delivery): String = when (d) {
        Delivery.SUCCESS -> "Reached the watch"
        Delivery.NOT_CONNECTED -> "Did not reach the watch: it is not connected"
        Delivery.TOO_LARGE -> "Did not reach the watch: the message is too large"
        Delivery.INVALID_DEVICE -> "Did not reach the watch: Garmin Connect does not know this watch"
        Delivery.TRANSFER_FAILED -> "Did not reach the watch: the transfer failed"
        Delivery.INVALID_FORMAT, Delivery.UNSUPPORTED_TYPE -> "Did not reach the watch: Garmin Connect refused the message format"
        Delivery.LINK_ERROR -> "Did not reach the watch: Garmin Connect could not be reached"
        Delivery.UNKNOWN_FAILURE -> "Did not reach the watch: unknown error"
    }

    fun openResult(r: OpenResult): String = when (r) {
        OpenResult.PROMPT_SHOWN -> "The watch shows a prompt. Accept it to open the widget."
        OpenResult.PROMPT_NOT_SHOWN -> "The watch did not show a prompt. Open the widget on the watch: widget list, CARDS, START."
        OpenResult.NOT_INSTALLED -> "Garmin Connect reports that the widget is not installed. It may still receive cards if it is on the watch."
        OpenResult.ALREADY_RUNNING -> "The widget is already open on the watch."
        OpenResult.UNKNOWN_FAILURE, OpenResult.LINK_ERROR -> "The request to open the widget failed. Open it on the watch: widget list, CARDS, START."
    }

    enum class Mark { DONE, WAITING, FAILED }

    class Line(val mark: Mark, val text: String)

    /** The four steps of a send as lines, in order. */
    fun resultLines(p: SendProgress): List<Line> {
        val lines = ArrayList<Line>()
        lines.add(
            if (p.handedOver) Line(Mark.DONE, "Handed to Garmin Connect")
            else if (p.delivery != null) Line(Mark.FAILED, "Not handed to Garmin Connect")
            else Line(Mark.WAITING, "Handing to Garmin Connect"),
        )
        val delivery = p.delivery
        lines.add(
            when {
                delivery == null -> Line(Mark.WAITING, "Waiting for the watch to receive it")
                delivery == Delivery.SUCCESS -> Line(Mark.DONE, delivery(delivery))
                else -> Line(Mark.FAILED, delivery(delivery))
            },
        )
        val answer = p.answer
        lines.add(
            when {
                answer != null && answer.ok -> Line(Mark.DONE, "Stored on the watch as ${p.cardName}")
                answer != null -> Line(Mark.FAILED, "The widget refused it: ${Contract.whyText(answer.why)}")
                delivery != null && delivery != Delivery.SUCCESS -> Line(Mark.FAILED, "No answer from the widget, because the message did not arrive")
                p.waitedLong -> Line(
                    Mark.WAITING,
                    "No answer yet. The widget stores the card when it is next opened on the watch (widget list, CARDS, START). This screen keeps listening while it is open.",
                )
                else -> Line(Mark.WAITING, "Waiting for the widget to answer")
            },
        )
        return lines
    }
}
