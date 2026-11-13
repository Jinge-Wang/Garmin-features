package app.cardloader.codec

import com.google.zxing.LuminanceSource

/** An 8-bit grey picture, row 0 at the top, 255 = white. */
class Luma(val width: Int, val height: Int, val data: ByteArray) {
    init {
        require(data.size == width * height) { "picture of $width x $height needs ${width * height} bytes" }
    }

    /** The picture turned a quarter turn clockwise, so that a vertical bar code becomes horizontal. */
    fun rotated(): Luma {
        val out = ByteArray(data.size)
        for (y in 0 until height) for (x in 0 until width) {
            out[x * height + (height - 1 - y)] = data[y * width + x]
        }
        return Luma(height, width, out)
    }

    /** Box-average reduction by a whole factor. */
    fun reducedBy(factor: Int): Luma {
        if (factor <= 1) return this
        val w = width / factor
        val h = height / factor
        val out = ByteArray(w * h)
        val area = factor * factor
        for (y in 0 until h) for (x in 0 until w) {
            var sum = 0
            for (dy in 0 until factor) {
                val line = (y * factor + dy) * width + x * factor
                for (dx in 0 until factor) sum += data[line + dx].toInt() and 0xff
            }
            out[y * w + x] = (sum / area).toByte()
        }
        return Luma(w, h, out)
    }

    /** Each pixel repeated `factor` times in both directions, for a code drawn very small. */
    fun enlargedBy(factor: Int): Luma {
        if (factor <= 1) return this
        val w = width * factor
        val out = ByteArray(w * height * factor)
        for (y in 0 until height) for (x in 0 until width) {
            val value = data[y * width + x]
            for (dy in 0 until factor) {
                val line = (y * factor + dy) * w + x * factor
                for (dx in 0 until factor) out[line + dx] = value
            }
        }
        return Luma(w, height * factor, out)
    }

    fun source(): LuminanceSource = object : LuminanceSource(width, height) {
        override fun getRow(y: Int, row: ByteArray?): ByteArray {
            val out = if (row == null || row.size < width) ByteArray(width) else row
            System.arraycopy(data, y * width, out, 0, width)
            return out
        }

        override fun getMatrix(): ByteArray = data
    }

    companion object {
        /** From ARGB pixels (as a bitmap gives them); transparent pixels count as white. */
        fun fromArgb(width: Int, height: Int, pixels: IntArray): Luma {
            val out = ByteArray(width * height)
            for (i in out.indices) {
                val p = pixels[i]
                val a = p ushr 24
                val r = (p shr 16) and 0xff
                val g = (p shr 8) and 0xff
                val b = p and 0xff
                var y = (r * 306 + g * 601 + b * 117) shr 10
                if (a < 255) y = (y * a + 255 * (255 - a)) / 255
                out[i] = y.toByte()
            }
            return Luma(width, height, out)
        }
    }
}
