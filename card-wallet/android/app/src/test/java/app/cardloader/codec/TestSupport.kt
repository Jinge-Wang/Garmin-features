package app.cardloader.codec

import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.google.zxing.qrcode.decoder.Version
import com.google.zxing.qrcode.encoder.Encoder
import com.google.zxing.qrcode.encoder.QRCode
import java.awt.image.BufferedImage

object TestSupport {
    /** A grey picture of the grid: dark = 0, white border of `quiet` modules, `scale` pixels per module. */
    fun picture(grid: Grid, scale: Int, quiet: Int): Luma {
        val n = grid.size
        val side = (n + 2 * quiet) * scale
        val data = ByteArray(side * side) { 255.toByte() }
        for (r in 0 until n) for (c in 0 until n) if (grid[r][c]) {
            for (dy in 0 until scale) for (dx in 0 until scale) {
                data[((r + quiet) * scale + dy) * side + (c + quiet) * scale + dx] = 0
            }
        }
        return Luma(side, side, data)
    }

    fun lumaOf(image: BufferedImage): Luma {
        val w = image.width
        val h = image.height
        val pixels = IntArray(w * h)
        image.getRGB(0, 0, w, h, pixels, 0, w)
        return Luma.fromArgb(w, h, pixels)
    }

    fun encode(text: String, level: ErrorCorrectionLevel, mask: Int, version: Int? = null): QRCode {
        val hints = HashMap<EncodeHintType, Any>()
        hints[EncodeHintType.QR_MASK_PATTERN] = mask
        if (version != null) hints[EncodeHintType.QR_VERSION] = version
        return Encoder.encode(text, level, hints)
    }

    fun gridOf(code: QRCode): Grid {
        val m = code.matrix
        return Array(m.height) { r -> BooleanArray(m.width) { c -> m.get(c, r).toInt() == 1 } }
    }

    /** A dummy text that fills about `fraction` of the version's data capacity in byte mode. */
    fun dummyText(version: Int, level: ErrorCorrectionLevel, fraction: Double): String {
        val v = Version.getVersionForNumber(version)
        val capacity = v.totalCodewords - v.getECBlocksForLevel(level).totalECCodewords
        val length = maxOf(4, ((capacity - 4) * fraction).toInt())
        val base = "SAMPLE-CARD-0000-"
        return buildString { while (length > this.length) append(base) }.take(length)
    }
}
