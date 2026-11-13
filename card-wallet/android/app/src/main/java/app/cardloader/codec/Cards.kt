package app.cardloader.codec

/** One card as the phone will send it and as the watch stores it. No Android types. */
sealed interface Card {
    val name: String

    /** The record cardtool writes and the watch's storage holds (README "Storage"), without `b`. */
    fun toStorageMap(): Map<String, Any>

    /** The message of the phone link contract, with the given id. */
    fun toMessage(id: Int): Map<String, Any>
}

data class QrCard(override val name: String, val n: Int, val g: List<String>) : Card {
    override fun toStorageMap(): Map<String, Any> =
        linkedMapOf("name" to name, "kind" to "qr", "n" to n, "g" to g)

    override fun toMessage(id: Int): Map<String, Any> =
        linkedMapOf("v" to Contract.VERSION, "id" to id, "name" to name, "kind" to "qr", "n" to n, "g" to g)

    companion object {
        fun of(name: String, grid: Grid): QrCard = QrCard(name, grid.size, Grids.hexRows(grid))
    }
}

data class BarCard(override val name: String, val t: String) : Card {
    override fun toStorageMap(): Map<String, Any> =
        linkedMapOf("name" to name, "kind" to "bar", "t" to t)

    override fun toMessage(id: Int): Map<String, Any> =
        linkedMapOf("v" to Contract.VERSION, "id" to id, "name" to name, "kind" to "bar", "t" to t)
}
