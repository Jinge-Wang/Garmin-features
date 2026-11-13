package app.cardloader.codec

import com.google.zxing.BarcodeFormat
import com.google.zxing.Binarizer
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.ReaderException
import com.google.zxing.common.GlobalHistogramBinarizer
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.multi.qrcode.detector.MultiDetector
import com.google.zxing.qrcode.detector.Detector

/** What a picture or a camera frame held. */
sealed interface ReadOutcome {
    /** A QR code, rebuilt exactly. */
    class Qr(val symbol: QrSymbol) : ReadOutcome

    /** A 1-D bar code: its content only; the watch draws Code 128. */
    class Bar(val content: String, val format: BarcodeFormat) : ReadOutcome {
        val symbology: String get() = symbologyName(format)
        val isCode128: Boolean get() = format == BarcodeFormat.CODE_128
    }

    /** More than one different QR code in the picture. */
    data object MultipleQr : ReadOutcome

    /** A 2-D code the watch app does not show (PDF417, Aztec, Data Matrix). */
    class OtherCode(val name: String) : ReadOutcome

    /** A code was found but cannot be used; the message says why in plain words. */
    class Refused(val message: String) : ReadOutcome

    data object NotFound : ReadOutcome
}

fun symbologyName(format: BarcodeFormat): String = when (format) {
    BarcodeFormat.CODE_128 -> "Code 128"
    BarcodeFormat.CODE_39 -> "Code 39"
    BarcodeFormat.CODE_93 -> "Code 93"
    BarcodeFormat.EAN_13 -> "EAN-13"
    BarcodeFormat.EAN_8 -> "EAN-8"
    BarcodeFormat.UPC_A -> "UPC-A"
    BarcodeFormat.UPC_E -> "UPC-E"
    BarcodeFormat.ITF -> "ITF"
    BarcodeFormat.CODABAR -> "Codabar"
    BarcodeFormat.PDF_417 -> "PDF417"
    BarcodeFormat.AZTEC -> "Aztec"
    BarcodeFormat.DATA_MATRIX -> "Data Matrix"
    else -> format.name
}

/**
 * Reads a QR code or a 1-D bar code from a grey picture, all on the phone with ZXing's core.
 * `thorough` is for a picked picture (both binarizers, inverted, two scales, a check for a second
 * QR code); a camera frame uses the quick path and the next frame is another try.
 */
object CodeReader {
    private const val LARGEST_SIDE = 3000
    private const val SMALL_SIDE = 400

    private val ONE_D = listOf(
        BarcodeFormat.CODE_128, BarcodeFormat.CODE_39, BarcodeFormat.CODE_93, BarcodeFormat.EAN_13,
        BarcodeFormat.EAN_8, BarcodeFormat.UPC_A, BarcodeFormat.UPC_E, BarcodeFormat.ITF, BarcodeFormat.CODABAR,
    )
    private val TWO_D = listOf(BarcodeFormat.PDF_417, BarcodeFormat.AZTEC, BarcodeFormat.DATA_MATRIX)

    private enum class Binarization { HYBRID, GLOBAL }

    private class Attempt(val binarization: Binarization, val inverted: Boolean)

    fun read(picture: Luma, thorough: Boolean): ReadOutcome {
        val attempts = if (thorough) {
            listOf(
                Attempt(Binarization.HYBRID, false), Attempt(Binarization.GLOBAL, false),
                Attempt(Binarization.HYBRID, true), Attempt(Binarization.GLOBAL, true),
            )
        } else {
            listOf(Attempt(Binarization.HYBRID, false), Attempt(Binarization.GLOBAL, false))
        }
        val scales = scalesOf(picture, thorough)

        var refusal: ReadOutcome.Refused? = null
        // 1. QR code.
        for (scale in scales) for (attempt in attempts) {
            when (val found = tryQr(bitmapOf(scale, attempt), thorough)) {
                is ReadOutcome.Qr, ReadOutcome.MultipleQr -> return found
                is ReadOutcome.Refused -> refusal = found
                else -> Unit
            }
        }
        if (refusal != null) return refusal
        // 2. 1-D bar code, in both orientations.
        for (scale in scales) for (picturePart in listOf(scale, scale.rotated())) for (attempt in attempts) {
            val bar = tryBar(bitmapOf(picturePart, attempt))
            if (bar != null) return bar
        }
        // 3. Other 2-D codes, only to say that the watch app does not show them.
        if (thorough) {
            for (scale in scales) for (attempt in attempts) {
                val other = tryOther(bitmapOf(scale, attempt))
                if (other != null) return other
            }
        }
        return ReadOutcome.NotFound
    }

    /**
     * The picture itself when it is not huge. A picked picture is also tried at half size (a
     * blurred photo reads better small) and, when it is small, at three times its size (a code
     * drawn at 2 px per module is too fine for the detector).
     */
    private fun scalesOf(picture: Luma, thorough: Boolean): List<Luma> {
        val side = maxOf(picture.width, picture.height)
        val factor = (side + LARGEST_SIDE - 1) / LARGEST_SIDE
        val first = picture.reducedBy(factor)
        if (!thorough) return listOf(first)
        val firstSide = maxOf(first.width, first.height)
        if (firstSide < SMALL_SIDE) return listOf(first, first.enlargedBy(3))
        if (firstSide < 600) return listOf(first)
        return listOf(first, first.reducedBy(2))
    }

    private fun bitmapOf(picture: Luma, attempt: Attempt): BinaryBitmap {
        var source = picture.source()
        if (attempt.inverted) source = source.invert()
        val binarizer: Binarizer = when (attempt.binarization) {
            Binarization.HYBRID -> HybridBinarizer(source)
            Binarization.GLOBAL -> GlobalHistogramBinarizer(source)
        }
        return BinaryBitmap(binarizer)
    }

    private fun tryQr(bitmap: BinaryBitmap, thorough: Boolean): ReadOutcome? {
        val matrix = try {
            bitmap.blackMatrix
        } catch (e: ReaderException) {
            return null
        }
        val hints = if (thorough) mapOf(DecodeHintType.TRY_HARDER to true) else null
        var refusal: String? = null
        var symbol: QrSymbol? = null
        // The detector's own choice of the three position squares.
        val sampled = try {
            Detector(matrix).detect(hints).bits
        } catch (e: ReaderException) {
            null
        }
        if (sampled != null) {
            when (val copy = QrExactCopy.copy(sampled)) {
                is CopyOutcome.Copied -> symbol = copy.symbol
                is CopyOutcome.Refused -> refusal = copy.reason
            }
        }
        // Data modules can form a shape that looks like a position square, and the detector then
        // settles on a wrong three. The multi-code detector goes through the other combinations.
        // It also finds a second code in the picture, which a picked picture is checked for.
        val others = if (symbol == null || thorough) copiesOfEveryCode(matrix, hints) else emptyList()
        if (symbol == null) symbol = others.firstOrNull()
        if (symbol == null) return refusal?.let { ReadOutcome.Refused(it) }
        if (thorough) {
            val different = (others + symbol).map { Grids.hexRows(it.grid) }.toSet()
            if (different.size > 1) return ReadOutcome.MultipleQr
        }
        return ReadOutcome.Qr(symbol)
    }

    /** Every QR code the multi-code detector locates that passes the exact copy and its checks. */
    private fun copiesOfEveryCode(matrix: com.google.zxing.common.BitMatrix, hints: Map<DecodeHintType, Any>?): List<QrSymbol> {
        val found = try {
            MultiDetector(matrix).detectMulti(hints)
        } catch (e: ReaderException) {
            return emptyList()
        }
        val out = ArrayList<QrSymbol>()
        for (item in found) {
            val copy = QrExactCopy.copy(item.bits)
            if (copy is CopyOutcome.Copied) out.add(copy.symbol)
        }
        return out
    }

    private fun tryBar(bitmap: BinaryBitmap): ReadOutcome? {
        val hints = mapOf(
            DecodeHintType.POSSIBLE_FORMATS to ONE_D,
            DecodeHintType.TRY_HARDER to true,
        )
        val result = try {
            MultiFormatReader().decode(bitmap, hints)
        } catch (e: ReaderException) {
            return null
        }
        val content = result.text ?: return null
        val problem = BarContent.problem(content)
        if (problem != null) return ReadOutcome.Refused(problem)
        return ReadOutcome.Bar(content, result.barcodeFormat)
    }

    private fun tryOther(bitmap: BinaryBitmap): ReadOutcome? {
        val hints = mapOf(DecodeHintType.POSSIBLE_FORMATS to TWO_D, DecodeHintType.TRY_HARDER to true)
        val result = try {
            MultiFormatReader().decode(bitmap, hints)
        } catch (e: ReaderException) {
            return null
        }
        return ReadOutcome.OtherCode(symbologyName(result.barcodeFormat))
    }
}
