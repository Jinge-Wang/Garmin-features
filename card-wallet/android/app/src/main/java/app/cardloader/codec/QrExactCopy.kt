package app.cardloader.codec

import com.google.zxing.ReaderException
import com.google.zxing.common.BitMatrix
import com.google.zxing.qrcode.decoder.Decoder
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.google.zxing.qrcode.decoder.QRCodeDecoderMetaData
import com.google.zxing.qrcode.decoder.Version

/** The QR symbol that will be sent: the rebuilt grid and what it was rebuilt from. */
class QrSymbol(
    val grid: Grid,
    val version: Int,
    val level: ErrorCorrectionLevel,
    val mask: Int,
    val dataCodewords: ByteArray,
) {
    val n: Int get() = grid.size
}

sealed interface CopyOutcome {
    class Copied(val symbol: QrSymbol) : CopyOutcome
    class Refused(val reason: String) : CopyOutcome
}

/**
 * The exact copy of a QR code. The sampled grid (what the detector saw, with any damage or blur)
 * is decoded to its error-corrected data codewords, error-correction level and mask pattern, and
 * the symbol is generated again from them. The result has the same version, mask, level and data
 * as the code that was read, and none of the read errors.
 */
object QrExactCopy {

    fun copy(sampled: BitMatrix): CopyOutcome {
        val n = sampled.width
        if (n != sampled.height || n < 21 || n > 177 || (n - 17) % 4 != 0) {
            return CopyOutcome.Refused("The code could not be read at a usable size.")
        }
        val decoded = try {
            Decoder().decode(sampled.clone())
        } catch (e: ReaderException) {
            return CopyOutcome.Refused("The code could not be decoded.")
        }
        val mirrored = (decoded.other as? QRCodeDecoderMetaData)?.isMirrored == true
        var grid: Grid = Array(n) { r -> BooleanArray(n) { c -> sampled.get(c, r) } }
        if (mirrored) grid = Grids.transposed(grid)

        val level = decoded.getECLevel()?.let { ErrorCorrectionLevel.valueOf(it) }
            ?: return CopyOutcome.Refused("The code has no error-correction level.")
        val format = readFormat(grid) ?: return CopyOutcome.Refused("The format information of the code is unreadable.")
        if (format.first != level) return CopyOutcome.Refused("The two readings of the error-correction level disagree.")
        val mask = format.second
        val version = Version.getVersionForNumber((n - 17) / 4)
        val data = decoded.rawBytes ?: return CopyOutcome.Refused("The code has no data.")

        val rebuilt = try {
            QrMatrixBuilder.build(data, version, level, mask)
        } catch (e: IllegalArgumentException) {
            return CopyOutcome.Refused("The code does not match its own version.")
        }

        // Check 1: the rebuilt grid decodes to the same data, version and level.
        val again = try {
            Decoder().decode(BitMatrix.parse(rebuilt.map { it.copyOf() }.toTypedArray()))
        } catch (e: ReaderException) {
            return CopyOutcome.Refused("The redrawn code does not read back.")
        }
        if (!again.rawBytes.contentEquals(data) || again.getECLevel() != decoded.getECLevel()) {
            return CopyOutcome.Refused("The redrawn code does not read back as the original.")
        }
        // Check 2: the three position squares are in place and the bottom right one is not.
        if (!Grids.hasPositionSquares(rebuilt)) {
            return CopyOutcome.Refused("The redrawn code is not the right way up.")
        }
        // Check 3: it is close to what was seen. A far-off result means the wrong code was rebuilt.
        if (Grids.differences(rebuilt, grid) * 4 >= n * n) {
            return CopyOutcome.Refused("The redrawn code differs too much from the picture.")
        }
        return CopyOutcome.Copied(QrSymbol(rebuilt, version.versionNumber, level, mask, data))
    }

    /**
     * Error-correction level and mask pattern from the 15 format bits of the sampled grid: both
     * copies read, XOR 0x5412, the nearest of the 32 valid codewords (at most 3 bits away).
     */
    fun readFormat(grid: Grid): Pair<ErrorCorrectionLevel, Int>? {
        val n = grid.size
        var first = 0
        // Bit 14 first: along row 8 from the left, then up column 8.
        for (c in 0..5) first = (first shl 1) or bit(grid[8][c])
        first = (first shl 1) or bit(grid[8][7])
        first = (first shl 1) or bit(grid[8][8])
        first = (first shl 1) or bit(grid[7][8])
        for (r in 5 downTo 0) first = (first shl 1) or bit(grid[r][8])
        var second = 0
        for (r in n - 1 downTo n - 7) second = (second shl 1) or bit(grid[r][8])
        for (c in n - 8 until n) second = (second shl 1) or bit(grid[8][c])

        var best: Pair<ErrorCorrectionLevel, Int>? = null
        var bestDistance = Int.MAX_VALUE
        for (level in ErrorCorrectionLevel.values()) {
            for (mask in 0..7) {
                val target = QrMatrixBuilder.formatBits(level, mask)
                val d = minOf(Integer.bitCount(target xor first), Integer.bitCount(target xor second))
                if (d < bestDistance) {
                    bestDistance = d
                    best = level to mask
                }
            }
        }
        return if (bestDistance <= 3) best else null
    }

    private fun bit(b: Boolean) = if (b) 1 else 0
}
