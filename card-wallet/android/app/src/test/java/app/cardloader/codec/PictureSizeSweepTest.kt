package app.cardloader.codec

import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test

/**
 * A screenshot shows a code at one size, so the picture path has one try. Every dummy code here is
 * drawn clean at each module size from 2 to 40 px and read once, with no retry at another size:
 * the result must be a QR code whose grid is the encoder's matrix.
 */
class PictureSizeSweepTest {
    private val versions = listOf(1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 15, 20, 25)
    private val scales = (2..16).toList() + listOf(18, 20, 22, 24, 27, 30, 33, 36, 40)

    @Test
    fun aCleanPictureIsReadAtEveryModuleSize() {
        val misses = ArrayList<String>()
        var tried = 0
        for (version in versions) for (level in ErrorCorrectionLevel.values()) for (mask in 0..7) {
            val code = TestSupport.encode(TestSupport.dummyText(version, level, 0.6), level, mask, version)
            val original = TestSupport.gridOf(code)
            for (scale in scales) {
                // Keep the picture within what a phone screenshot or photo holds.
                if ((original.size + 8) * scale > 4000) continue
                tried++
                val outcome = CodeReader.read(TestSupport.picture(original, scale, 4), thorough = true)
                if (outcome !is ReadOutcome.Qr) {
                    misses.add("version $version level $level mask $mask at $scale px: ${outcome::class.simpleName}")
                    continue
                }
                assertEquals("version $version level $level at $scale px", 0, Grids.differences(original, outcome.symbol.grid))
            }
        }
        if (misses.isNotEmpty()) {
            fail("${misses.size} of $tried clean pictures were not read as a QR code:\n" + misses.joinToString("\n"))
        }
    }
}
