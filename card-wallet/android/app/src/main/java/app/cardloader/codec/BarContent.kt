package app.cardloader.codec

/** What a bar code card may hold, and whether the watch can show it. */
object BarContent {
    const val MAX_LENGTH = 80

    /**
     * Pixels per module of a Code 128 bar code on a round screen, estimated without the encoder
     * (cardtool's `barPixels`): symbols of 11 modules each plus start, check and stop (13), and
     * the chord of the screen at the top edge of the 72 px tall bars, minus 8 px, over the modules
     * plus 6 quiet modules.
     */
    fun barPixels(content: String, screen: Int): Int {
        val n = content.length
        val digits = content.all { it in '0'..'9' }
        val symbols = if (digits) {
            if (n % 2 == 0) n / 2 else 1 + (n - 1) / 2 + (if (n > 1) 1 else 0)
        } else {
            n
        }
        val modules = 11 * (symbols + 2) + 13
        val r = screen / 2.0
        val chord = 2 * Math.sqrt(r * r - 36.0 * 36.0)
        return Math.floor((chord - 8) / (modules + 6)).toInt()
    }

    /** The reason the watch cannot take this content, in a plain sentence, or null when it can. */
    fun problem(content: String): String? {
        if (content.isEmpty()) return "The bar code is empty."
        if (content.length > MAX_LENGTH) return "The bar code has more than $MAX_LENGTH characters."
        if (!content.all { it.code in 32..126 }) {
            return "The bar code holds characters that the watch cannot show. It takes letters, digits and punctuation only."
        }
        if (barPixels(content, Contract.SCREEN) < 1) return "The bar code is too long to show on the watch."
        return null
    }

    /**
     * A typed number as cardtool takes it: spaces are how a number is printed on a card, not
     * part of the code.
     */
    fun fromTyped(typed: String): String = typed.filter { !it.isWhitespace() }
}
