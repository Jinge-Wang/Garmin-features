package app.cardloader.codec

import com.google.zxing.common.reedsolomon.GenericGF
import com.google.zxing.common.reedsolomon.ReedSolomonEncoder
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.google.zxing.qrcode.decoder.Version

/**
 * Builds the module grid of a QR code (ISO/IEC 18004, model 2) from its data codewords, version,
 * error-correction level and mask pattern. The codewords are the data bytes after the mode
 * indicators, character counts, terminator and pad bytes are all in place, as a reader returns them.
 */
object QrMatrixBuilder {

    fun build(dataCodewords: ByteArray, version: Version, level: ErrorCorrectionLevel, mask: Int): Grid {
        require(mask in 0..7) { "mask pattern $mask" }
        val codewords = interleavedCodewords(dataCodewords, version, level)
        val n = version.dimensionForVersion
        val dark = Array(n) { BooleanArray(n) }
        val reserved = Array(n) { BooleanArray(n) }
        placeFunctionPatterns(dark, reserved, version)
        placeFormatInformation(dark, formatBits(level, mask))
        if (version.versionNumber >= 7) placeVersionInformation(dark, versionBits(version.versionNumber))
        placeData(dark, reserved, codewords, mask)
        return dark
    }

    /** Data blocks with their Reed-Solomon bytes, interleaved as the standard orders them. */
    fun interleavedCodewords(data: ByteArray, version: Version, level: ErrorCorrectionLevel): ByteArray {
        val blocksInfo = version.getECBlocksForLevel(level)
        val ecPerBlock = blocksInfo.getECCodewordsPerBlock()
        val dataLengths = ArrayList<Int>()
        for (ecb in blocksInfo.getECBlocks()) repeat(ecb.count) { dataLengths.add(ecb.dataCodewords) }
        val totalData = dataLengths.sum()
        require(data.size == totalData) { "${data.size} data codewords, version ${version.versionNumber} holds $totalData" }

        val encoder = ReedSolomonEncoder(GenericGF.QR_CODE_FIELD_256)
        val dataBlocks = ArrayList<IntArray>()
        val ecBlocks = ArrayList<IntArray>()
        var offset = 0
        for (length in dataLengths) {
            val block = IntArray(length + ecPerBlock)
            for (i in 0 until length) block[i] = data[offset + i].toInt() and 0xff
            encoder.encode(block, ecPerBlock)
            dataBlocks.add(block.copyOfRange(0, length))
            ecBlocks.add(block.copyOfRange(length, length + ecPerBlock))
            offset += length
        }

        val out = ByteArray(version.totalCodewords)
        var at = 0
        val longest = dataLengths.max()
        for (i in 0 until longest) for (b in dataBlocks) if (i < b.size) out[at++] = b[i].toByte()
        for (i in 0 until ecPerBlock) for (b in ecBlocks) out[at++] = b[i].toByte()
        check(at == out.size) { "interleaved $at of ${out.size} codewords" }
        return out
    }

    /** The 15 format bits: 2 bits of level, 3 of mask, 10 of BCH check, XOR 0x5412. */
    fun formatBits(level: ErrorCorrectionLevel, mask: Int): Int {
        val data = (level.bits shl 3) or mask
        var rem = data shl 10
        for (i in 14 downTo 10) if ((rem shr i) and 1 == 1) rem = rem xor (0x537 shl (i - 10))
        return ((data shl 10) or rem) xor 0x5412
    }

    /** The 18 version bits: 6 of version number, 12 of BCH check. */
    fun versionBits(version: Int): Int {
        var rem = version shl 12
        for (i in 17 downTo 12) if ((rem shr i) and 1 == 1) rem = rem xor (0x1f25 shl (i - 12))
        return (version shl 12) or rem
    }

    /** True when the mask pattern flips the data module in this row and column. */
    fun maskFlips(mask: Int, row: Int, col: Int): Boolean = when (mask) {
        0 -> (row + col) and 1 == 0
        1 -> row and 1 == 0
        2 -> col % 3 == 0
        3 -> (row + col) % 3 == 0
        4 -> ((row / 2) + (col / 3)) and 1 == 0
        5 -> ((row * col) and 1) + ((row * col) % 3) == 0
        6 -> ((((row * col) and 1) + ((row * col) % 3)) and 1) == 0
        7 -> ((((row * col) % 3) + ((row + col) and 1)) and 1) == 0
        else -> throw IllegalArgumentException("mask pattern $mask")
    }

    /** The modules that are not data: position squares, timing, alignment, format and version areas. */
    fun functionModules(version: Version): Grid {
        val n = version.dimensionForVersion
        val reserved = Array(n) { BooleanArray(n) }
        placeFunctionPatterns(Array(n) { BooleanArray(n) }, reserved, version)
        return reserved
    }

    private fun placeFunctionPatterns(dark: Grid, reserved: Grid, version: Version) {
        val n = dark.size
        fun put(r: Int, c: Int, value: Boolean) {
            dark[r][c] = value
            reserved[r][c] = true
        }
        // Position squares with their one-module separators.
        for ((r0, c0) in listOf(0 to 0, 0 to n - 7, n - 7 to 0)) {
            for (dr in -1..7) for (dc in -1..7) {
                val r = r0 + dr
                val c = c0 + dc
                if (r !in 0 until n || c !in 0 until n) continue
                val inside = dr in 0..6 && dc in 0..6
                put(r, c, inside && maxOf(Math.abs(dr - 3), Math.abs(dc - 3)) != 2)
            }
        }
        // Timing patterns.
        for (i in 8 until n - 8) {
            put(6, i, i % 2 == 0)
            put(i, 6, i % 2 == 0)
        }
        // Alignment patterns, except where they would overlap a position square.
        val centers = version.alignmentPatternCenters
        val last = centers.size - 1
        for (a in centers.indices) for (b in centers.indices) {
            if ((a == 0 && b == 0) || (a == 0 && b == last) || (a == last && b == 0)) continue
            for (dr in -2..2) for (dc in -2..2) {
                put(centers[a] + dr, centers[b] + dc, maxOf(Math.abs(dr), Math.abs(dc)) != 1)
            }
        }
        // Format information areas (filled later) and the always-dark module.
        for (i in 0..8) {
            reserved[8][i] = true
            reserved[i][8] = true
        }
        for (i in 0 until 8) {
            reserved[8][n - 1 - i] = true
            reserved[n - 1 - i][8] = true
        }
        put(n - 8, 8, true)
        // Version information areas (versions 7 and up).
        if (version.versionNumber >= 7) {
            for (i in 0 until 6) for (j in 0 until 3) {
                reserved[i][n - 11 + j] = true
                reserved[n - 11 + j][i] = true
            }
        }
    }

    private fun placeFormatInformation(dark: Grid, bits: Int) {
        val n = dark.size
        // First copy around the top left square: (row, column) of format bit i, bit 0 = least significant.
        val first = arrayOf(
            0 to 8, 1 to 8, 2 to 8, 3 to 8, 4 to 8, 5 to 8, 7 to 8, 8 to 8, 8 to 7, 8 to 5, 8 to 4, 8 to 3, 8 to 2, 8 to 1, 8 to 0,
        )
        for (i in 0 until 15) {
            val bit = (bits shr i) and 1 == 1
            dark[first[i].first][first[i].second] = bit
            // Second copy: along the bottom of the left strip, then along the right of the top strip.
            if (i < 8) dark[8][n - 1 - i] = bit else dark[n - 7 + (i - 8)][8] = bit
        }
    }

    private fun placeVersionInformation(dark: Grid, bits: Int) {
        val n = dark.size
        for (i in 0 until 6) for (j in 0 until 3) {
            val bit = (bits shr (i * 3 + j)) and 1 == 1
            dark[n - 11 + j][i] = bit
            dark[i][n - 11 + j] = bit
        }
    }

    private fun placeData(dark: Grid, reserved: Grid, codewords: ByteArray, mask: Int) {
        val n = dark.size
        val totalBits = codewords.size * 8
        var bitIndex = 0
        var direction = -1
        var col = n - 1
        var row = n - 1
        while (col > 0) {
            if (col == 6) col -= 1
            while (row in 0 until n) {
                for (k in 0..1) {
                    val c = col - k
                    if (reserved[row][c]) continue
                    var bit = false
                    if (bitIndex < totalBits) {
                        bit = (codewords[bitIndex shr 3].toInt() shr (7 - (bitIndex and 7))) and 1 == 1
                        bitIndex++
                    }
                    if (maskFlips(mask, row, c)) bit = !bit
                    dark[row][c] = bit
                }
                row += direction
            }
            direction = -direction
            row += direction
            col -= 2
        }
        check(bitIndex == totalBits) { "placed $bitIndex of $totalBits bits" }
    }
}
