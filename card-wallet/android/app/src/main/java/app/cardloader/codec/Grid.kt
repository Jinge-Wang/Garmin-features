package app.cardloader.codec

/** A module grid, row 0 at the top; true is a dark module. */
typealias Grid = Array<BooleanArray>

object Grids {
    private const val HEX = "0123456789abcdef"

    /**
     * Each row as hex, most significant bit = leftmost module, padded on the right with zero
     * bits to a whole number of hex digits (the watch's storage format; cardtool's `hexRows`).
     */
    fun hexRows(grid: Grid): List<String> = grid.map { row ->
        val out = StringBuilder()
        var c = 0
        while (c < row.size) {
            var v = 0
            for (k in 0 until 4) {
                v = v shl 1
                if (c + k < row.size && row[c + k]) v = v or 1
            }
            out.append(HEX[v])
            c += 4
        }
        out.toString()
    }

    /** The grid of n x n modules that the hex rows describe; the padding bits are dropped. */
    fun fromHexRows(rows: List<String>, n: Int): Grid = Array(n) { r ->
        BooleanArray(n) { c ->
            val digit = Character.digit(rows[r][c / 4], 16)
            (digit shr (3 - c % 4)) and 1 == 1
        }
    }

    /**
     * The 7 x 7 position square with its top left corner at (row, column): dark except the ring
     * at distance 2 from the centre (cardtool's `isFinder`).
     */
    fun isFinder(grid: Grid, row: Int, column: Int): Boolean {
        for (r in 0 until 7) {
            for (c in 0 until 7) {
                val ring = maxOf(Math.abs(r - 3), Math.abs(c - 3))
                val dark = ring != 2
                if (grid[row + r][column + c] != dark) return false
            }
        }
        return true
    }

    /** Position squares at the top left, top right and bottom left, and none at the bottom right. */
    fun hasPositionSquares(grid: Grid): Boolean {
        val n = grid.size
        if (n < 21) return false
        return isFinder(grid, 0, 0) && isFinder(grid, 0, n - 7) && isFinder(grid, n - 7, 0) &&
            !isFinder(grid, n - 7, n - 7)
    }

    fun transposed(grid: Grid): Grid = Array(grid.size) { r -> BooleanArray(grid.size) { c -> grid[c][r] } }

    /** The number of modules in which the two grids differ. */
    fun differences(a: Grid, b: Grid): Int {
        var d = 0
        for (r in a.indices) for (c in a[r].indices) if (a[r][c] != b[r][c]) d++
        return d
    }
}
