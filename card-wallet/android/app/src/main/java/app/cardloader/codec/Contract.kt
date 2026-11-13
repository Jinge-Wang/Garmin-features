package app.cardloader.codec

import kotlin.random.Random

/** The phone link contract: the message rules, checked here the way the watch checks them. */
object Contract {
    const val VERSION: Int = 1
    const val WATCH_APP_ID = "3322e9a040a44fb5944b215574981322"
    const val SCREEN = 280
    const val MAX_ID = 1_000_000_000
    const val MAX_NAME = 24

    /** The `why` codes, in the order the watch checks them. */
    val WHY_CODES = listOf("format", "name", "kind", "size", "chars", "shape", "content", "long", "full")

    fun newId(random: Random = Random.Default): Int = random.nextInt(1, MAX_ID + 1)

    /** Pixels per module the QR code will have on the watch: the screen's inscribed square over n + 2. */
    fun qrPixelsPerModule(n: Int, screen: Int = SCREEN): Int = (screen * 707 / 1000) / (n + 2)

    /** A plain sentence for what is wrong with the name, or null when it is fine. */
    fun nameProblem(name: String): String? {
        val count = name.codePointCount(0, name.length)
        if (count < 1) return "Enter a name."
        if (count > MAX_NAME) return "The name can have at most $MAX_NAME characters."
        if (name.any { it.code < 0x20 || it.code == 0x7f }) return "The name cannot hold control characters."
        if (name.first() == ' ' || name.last() == ' ') return "The name cannot start or end with a space."
        return null
    }

    /** What the user typed, cleaned up the way the review screen uses it: spaces at both ends removed. */
    fun cleanName(typed: String): String = typed.trim(' ')

    /**
     * The first rule a message breaks, as the watch reports it, or "" when the message is good.
     * `message` is whatever arrived; integers must be Kotlin Int.
     */
    fun validate(message: Any?): String {
        val m = message as? Map<*, *> ?: return "format"
        // format: v, id, name, kind present with the right types; the key set; n, g or t with the right types.
        if (m["v"] != VERSION || m["v"] !is Int) return "format"
        val id = m["id"] as? Int ?: return "format"
        if (id < 1 || id > MAX_ID) return "format"
        val name = m["name"] as? String ?: return "format"
        val kind = m["kind"] as? String ?: return "format"
        val qrKeys = setOf("v", "id", "name", "kind", "n", "g")
        val barKeys = setOf("v", "id", "name", "kind", "t")
        when (kind) {
            "qr" -> {
                if (m.keys != qrKeys) return "format"
                if (m["n"] !is Int) return "format"
                val g = m["g"] as? List<*> ?: return "format"
                if (g.any { it !is String }) return "format"
            }
            "bar" -> {
                if (m.keys != barKeys) return "format"
                if (m["t"] !is String) return "format"
            }
        }
        if (nameProblem(name) != null) return "name"
        if (kind != "qr" && kind != "bar") return "kind"
        if (kind == "qr") {
            val n = m["n"] as Int
            @Suppress("UNCHECKED_CAST")
            val g = m["g"] as List<String>
            if (n < 21 || n > 177 || (n - 17) % 4 != 0) return "size"
            val width = (n + 3) / 4
            if (g.size != n || g.any { it.length != width }) return "size"
            if (g.any { row -> row.any { it !in '0'..'9' && it !in 'a'..'f' } }) return "chars"
            val unused = 4 * width - n
            if (unused > 0) {
                val mask = (1 shl unused) - 1
                if (g.any { (Character.digit(it.last(), 16) and mask) != 0 }) return "chars"
            }
            if (!Grids.hasPositionSquares(Grids.fromHexRows(g, n))) return "shape"
            return ""
        }
        val t = m["t"] as String
        if (t.isEmpty() || t.length > BarContent.MAX_LENGTH || !t.all { it.code in 32..126 }) return "content"
        if (BarContent.barPixels(t, SCREEN) < 1) return "long"
        return ""
    }

    /** A plain sentence for a `why` code from the watch. */
    fun whyText(why: String): String = when (why) {
        "format" -> "The message was not in the form the widget expects."
        "name" -> "The name is not allowed. It needs 1 to 24 characters, with no control characters and no space at either end."
        "kind" -> "The widget does not know this kind of code."
        "size" -> "The size of the QR code is not one the widget accepts."
        "chars" -> "The code data holds characters the widget does not accept."
        "shape" -> "The widget did not find the three position squares of a QR code where they belong."
        "content" -> "The bar code content is empty, too long, or has characters the widget cannot show."
        "long" -> "The bar code is too long to show on the watch screen."
        "full" -> "The watch has no room left to store the card."
        else -> "The widget refused the card for a reason this app does not know ($why)."
    }
}

/** The widget's answer: the id of the message it answers, whether it stored the card, and why not. */
data class WatchAnswer(val id: Int, val ok: Boolean, val why: String) {
    companion object {
        /** From the payload of an incoming message: a list whose first element is the answer's dictionary. */
        fun parse(payload: List<*>?): WatchAnswer? {
            val m = payload?.firstOrNull() as? Map<*, *> ?: return null
            val id = (m["id"] as? Number)?.toInt() ?: return null
            val ok = m["ok"] as? Boolean ?: return null
            val why = m["why"] as? String ?: ""
            return WatchAnswer(id, ok, why)
        }
    }
}
