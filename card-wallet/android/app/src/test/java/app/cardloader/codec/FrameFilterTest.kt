package app.cardloader.codec

import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FrameFilterTest {
    private fun bar(content: String, format: BarcodeFormat = BarcodeFormat.CODE_128) = ReadOutcome.Bar(content, format)

    @Test
    fun aQrCodeIsTakenAtOnce() {
        val grid = TestSupport.gridOf(TestSupport.encode("SAMPLE-CARD-0000", ErrorCorrectionLevel.M, 0))
        val read = CodeReader.read(TestSupport.picture(grid, 4, 4), thorough = false)
        assertTrue(read is ReadOutcome.Qr)
        assertTrue(FrameFilter().take(read))
    }

    @Test
    fun aBarCodeNeedsThreeEqualFramesInARow() {
        val filter = FrameFilter()
        assertFalse(filter.take(bar("000012345678")))
        assertFalse(filter.take(bar("000012345678")))
        assertTrue(filter.take(bar("000012345678")))
    }

    @Test
    fun anotherReadOrAnEmptyFrameStartsTheCountAgain() {
        val filter = FrameFilter()
        assertFalse(filter.take(bar("000012345678")))
        assertFalse(filter.take(bar("000012345678")))
        // A different content, as a misread of a blurred QR code would give.
        assertFalse(filter.take(bar("4711")))
        assertFalse(filter.take(bar("000012345678")))
        assertFalse(filter.take(bar("000012345678")))
        assertFalse(filter.take(ReadOutcome.NotFound))
        assertFalse(filter.take(bar("000012345678")))
        // The same content in another symbology is another read.
        assertFalse(filter.take(bar("000012345678", BarcodeFormat.ITF)))
        assertFalse(filter.take(bar("000012345678")))
        assertFalse(filter.take(bar("000012345678")))
        assertTrue(filter.take(bar("000012345678")))
    }
}
