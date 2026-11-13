package app.cardloader.codec

import com.google.zxing.BarcodeFormat

/**
 * Decides when a camera frame's read is taken. A QR code is taken at once: it has passed its own
 * error correction and the checks of the exact copy. A bar code has no such proof, and the modules
 * of a blurred QR code can read as a short bar code, so a bar code is taken only when the same
 * content in the same symbology was read in three frames in a row.
 */
class FrameFilter(private val needed: Int = 3) {
    private var last: Pair<BarcodeFormat, String>? = null
    private var count = 0

    /** True when this frame's read should go to the review screen. */
    fun take(outcome: ReadOutcome): Boolean = when (outcome) {
        is ReadOutcome.Qr -> true
        is ReadOutcome.Bar -> {
            val now = outcome.format to outcome.content
            count = if (now == last) count + 1 else 1
            last = now
            count >= needed
        }
        else -> {
            last = null
            count = 0
            false
        }
    }
}
