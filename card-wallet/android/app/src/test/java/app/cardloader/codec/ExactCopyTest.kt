package app.cardloader.codec

import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import kotlin.random.Random

/** The phone's QR pipeline against ZXing's own encoder: the rebuilt grid is the encoder's matrix. */
class ExactCopyTest {
    // Versions 1 and 2 (no and one alignment pattern), 7 (version information), 10 (multi-block),
    // 15 and 25 (several blocks, many alignment patterns).
    private val versions = listOf(1, 2, 7, 10, 15, 25)

    /** The grid drawn at 4 px per module and read once, as a picked picture is. */
    private fun readQr(grid: Grid, where: String): QrSymbol {
        val outcome = CodeReader.read(TestSupport.picture(grid, 4, 4), thorough = true)
        if (outcome is ReadOutcome.Qr) return outcome.symbol
        fail("$where: expected a QR code, got ${outcome::class.simpleName}" + ((outcome as? ReadOutcome.Refused)?.let { " (${it.message})" } ?: ""))
        throw IllegalStateException()
    }

    @Test
    fun rebuiltGridEqualsTheEncodersMatrixForEveryLevelAndMask() {
        var checked = 0
        for (version in versions) for (level in ErrorCorrectionLevel.values()) for (mask in 0..7) {
            val text = TestSupport.dummyText(version, level, 0.6)
            val code = TestSupport.encode(text, level, mask, version)
            assertEquals(version, code.version.versionNumber)
            assertEquals(mask, code.maskPattern)
            val original = TestSupport.gridOf(code)
            val where = "version $version level $level mask $mask"
            val symbol = readQr(original, where)
            assertEquals(where, original.size, symbol.n)
            assertEquals(where, 0, Grids.differences(original, symbol.grid))
            assertEquals(where, mask, symbol.mask)
            assertEquals(where, level, symbol.level)
            assertEquals(where, version, symbol.version)
            checked++
        }
        assertEquals(versions.size * 4 * 8, checked)
    }

    @Test
    fun theEncodersOwnVersionChoiceIsCopiedToo() {
        // Texts of several lengths without forcing the version: 1, 2, 7+ and a multi-block version appear.
        val seen = HashSet<Int>()
        for (length in listOf(5, 20, 40, 130, 300, 600, 900)) {
            val text = TestSupport.dummyText(40, ErrorCorrectionLevel.L, 1.0).take(length)
            for (level in ErrorCorrectionLevel.values()) {
                val code = TestSupport.encode(text, level, mask = (length + level.ordinal) % 8)
                val original = TestSupport.gridOf(code)
                val symbol = readQr(original, "own version choice")
                assertEquals(0, Grids.differences(original, symbol.grid))
                seen.add(code.version.versionNumber)
            }
        }
        assertTrue("versions seen: $seen", seen.any { it == 1 } && seen.any { it >= 7 } && seen.any { it >= 10 })
    }

    @Test
    fun flippedModulesInThePictureAreCorrectedAndTheOriginalIsRebuilt() {
        val random = Random(7)
        for (version in versions) for (level in ErrorCorrectionLevel.values()) {
            val mask = random.nextInt(8)
            val code = TestSupport.encode(TestSupport.dummyText(version, level, 0.6), level, mask, version)
            val original = TestSupport.gridOf(code)
            val n = original.size
            val damaged = Array(n) { original[it].copyOf() }
            // Two data modules (not position squares, timing, alignment or format modules).
            val function = QrMatrixBuilder.functionModules(code.version)
            val flipped = HashSet<Pair<Int, Int>>()
            while (flipped.size < 2) {
                val r = random.nextInt(n)
                val c = random.nextInt(n)
                if (!function[r][c]) flipped.add(r to c)
            }
            for ((r, c) in flipped) damaged[r][c] = !damaged[r][c]
            val where = "flipped: version $version level $level"
            val symbol = readQr(damaged, where)
            assertEquals(where, 0, Grids.differences(original, symbol.grid))
        }
    }

    @Test
    fun aMirroredPictureIsRebuiltTheRightWayRound() {
        val code = TestSupport.encode(TestSupport.dummyText(3, ErrorCorrectionLevel.M, 0.6), ErrorCorrectionLevel.M, 3, 3)
        val original = TestSupport.gridOf(code)
        val symbol = readQr(Grids.transposed(original), "mirrored")
        assertEquals(0, Grids.differences(original, symbol.grid))
    }

    @Test
    fun aPictureWithoutACodeIsNotFound() {
        val blank = Luma(200, 200, ByteArray(200 * 200) { 255.toByte() })
        assertTrue(CodeReader.read(blank, thorough = true) is ReadOutcome.NotFound)
    }

    @Test
    fun twoDifferentQrCodesInOnePictureAreReportedAsMany() {
        val a = TestSupport.gridOf(TestSupport.encode("SAMPLE-CARD-0000", ErrorCorrectionLevel.M, 1))
        val b = TestSupport.gridOf(TestSupport.encode("SAMPLE-CARD-9999", ErrorCorrectionLevel.M, 2))
        val first = TestSupport.picture(a, 4, 4)
        val second = TestSupport.picture(b, 4, 4)
        val gap = 40
        val width = first.width + gap + second.width
        val height = maxOf(first.height, second.height)
        val data = ByteArray(width * height) { 255.toByte() }
        for (y in 0 until first.height) System.arraycopy(first.data, y * first.width, data, y * width, first.width)
        for (y in 0 until second.height) {
            System.arraycopy(second.data, y * second.width, data, y * width + first.width + gap, second.width)
        }
        assertTrue(CodeReader.read(Luma(width, height, data), thorough = true) is ReadOutcome.MultipleQr)
    }
}
