package app.cardloader.codec

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GridTest {
    @Test
    fun hexRowsOfASmallGrid() {
        // 6 modules per row: 4 + 2 bits, padded on the right with zero bits.
        val g = arrayOf(
            booleanArrayOf(true, false, true, true, true, false),   // 1011 10(00) -> b8
            booleanArrayOf(false, false, false, false, false, true), // 0000 01(00) -> 04
            booleanArrayOf(true, true, true, true, true, true),      // 1111 11(00) -> fc
            booleanArrayOf(false, false, false, false, false, false), // 00
            booleanArrayOf(true, false, false, false, false, false),  // 1000 00(00) -> 80
            booleanArrayOf(false, true, false, false, false, true),   // 0100 01(00) -> 44
        )
        assertEquals(listOf("b8", "04", "fc", "00", "80", "44"), Grids.hexRows(g))
        val back = Grids.fromHexRows(Grids.hexRows(g), 6)
        assertEquals(0, Grids.differences(g, back))
    }

    @Test
    fun hexRowsOf21ModulesUseSixDigits() {
        val row = BooleanArray(21) { it == 0 || it == 20 }
        val hex = Grids.hexRows(arrayOf(row)).single()
        assertEquals(6, hex.length)
        assertEquals("800008", hex) // first module = top bit of digit 0; last module = bit 3 of digit 5 (21 = 5*4 + 1)
    }

    private fun squareAt(g: Grid, r0: Int, c0: Int) {
        for (r in 0 until 7) for (c in 0 until 7) g[r0 + r][c0 + c] = maxOf(Math.abs(r - 3), Math.abs(c - 3)) != 2
    }

    @Test
    fun positionSquareCheck() {
        val g = Array(21) { BooleanArray(21) }
        assertFalse(Grids.isFinder(g, 0, 0))
        squareAt(g, 0, 0)
        assertTrue(Grids.isFinder(g, 0, 0))
        assertFalse(Grids.hasPositionSquares(g))
        squareAt(g, 0, 14)
        squareAt(g, 14, 0)
        assertTrue(Grids.hasPositionSquares(g))
        squareAt(g, 14, 14)
        assertFalse("a square at the bottom right is wrong", Grids.hasPositionSquares(g))
    }

    @Test
    fun aFlippedGridIsRefused() {
        val g = Array(21) { BooleanArray(21) }
        squareAt(g, 0, 0); squareAt(g, 0, 14); squareAt(g, 14, 14)
        assertFalse(Grids.hasPositionSquares(g))
    }

    @Test
    fun barPixelsMatchTheFormulaByHand() {
        // r = 140, chord = 2 * sqrt(140^2 - 36^2) = 270.5846; (chord - 8) = 262.5846.
        // "7": 1 symbol -> 11 * 3 + 13 = 46 modules; 262.58 / 52 = 5.05 -> 5.
        assertEquals(5, BarContent.barPixels("7", 280))
        // "12345": odd digits, 1 + 2 + 1 = 4 symbols -> 79 modules; 262.58 / 85 = 3.09 -> 3.
        assertEquals(3, BarContent.barPixels("12345", 280))
        // "000012345678": even digits, 6 symbols -> 101 modules; 262.58 / 107 = 2.45 -> 2.
        assertEquals(2, BarContent.barPixels("000012345678", 280))
        // "SAMPLE-CARD-0000": 16 symbols -> 211 modules; 262.58 / 217 = 1.21 -> 1.
        assertEquals(1, BarContent.barPixels("SAMPLE-CARD-0000", 280))
        // 20 other characters -> 22 symbols * 11 + 13 = 255 modules; 262.58 / 261 = 1.006 -> 1; 21 -> 0.
        assertEquals(1, BarContent.barPixels("A".repeat(20), 280))
        assertEquals(0, BarContent.barPixels("A".repeat(21), 280))
        // 40 digits -> 20 symbols; 39 digits -> 1 + 19 + 1 = 21 symbols.
        assertEquals(1, BarContent.barPixels("1".repeat(40), 280))
        assertEquals(0, BarContent.barPixels("1".repeat(39), 280))
    }

    @Test
    fun barContentRules() {
        assertEquals(null, BarContent.problem("000012345678"))
        assertTrue(BarContent.problem("") != null)
        assertTrue(BarContent.problem("A".repeat(81)) != null)
        assertTrue(BarContent.problem("café") != null)
        assertTrue(BarContent.problem("A".repeat(21)) != null)
        assertEquals("000012345678", BarContent.fromTyped("0000 1234 5678"))
    }

    @Test
    fun qrPixelsPerModuleOnTheWatch() {
        // (280 * 707 / 1000) = 197; 197 / (n + 2)
        assertEquals(8, Contract.qrPixelsPerModule(21))
        assertEquals(6, Contract.qrPixelsPerModule(29))
        assertEquals(5, Contract.qrPixelsPerModule(37))
        assertEquals(4, Contract.qrPixelsPerModule(45))
        assertEquals(2, Contract.qrPixelsPerModule(77))
    }
}
